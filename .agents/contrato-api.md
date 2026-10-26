# Contrato da API

Contrato completo entre `backend/`, `frontend/` e `simulator/`. Regras de negócio citadas aqui estão detalhadas em `regras-de-negocio.md`.

## Convenções

- Base: `http://<host>:8000`. Prefixo REST: `/api/v1`.
- JSON em `snake_case`. Datas em ISO-8601 UTC (`2026-10-07T14:30:00Z`). IDs são strings.
- Erros seguem o formato padrão do FastAPI: `{"detail": "mensagem"}`.
- Autenticação: header `Authorization: Bearer <jwt>` em todas as rotas, **exceto** `GET /`, `POST /auth/login`, `POST /auth/register` e `POST /predict`.
- JWT válido por 24 h, assinado com `HS256`; o `sub` é o `id` do responsável.

| Código | Quando |
| :--- | :--- |
| 400 | Regra de entrada violada (texto vazio, código de convite inválido) |
| 401 | Token ausente, inválido ou expirado; credenciais erradas |
| 403 | Ação exclusiva do responsável primário feita por secundário |
| 404 | Recurso inexistente **ou** não vinculado ao usuário |
| 409 | Transição de status inválida; e-mail já cadastrado |
| 422 | Payload malformado (validação Pydantic) |

## Resumo

| Método | Rota | Auth | UC | Prioridade |
| :--- | :--- | :--- | :--- | :--- |
| GET | `/` | Não | — | Essencial |
| POST | `/api/v1/auth/login` | Não | UC-18 | Essencial |
| GET | `/api/v1/auth/me` | Sim | UC-18 | Essencial |
| POST | `/api/v1/predict` | Não | UC-01 | Essencial |
| GET | `/api/v1/dependents` | Sim | — | Essencial |
| PATCH | `/api/v1/dependents/{dependent_id}/threshold` | Primário | UC-03 | Essencial |
| GET | `/api/v1/incidents` | Sim | UC-09 | Essencial |
| GET | `/api/v1/incidents/{incident_id}` | Sim | UC-09 | Essencial |
| POST | `/api/v1/incidents/{incident_id}/view` | Sim | UC-02 | Essencial |
| PATCH | `/api/v1/incidents/{incident_id}/status` | Sim | UC-09, UC-07 | Essencial |
| GET | `/api/v1/incidents/{incident_id}/report` | Sim | UC-04 | Essencial |
| DELETE | `/api/v1/incidents/{incident_id}` | Primário | UC-17 | Essencial |
| WS | `/ws?token=<jwt>` | Sim | UC-02 | Essencial |
| POST | `/api/v1/dependents/{dependent_id}/invites` | Primário | UC-06 | Se sobrar tempo |
| POST | `/api/v1/auth/register` | Não | UC-06 | Se sobrar tempo |

---

## Saúde

### `GET /`

```json
{ "status": "online", "model_loaded": false }
```

`model_loaded` indica se o Proxy já carregou os pesos (só ocorre na primeira predição).

---

## Autenticação

### `POST /api/v1/auth/login`

```json
// Request
{ "email": "responsavel@exemplo.com", "password": "..." }

// 200 OK
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 86400,
  "guardian": { "id": "resp-001", "name": "Maria", "email": "responsavel@exemplo.com" }
}
```

Credenciais inválidas → 401 com `{"detail": "E-mail ou senha incorretos"}`.

### `GET /api/v1/auth/me`

```json
// 200 OK
{
  "id": "resp-001",
  "name": "Maria",
  "email": "responsavel@exemplo.com",
  "dependents": [
    { "id": "dep-001", "name": "Lucas", "is_primary": true }
  ]
}
```

`is_primary` é por dependente: o mesmo responsável pode ser primário de um e secundário de outro.

### `POST /api/v1/auth/register` *(se sobrar tempo)*

```json
// Request
{ "name": "João", "email": "joao@exemplo.com", "password": "...", "invite_code": "K7P2QX9M" }

// 201 Created: mesmo formato do login (já devolve o token)
```

Código inexistente, expirado ou já usado → 400. E-mail já cadastrado → 409.

---

## Predição

