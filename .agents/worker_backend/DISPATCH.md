## 2026-10-09T20:09:52Z

You are the Backend Specialist Worker for Project Artemis.
Your working directory is: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_backend
Project workspace: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos
Branch: feature/mvp-tcc-artemis (verify you are on this branch; do NOT commit to or checkout main/develop).

MANDATORY READ FIRST:
Read ORIGINAL_REQUEST.md at:
C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\ORIGINAL_REQUEST.md
Also read .agents/PROJECT.md, .agents/regras-de-negocio.md, .agents/contrato-api.md, and plano de ação/backend/ (tasks 01-05). In any conflict, regras-de-negocio.md and contrato-api.md prevail.

FILE OWNERSHIP:
You strictly and exclusively own `backend/` (`backend/src/`, `backend/tests/`, `backend/pyproject.toml`, etc.). DO NOT touch `frontend/` or `simulator/`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

SCOPE OF WORK (Tasks 01 to 05 of plano de ação/backend):
1. Domain Layer (`src/domain/`):
   - Entities: Guardian, Dependent, Incident, Message, ContextMetadata.
   - Status State Machine (7 states: DETECTADO, VISUALIZADO, EM_ANALISE, CONFIRMADO, FALSO_POSITIVO, ARQUIVADO, ESCALADO). Invalid transitions return HTTP 409.
   - Evaluator (`AvaliadorDecisaoRisco`): strict priority rules (P >= 0.85 -> CIBERBULLYING/ALERT_PARENT_CRITICAL; L <= P < 0.85 -> CIBERBULLYING/LOG_INCIDENT; P < L & has_link -> LINK_SUSPEITO/LOG_INCIDENT; P < L & !has_link -> SEGURO/NONE).
   - Gamer Mode: L = max(limiar_comum, 0.70) when room_type == "jogo".
   - Deterministic Link Detector (`DetectorDeLinks`): regex `https?://\S+|www\.\S+` case-insensitive.
   - Volatile in-memory Context Buffer (3 messages before, up to 3 after within 10 min window).
2. Infrastructure Layer (`src/infrastructure/`):
   - SQLite with SQLAlchemy (`StaticPool` for thread-safe in-memory testing).
   - Virtual Proxy Lazy Loader for BERTimbau (`GuilhermeLA/modelo-tcc-final`): Uvicorn MUST boot in < 2.0s without loading heavy model weights at startup. Weights loaded on demand. Under `APP_ENV=testing`, use mock model classifier.
   - Tamper-evident ReportLab PDF Generator: calculates and displays SHA-256 hash with validity badge.
   - WebSocket Connection Manager (`/ws?token=<jwt>`).
3. Services Layer (`src/services/`):
   - Auth service: JWT HS256 (24h expiry), Argon2id/bcrypt password hashing.
   - Prediction & Triage service: coordinates link detector, lazy model, risk evaluator, context buffer, incident creation, and WebSocket alerts.
   - Incident service: pagination, filtering, idempotent `/view`, state transitions, cascade LGPD hard delete (`DELETE /incidents/{id}`).
4. API Presentation (`src/api/` or `src/presentation/`):
   - FastAPI routers matching `.agents/contrato-api.md`:
     - GET `/` (health check)
     - POST `/api/v1/auth/login`, GET `/api/v1/auth/me`
     - POST `/api/v1/predict`
     - GET `/api/v1/dependents`, PATCH `/api/v1/dependents/{id}/threshold`
     - GET `/api/v1/incidents`, GET `/api/v1/incidents/{id}`, POST `/api/v1/incidents/{id}/view`, PATCH `/api/v1/incidents/{id}/status`, GET `/api/v1/incidents/{id}/report`, DELETE `/api/v1/incidents/{id}`
     - WS `/ws?token=<jwt>`
5. Testing Suite (`tests/`):
   - Configure pytest with `APP_ENV=testing`.
   - Comprehensive test suite including:
     - Unit tests for domain rules, state machine, regex link detector.
     - Complete BVA tests for all thresholds (0.499, 0.500, 0.849, 0.850, 1.000, Gamer mode 0.70, custom thresholds).
     - Integration tests for all endpoints.
     - Automated test comparing FastAPI OpenAPI schema routes and fields with `.agents/contrato-api.md`.
     - Test confirming lazy loading boot time < 2.0s.

VERIFICATION:
You MUST execute the test suite yourself (`APP_ENV=testing pytest`) and verify 100% passing tests. Document all test commands and results.

OUTPUT:
Write your full report to:
`C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_backend\handoff.md`
Then send a completion message to your caller (parent).


## 2026-10-09T20:28:34Z
**Context**: Retomada pós-reinício do servidor - Backend Specialist Worker
**Content**: Houve um reinício do servidor que pausou temporariamente as atividades. Você deve RETOMAR sua execução imediatamente no ponto onde estava.
IMPORTANTE - NOVA DIRETIVA: Você tem AUTONOMIA TOTAL. Não faça perguntas nem aguarde confirmações do usuário. Execute proativamente qualquer comando (pip, pytest, criação de arquivos, testes) necessário para concluir a implementação completa de backend/ (Tasks 01-05).
ÚNICA PROIBIÇÃO ESTRITA: NUNCA fazer push/commit/merge na branch main. Todo o trabalho deve permanecer na branch feature/mvp-tcc-artemis.
Lembre-se dos critérios de aceitação:
- APP_ENV=testing pytest 100% verde com BVA completo (0.50/0.84, Gamer 0.70, crítico 0.85);
- Boot do Uvicorn com lazy loading em < 2s;
- Contrato da API estritamente compatível com .agents/contrato-api.md e verificado por teste automatizado.
Gere seu handoff.md em .agents/worker_backend/handoff.md e envie mensagem quando concluir.
**Action**: Retomar imediatamente a implementação das camadas do backend e testes.
