# Plano de Ação: Frontend Flutter (App de Controle Parental)

> **Módulo:** Aplicativo Mobile Android (Flutter)  
> **Independência:** 100% autônomo e desacoplado através de `MockApiService` e `MockWebSocketService`.

---

## 1. Visão Geral do Módulo
O frontend do Artemis é um aplicativo Flutter focado em Android para permitir que pais e responsáveis monitorem seus filhos, recebam alertas críticos com som em tempo real, gerenciem o fluxo de resolução de incidentes e exportem relatórios PDF com assinatura SHA-256.

Para permitir o desenvolvimento e validação visual de toda a UI **sem depender do backend estar rodando**, a camada de serviços é baseada em interfaces abstratas injetáveis com suporte a **Mocks completos e gerador de eventos simulados**.

---

## 2. Roteiro Passo a Passo de Implementação

### 📄 [Etapa 1: Modelos e Contratos de Mock](01_modelos_e_mock_contracts.md)
* Criação dos modelos Dart espelhando exatamente os schemas JSON do contrato da API (`IncidentSummary`, `IncidentDetail`, `Dependent`, `Guardian`, `StatusHistoryItem`, `ContextMessage`).
* Interface abstrata `ApiService` e implementação `MockApiService` com delay simulado e dados fixos de teste.
* Interface abstrata `WebSocketService` e implementação `MockWebSocketService` com disparador de eventos agendados (para testar alertas sonoros sem backend).

### 📄 [Etapa 2: Autenticação e Feed de Incidentes](02_autenticacao_e_feed_incidentes.md)
* Tela de Login (`LoginScreen`) com validação de e-mail e senha, persistência segura do token (`flutter_secure_storage`) e tratamento de erro 401.
* Tela de Feed (`IncidentsFeedScreen`) com lista de incidentes em formato de cards, badge visual de severidade (`CRITICO` vs `COMUM`), filtro por dependente e funcionalidade de *pull-to-refresh*.

### 📄 [Etapa 3: Detalhe do Incidente e Ações do Responsável](03_detalhe_incidente_e_acoes.md)
* Tela de Detalhe (`IncidentDetailScreen`):
  * Chamada automática a `POST /incidents/{id}/view` ao abrir a tela.
  * Mensagem principal em destaque, indicação de papel do menor ("Recebeu a mensagem" / "Enviou a mensagem") e probabilidade em porcentagem ("93%").
  * Exibição das mensagens de contexto anterior e posterior.
  * Timeline visual do histórico de status.
  * Modal dinâmico de troca de status preenchido via `allowed_transitions`.
  * Botão de exportação de relatório PDF (`open_filex`).
  * Botão de exclusão LGPD com confirmação irreversível (apenas para responsáveis primários).

### 📄 [Etapa 4: Calibração de Sensibilidade e Notificações com Áudio](04_calibracao_e_notificacoes_locais.md)
* Tela de Configurações do Dependente (`DependentConfigScreen`):
  * Slider de sensibilidade do limiar comum ($0.50$ a $0.84$) com feedback visual do nível de rigor.
  * Restrição de acesso ao responsável primário (`is_primary == true`).
  * Contador agregado de mensagens seguras analisadas.
* Serviço de Notificações Locais (`NotificationService`):
  * Integração com `flutter_local_notifications`.
  * Solicitação de permissão de notificação no Android 13+ (`POST_NOTIFICATIONS`).
  * Disparo de alerta com som e vibração para eventos `incident.critical` e `incident.escalated`.

### 📄 [Etapa 5: Testes de Widgets e UI](05_testes_widgets_e_ui.md)
* Testes de widget usando `flutter test` cobrindo renderização do feed, transição para tela de detalhes e disparo de diálogos de confirmação usando `MockApiService`.

---

## 3. Critérios de Pronto (Definition of Done) do Frontend
- [ ] O app compila e roda no emulador Android sem erros via `flutter run`.
- [ ] Modo Mock funcional: navegação fluida em todas as telas sem nenhuma chamada de rede externa.
- [ ] Notificação local disparada com som ao receber um evento crítico simulado.
- [ ] 100% dos testes de widgets passando via `flutter test`.