### `POST /api/v1/predict`

Chamado pelo simulador. Sem autenticação (limitação documentada: em produção exigiria autenticação do dispositivo).

```json
// Request
{
  "text": "Você é um inútil, ninguém gosta de você",
  "message_hash": "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e",
  "dependent_id": "dep-001",
  "context_metadata": {
    "conversation_id": "conv-game-88",
    "room_type": "jogo",
    "sender_id": "user-adversario-09",
    "is_from_minor": false,
    "is_direct": true,
    "timestamp": "2026-10-07T14:30:00Z"
  }
}

// 200 OK
{
  "label": "nocivo",
  "category": "CIBERBULLYING",
  "confidence": 0.93,
  "has_link": false,
  "action_required": "ALERT_PARENT_CRITICAL",
  "detected_role": "VITIMA",
  "sha256_match": true,
  "incident_id": "inc-9876",
  "model_version": "GuilhermeLA/modelo-tcc-final",
  "inference_time_ms": 142.5
}
```

| Campo | Valores |
| :--- | :--- |
| `room_type` | `"jogo"` ou `"conversa"` (qualquer outro valor → 422) |
| `label` | `"normal"` ou `"nocivo"` |
| `category` | `"SEGURO"`, `"CIBERBULLYING"`, `"LINK_SUSPEITO"` |
| `action_required` | `"NONE"`, `"LOG_INCIDENT"`, `"ALERT_PARENT_CRITICAL"` |
| `detected_role` | `"VITIMA"`, `"EMISSOR"`, `"ESPECTADOR"` |
| `incident_id` | ID do incidente criado, ou `null` se `action_required = "NONE"` |

Erros: texto vazio ou só espaços → 400; `dependent_id` inexistente → 404; campo ausente ou valor fora do enum → 422.

---

## Dependentes

### `GET /api/v1/dependents`

Dependentes vinculados ao usuário logado.

```json
// 200 OK
[
  {
    "id": "dep-001",
    "name": "Lucas",
    "common_threshold": 0.50,
    "is_primary": true,
    "safe_messages_count": 128
  }
]
```

`safe_messages_count` é o contador agregado de mensagens seguras (único dado guardado sobre elas).

### `PATCH /api/v1/dependents/{dependent_id}/threshold`

```json
// Request
{ "common_threshold": 0.65 }

// 200 OK
{ "id": "dep-001", "common_threshold": 0.65 }
```

Valor fora de `0.50 <= x <= 0.84` → 422. Usuário não primário → 403.

### `POST /api/v1/dependents/{dependent_id}/invites` *(se sobrar tempo)*

```json
// 201 Created
{ "invite_code": "K7P2QX9M", "expires_at": "2026-10-09T14:30:00Z" }
```

Usuário não primário → 403.

---

## Incidentes

### Objeto `IncidentSummary`

Usado na listagem e nos eventos WebSocket.

```json
{
  "id": "inc-9876",
  "dependent_id": "dep-001",
  "dependent_name": "Lucas",
  "category": "CIBERBULLYING",
  "severity": "CRITICO",
  "confidence": 0.93,
  "has_link": false,
  "detected_role": "VITIMA",
  "status": "DETECTADO",
  "integrity_mismatch": false,
  "escalated": false,
  "preview": "Você é um inútil, ninguém gosta...",
  "created_at": "2026-10-07T14:30:01Z"
}
```

- `severity`: `"CRITICO"` se `confidence >= 0.85`, senão `"COMUM"`.
- `preview`: primeiros 60 caracteres do texto.

### `GET /api/v1/incidents`

Query params opcionais: `dependent_id`, `status`, `category`, `limit` (padrão 50, máximo 200), `offset` (padrão 0).

```json
// 200 OK
{ "items": [ /* IncidentSummary */ ], "total": 12 }
```

Ordenado por `created_at` decrescente. Só retorna incidentes de dependentes vinculados ao usuário.

### `GET /api/v1/incidents/{incident_id}`

**Não** altera o status (ver `/view`).

