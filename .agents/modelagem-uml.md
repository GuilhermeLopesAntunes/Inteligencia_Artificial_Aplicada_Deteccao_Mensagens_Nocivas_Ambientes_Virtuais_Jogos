
# Modelagem UML como Esboços (Sketches): Project Artemis

> **Sistema de Controle Parental Inteligente com Detecção de Ciberbullying via BERTimbau**  
> **Referência Metodológica:** Prof. Marco Tulio Valente — *Engenharia de Software Moderna* (Capítulo 4 – Modelos)  

> **Abordagem:** Esboços Ágeis (Regra dos 20/80, Foco em Decisões de Design e Eliminação de BDUF)

---

## 1. Visão Arquitetural de Alto Nível (Diagrama de Pacotes)

```plantuml
@startuml
!theme plain
skinparam packageStyle rectangle
skinparam shadowing false
skinparam roundcorner 8

title Diagrama de Pacotes - Arquitetura em Camadas (Project Artemis)

package "Apresentação & Clientes" as CamadaApresentacao {
  [SimuladorChatWeb]
  [AppParentalFlutter]
}

package "Aplicação & Orquestração" as CamadaAplicacao {
  [PredictController]
  [AuthController]
  [AnaliseMensagemService]
  [GestaoIncidenteService]
  [EscalonamentoService]
  [RelatorioIncidenteService]
}

package "Domínio Central" as CamadaDominio {
  [Incidente]
  [Mensagem]
  [Responsavel]
  [Dependente]
  enum CategoriaAmeaca
  enum StatusIncidente
  enum PapelMenor
  enum AcaoRequerida
}

package "Infraestrutura & Persistência" as CamadaInfra {
  [BERTimbauNeuralEngine]
  [DetectorDeLinks]
  [WebSocketNotificationGateway]
  [IncidenteRepository]
  [InMemoryMessageBuffer]
}

' Relacionamentos
[SimuladorChatWeb] --> [PredictController] : HTTP POST /api/v1/predict
[AppParentalFlutter] --> [AuthController] : Login JWT
[AppParentalFlutter] --> [GestaoIncidenteService] : HTTP REST
[AppParentalFlutter] <.. [WebSocketNotificationGateway] : Notificações em Tempo Real

[PredictController] --> [AnaliseMensagemService]
[AnaliseMensagemService] --> [BERTimbauNeuralEngine] : <<use>>
[AnaliseMensagemService] --> [DetectorDeLinks] : <<use>>
[AnaliseMensagemService] --> [InMemoryMessageBuffer] : <<use>>
[AnaliseMensagemService] --> [Incidente] : Cria se incidente
[AnaliseMensagemService] --> [IncidenteRepository] : Persiste incidente
[AnaliseMensagemService] --> [WebSocketNotificationGateway] : Notifica se P >= 0.85

[GestaoIncidenteService] --> [IncidenteRepository]
[EscalonamentoService] --> [IncidenteRepository]
[EscalonamentoService] --> [WebSocketNotificationGateway]
[RelatorioIncidenteService] --> [Incidente]

@enduml
```

---

## 2. Diagrama de Classes do Domínio Central (PlantUML)

```plantuml
@startuml
skinparam classAttributeIconSize 0
skinparam shadowing false
skinparam roundcorner 8

title Diagrama de Classes - Domínio Central (Project Artemis)

enum CategoriaAmeaca {
  SEGURO
  CIBERBULLYING
  LINK_SUSPEITO
}

enum StatusIncidente {
  DETECTADO
  VISUALIZADO
  EM_ANALISE
  CONVERSADO_COM_FILHO
  ENCAMINHADO_A_ESCOLA
  FALSO_POSITIVO
  RESOLVIDO
}

enum PapelMenor {
  VITIMA
  EMISSOR
  ESPECTADOR
}

enum AcaoRequerida {
  NONE
  LOG_INCIDENT
  ALERT_PARENT_CRITICAL
}

class Mensagem {
  - String id
  - String texto
  - String hashSha256
  - DateTime timestamp
  - String remetenteId
  - Boolean isFromMinor
  + validarIntegridadeHash(hashCalculado: String): Boolean
}

class Incidente {
  - String id
  - DateTime dataHora
  - CategoriaAmeaca categoria
  - Float probabilidadeNocivo
  - PapelMenor papelMenor
  - StatusIncidente status
  - Boolean escalonado
  - Boolean integridadeDivergente
  - List<Mensagem> contextoAnterior
  - List<Mensagem> contextoPosterior
  + marcarVisualizado(): void
  + atualizarStatus(novoStatus: StatusIncidente): void
  + anexarMensagemPosterior(msg: Mensagem): void
}

class Responsavel {
  - String id
  - String nome
  - String email
  - String senhaHash
  - Boolean isPrimario
  + gerarCodigoConvite(): String
}

class Dependente {
  - String id
  - String nome
  - Float limiarComum
  - List<Responsavel> guardioes
  + atualizarLimiarComum(novoLimiar: Float): void
}

Incidente *--> "1" Mensagem : -mensagemPrincipal
Incidente o--> "0..3" Mensagem : -contextoAnterior
Incidente o--> "0..3" Mensagem : -contextoPosterior
Incidente --> CategoriaAmeaca : -categoria
Incidente --> StatusIncidente : -status
Incidente --> PapelMenor : -papelMenor

Dependente "1" o--> "1..*" Responsavel : -guardioes
Incidente --> "1" Dependente : -dependente
@enduml
```

