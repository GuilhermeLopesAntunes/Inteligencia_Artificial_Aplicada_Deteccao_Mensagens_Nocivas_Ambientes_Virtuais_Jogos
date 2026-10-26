# Plano de Ação: Backend Artemis (Python / FastAPI)

> **Módulo:** Backend de Inferência Neural e Regras de Negócio  
> **Independência:** Totalmente desacoplado do Frontend e do Simulador (executável via Swagger, cURL e pytest).

---

## 1. Visão Geral do Módulo
O backend do Artemis segue a arquitetura em camadas e Clean Architecture, separando estritamente:
1. **Domínio (`src/domain/`)**: Regras puras em Python (sem dependências externas de PyTorch, banco ou API).
2. **Infraestrutura (`src/infrastructure/`)**: Virtual Proxy do BERTimbau em CPU, Detector de Links, Buffer circular de memória, modelos SQLAlchemy e repositórios SQLite.
3. **Serviços (`src/services/`)**: Casos de uso de negócio, orquestração de análise, transições de status e geração de PDF.
4. **API (`src/api/`)**: Endpoints REST FastAPI, validação Pydantic, autenticação JWT e WebSocket Gateway.

---

## 2. Roteiro Passo a Passo de Implementação

### 📄 [Etapa 1: Domínio e Regras Puras](01_dominio_e_regras_puras.md)
* Implementação das entidades puras (`Incidente`, `Mensagem`, `Responsavel`, `Dependente`).
* Enums de negócio (`StatusIncidente`, `CategoriaAmeaca`, `PapelMenor`, `AcaoRequerida`).
* Classe `AvaliadorDecisaoRisco` com lógica de limiar comum, Modo Gamer (`L = max(limiar, 0.70)`) e crítico ($0.85$).
* Derivação do papel do menor (`VITIMA`, `EMISSOR`, `ESPECTADOR`) com base em metadados.
* Máquina de estados finita para ciclo de vida de incidentes.

### 📄 [Etapa 2: Infraestrutura e IA BERTimbau](02_infraestrutura_e_ia_bertimbau.md)
* Padrão Strategy e Virtual Proxy para o modelo BERTimbau (`BERTimbauEngineProxy` e `RealBERTimbauEngine`).
* `DetectorDeLinks` via Regex determinístico.
* `InMemoryBuffer` circular com retenção das últimas 3 mensagens por `conversation_id`.
* Configuração do SQLAlchemy 2.x com SQLite e mapeamento das tabelas.
* Padrão Factory (`ClassificadorFactory` e `MockClassificadorFactory` para testes ágeis).

### 📄 [Etapa 3: Serviços de Aplicação](03_servicos_de_aplicacao.md)
* `AnaliseMensagemService`: Orquestração de inferência, verificação de integridade SHA-256, junção de contexto anterior e posterior (janela de 10 min) e disparo de eventos Observer.
* `GestaoIncidenteService`: Visualização (`/view`), transições de status com gravação de histórico, registro de feedback para retreino e exclusão definitiva (LGPD).
* `RelatorioPdfService`: Geração de relatório com ReportLab, contendo metadados, contexto e cadeia de custódia SHA-256.
* `EscalonamentoService`: Scheduler periódico de 60 s para alertar responsáveis secundários em incidentes críticos pendentes > 15 min.

### 📄 [Etapa 4: API REST e WebSocket Gateway](04_api_rest_e_websocket.md)
* Endpoint público `POST /api/v1/predict` conforme contrato oficial.
* Endpoints de autenticação (`POST /api/v1/auth/login`, `GET /api/v1/auth/me`) com JWT (Argon2id + PyJWT).
* Endpoints de dependentes e calibração de limiar (`GET /dependents`, `PATCH /dependents/{id}/threshold`).
* Endpoints de gestão de incidentes (`GET /incidents`, `GET /incidents/{id}`, `POST /incidents/{id}/view`, `PATCH /incidents/{id}/status`, `GET /incidents/{id}/report`, `DELETE /incidents/{id}`).
* Handler WebSocket `/ws?token=<jwt>` e emissão de eventos em tempo real (`incident.created`, `incident.critical`, `incident.escalated`, `incident.updated`, `incident.deleted`).
* Script de seed (`python -m src.seed`) com dados iniciais para testes.

### 📄 [Etapa 5: Testes e Cobertura](05_testes_backend_e_ci.md)
* Suíte de testes unitários com Pytest cobrindo BVA (Boundary Value Analysis) de todos os limiares.
* Testes de integração de todas as rotas usando `TestClient` e SQLite em memória.
* Validação de autenticação, permissões primárias vs secundárias e integridade SHA-256.

---

## 3. Critérios de Pronto (Definition of Done) do Backend
- [ ] 100% dos testes unitários e de integração passando via `APP_ENV=testing pytest`.
- [ ] Servidor Uvicorn iniciando em `< 2s` sem carregar pesos pesados no boot (Lazy Loading validado).
- [ ] Swagger (`http://localhost:8000/docs`) totalmente navegável e funcional.
- [ ] Banco de dados SQLite persistindo dados corretamente em `/app/data/artemis.db`.
