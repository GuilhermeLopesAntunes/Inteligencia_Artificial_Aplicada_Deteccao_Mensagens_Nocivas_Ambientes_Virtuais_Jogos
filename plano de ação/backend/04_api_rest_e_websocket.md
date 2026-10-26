# Backend - Etapa 4: API REST e WebSocket Gateway

> **Objetivo:** Expor os endpoints REST e o gateway WebSocket em `src/api/`, com esquemas Pydantic rígidos, autenticação JWT e tratamento de erros padronizado.

---

## 1. Arquivos a Criar/Atualizar
- `backend/src/api/v1/predict.py`
- `backend/src/api/v1/auth.py`
- `backend/src/api/v1/dependents.py`
- `backend/src/api/v1/incidents.py`
- `backend/src/api/websocket.py`
- `backend/src/api/schemas.py`
- `backend/src/main.py`
- `backend/src/seed.py`

---

## 2. Detalhamento dos Componentes

### 2.1. Esquemas Pydantic (`src/api/schemas.py`)
* `ContextMetadataSchema`: `conversation_id`, `room_type` (`jogo` | `conversa`), `sender_id`, `is_from_minor`, `is_direct`, `timestamp`.
* `PredictRequestSchema`: `text`, `message_hash`, `dependent_id`, `context_metadata`.
* `PredictResponseSchema`: `label`, `category`, `confidence`, `has_link`, `action_required`, `detected_role`, `sha256_match`, `incident_id`, `model_version`, `inference_time_ms`.
* `LoginRequestSchema`, `AuthResponseSchema`, `GuardianProfileSchema`.
* `IncidentSummarySchema`, `IncidentDetailSchema`, `StatusUpdateSchema`, `ThresholdUpdateSchema`.

### 2.2. Controladores REST
* **Inference (`POST /api/v1/predict`)**:
  * Rota pública (não requer JWT).
  * Valida se `text.strip()` não está vazio (400 Bad Request).
  * Chama `AnaliseMensagemService.analisar()`.
* **Auth (`/api/v1/auth`)**:
  * `POST /login`: Valida senha via Argon2id, gera JWT assinado com `HS256` e expiração de 24h.
  * `GET /me`: Retorna dados do guardião e dependentes vinculados com flag `is_primary`.
* **Dependentes (`/api/v1/dependents`)**:
  * `GET /`: Lista dependentes do guardião logado.
  * `PATCH /{dependent_id}/threshold`: Atualiza `common_threshold` (valida faixa `0.50 <= x <= 0.84`, 403 se não for primário).
* **Incidentes (`/api/v1/incidents`)**:
  * `GET /`: Listagem paginada e filtrável.
  * `GET /{incident_id}`: Detalhe completo sem alterar status.
  * `POST /{incident_id}/view`: Marca visualizado idempotente.
  * `PATCH /{incident_id}/status`: Transição de status validada.
  * `GET /{incident_id}/report`: Download de PDF binário.
  * `DELETE /{incident_id}`: Exclusão real pelo responsável primário.

### 2.3. WebSocket Gateway (`src/api/websocket.py`)
* Endpoint `GET /ws?token=<jwt>`.
* Gerenciador de conexões em memória (`ConnectionManager`):
  * Mantém mapeamento `guardian_id -> set[WebSocket]`.
  * Trata desconexões limpas e ping/pong (`{"type": "ping"}` $\rightarrow$ `{"type": "pong"}`).
  * Implementa a interface do padrão Observer (`WebSocketNotifier`) para enviar eventos filtrados por dependente e perfil de guardião.

### 2.4. Dados de Demonstração (`src/seed.py`)
* Comando de execução: `python -m src.seed`.
* Criação de dados idênticos ao contrato da API:
  * Responsável Primário (`resp-001`), Responsável Secundário (`resp-002`).
  * Dependentes `dep-001` (Lucas) e `dep-002` (Ana).

---

## 3. Critérios de Aceitação da Etapa
- [ ] Swagger (`/docs`) e OpenAPI geram os contratos exatamente de acordo com `.agents/contrato-api.md`.
- [ ] Rotas protegidas rejeitam tokens inválidos ou expirados com 401.
- [ ] Rotas restritas ao primário rejeitam guardiões secundários com 403.
- [ ] Conexão WebSocket aceita token via query param e despacha eventos JSON.