---

## 3. Diagrama de Sequência: Análise e Notificação (PlantUML)

Alinhado ao contrato oficial da API (Decisão 22) e ao anexo de mensagens posteriores (Decisão 27).

```plantuml
@startuml
autonumber
skinparam shadowing false
skinparam roundcorner 8

title Diagrama de Sequência: Predição, Contexto e Notificação

actor "Simulador Web\n(HTML/JS Client)" as Sim
participant "PredictController" as API
participant "AnaliseMensagemService" as Service
participant "InMemoryBuffer" as Buffer
participant "DetectorDeLinks" as URLDetector
participant "BERTimbauEngine" as Model
database "IncidenteRepository\n(SQLite)" as DB
participant "WebSocketGateway\n(App Flutter)" as WS

Sim -> Sim : Calcular SHA-256 no navegador
Sim -> API : POST /api/v1/predict (text, message_hash, dependent_id, context_metadata)
activate API

API -> Service : processarMensagem(payload)
activate Service

Service -> Buffer : verificarIncidentesAbertosParaPosterior(conversaId)
opt Existe incidente aberto (< 10 min e < 3 posteriores)
    Service -> DB : anexarMensagemPosterior(incidenteId, msg)
end

Service -> URLDetector : verificarLink(text)
activate URLDetector
URLDetector --> Service : has_link (true/false)
deactivate URLDetector

Service -> Model : predict_probability(textoNormalizado)
activate Model
Model --> Service : P(nocivo)
deactivate Model

Service -> Service : calcularDecisao(P, has_link, limiarComum, room_type)

alt Incidente Confirmado (P >= L OU has_link == true)
    Service -> Buffer : obter3MensagensAnteriores(conversaId)
    Buffer --> Service : contextoAnterior
    Service -> DB : salvarIncidente(incidente, contextoAnterior)
    activate DB
    DB --> Service : incident_id
    deactivate DB
    Service -> Buffer : abrirIncidenteParaPosteriores(conversaId, incident_id)

    opt P >= 0.85 (Incidente Crítico)
        Service -> WS : emitirNotificacaoWebSocket(incidente)
        activate WS
        WS --> Service : ok
        deactivate WS
    end
else Mensagem Segura
    Service -> Service : (nada é persistido; apenas incrementa contador agregado)
end

Service -> Buffer : registrarMensagemBuffer(conversaId, msg)  // sempre por último (regra 7)
Service --> API : ResponsePayload (200 OK)
deactivate Service

API --> Sim : HTTP 200 OK (label, category, confidence, action_required, incident_id, ...)
deactivate API

@enduml
```

---

## 4. Diagrama de Estados do Incidente (PlantUML)

Mapeia estritamente a tabela oficial de transições de status da Decisão 31.

```plantuml
@startuml
skinparam shadowing false
skinparam roundcorner 8

title Diagrama de Transições de Estados do Incidente

state "DETECTADO" as DETECTADO : Criado pelo Sistema\n(escalonamento 15 min se crítico)
state "VISUALIZADO" as VISUALIZADO : Aberto pelo Responsável
state "EM_ANALISE" as EM_ANALISE : Responsável em investigação
state "CONVERSADO_COM_FILHO" as CONVERSADO : Mediação realizada
state "ENCAMINHADO_A_ESCOLA" as ENCAMINHADO : Acionamento da coordenação
state "FALSO_POSITIVO" as FALSO_POSITIVO : Marcado pelo Responsável
state "RESOLVIDO" as RESOLVIDO : Incidente concluído

[*] --> DETECTADO : P >= L ou has_link = true

DETECTADO --> VISUALIZADO : Sistema (ao abrir incidente)

VISUALIZADO --> EM_ANALISE : Responsável
VISUALIZADO --> FALSO_POSITIVO : Responsável

EM_ANALISE --> CONVERSADO_COM_FILHO : Responsável
EM_ANALISE --> ENCAMINHADO_A_ESCOLA : Responsável
EM_ANALISE --> FALSO_POSITIVO : Responsável
EM_ANALISE --> RESOLVIDO : Responsável

CONVERSADO_COM_FILHO --> RESOLVIDO : Responsável
ENCAMINHADO_A_ESCOLA --> RESOLVIDO : Responsável

FALSO_POSITIVO --> [*] : Arquivado para retreino
RESOLVIDO --> [*] : Concluído
@enduml
```