```json
// 200 OK
{
  "...": "todos os campos de IncidentSummary",
  "room_type": "jogo",
  "conversation_id": "conv-game-88",
  "message": {
    "text": "Você é um inútil, ninguém gosta de você",
    "sender_id": "user-adversario-09",
    "is_from_minor": false,
    "timestamp": "2026-10-07T14:30:00Z",
    "message_hash": "a591a6d4..."
  },
  "context_before": [
    { "text": "...", "sender_id": "...", "is_from_minor": true, "timestamp": "..." }
  ],
  "context_after": [],
  "allowed_transitions": [],
  "status_history": [
    {
      "from_status": "DETECTADO",
      "to_status": "VISUALIZADO",
      "note": null,
      "guardian_name": "Maria",
      "changed_at": "2026-10-07T14:35:12Z"
    }
  ]
}
```

`allowed_transitions` lista os destinos manuais válidos a partir do status atual (regra 9). O app usa essa lista para montar as opções, sem duplicar a regra.

### `POST /api/v1/incidents/{incident_id}/view`

Chamado pelo app ao abrir a tela do incidente. Se o status for `DETECTADO`, muda para `VISUALIZADO` e grava no histórico; em qualquer outro status não faz nada. Idempotente.

```json
// 200 OK: o detalhe completo do incidente (mesmo formato do GET)
```

### `PATCH /api/v1/incidents/{incident_id}/status`

```json
// Request
{ "status": "EM_ANALISE", "note": "Vou conversar com ele hoje à noite" }

// 200 OK: o detalhe completo do incidente atualizado
```

`note` é opcional. Transição fora da tabela (inclusive para `DETECTADO` ou `VISUALIZADO`) → 409. Ao ir para `FALSO_POSITIVO`, a nota também é gravada como feedback.

### `GET /api/v1/incidents/{incident_id}/report`

Resposta `200` com `Content-Type: application/pdf` e `Content-Disposition: attachment; filename="incidente-<id>.pdf"`.

Conteúdo mínimo do PDF: dados do incidente, mensagem principal, contexto anterior e posterior, timestamps UTC, hash SHA-256 de origem, resultado da verificação de integridade e data de geração.

### `DELETE /api/v1/incidents/{incident_id}`

`204 No Content`. Exclusão real (regra 14). Usuário não primário → 403.

---

## WebSocket

### Conexão

`ws://<host>:8000/ws?token=<jwt>`

- Token ausente ou inválido: o servidor fecha a conexão com código `4401`.
- O cliente não envia mensagens de negócio. Pode enviar `{"type": "ping"}`, e o servidor responde `{"type": "pong"}`.
- Ao reconectar, o app deve recarregar o feed via `GET /api/v1/incidents`, pois eventos perdidos não são reenviados.

### Eventos do servidor

Formato comum:

```json
{ "type": "incident.critical", "sent_at": "2026-10-07T14:30:01Z", "data": { } }
```

| `type` | `data` | Destinatários | Som no app |
| :--- | :--- | :--- | :--- |
| `incident.created` | `IncidentSummary` | Todos os responsáveis do dependente | Não |
| `incident.critical` | `IncidentSummary` | Só o primário | Sim |
| `incident.escalated` | `IncidentSummary` | Responsáveis não primários | Sim |
| `incident.updated` | `IncidentSummary` | Todos os responsáveis do dependente | Não |
| `incident.deleted` | `{ "id": "inc-9876", "dependent_id": "dep-001" }` | Todos os responsáveis do dependente | Não |

Um incidente crítico gera **dois** eventos: `incident.created` (para todos atualizarem o feed) e `incident.critical` (alerta sonoro ao primário).

---

## Dados de seed (`python -m src.seed`)

IDs fixos usados pelo simulador e pelos testes:

| Tipo | ID | Nome | Observação |
| :--- | :--- | :--- | :--- |
| Responsável | `resp-001` | Responsável Primário | Primário de `dep-001` e `dep-002` |
| Responsável | `resp-002` | Responsável Secundário | Secundário de `dep-001` (para testar escalonamento) |
| Dependente | `dep-001` | Lucas | `common_threshold = 0.50` |
| Dependente | `dep-002` | Ana | `common_threshold = 0.50` |

E-mails e senhas de demonstração ficam definidos apenas em `backend/src/seed.py`.
