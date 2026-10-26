## 2026-10-09T20:09:52Z

You are the Frontend Specialist Worker for Project Artemis.
Your working directory is: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_frontend
Project workspace: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos
Branch: feature/mvp-tcc-artemis (verify you are on this branch; do NOT commit to or checkout main/develop).

MANDATORY READ FIRST:
Read ORIGINAL_REQUEST.md at:
C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\ORIGINAL_REQUEST.md
Also read .agents/PROJECT.md, .agents/regras-de-negocio.md, .agents/contrato-api.md, and plano de ação/frontend/ (tasks 01-05).

FILE OWNERSHIP:
You strictly and exclusively own `frontend/` (`frontend/lib/`, `frontend/test/`, `frontend/android/`, `frontend/pubspec.yaml`, etc.). DO NOT touch `backend/` or `simulator/`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

SCOPE OF WORK (Tasks 01 to 05 of plano de ação/frontend):
1. Setup & Domain Models (`pubspec.yaml`, `lib/domain/`):
   - Configure dependencies (http, flutter_riverpod or provider, flutter_local_notifications, etc.).
   - Models: Guardian, Dependent, Incident, Message, Severity, IncidentStatus, Category.
2. Data & Mock Layer (`lib/data/`):
   - Complete Mock Mode (`MockApiService`, `MockWebSocketService`) enabling 100% offline navigation and realistic scenario testing.
   - Real network client (`ApiService`, `WebSocketService`) consuming FastAPI backend and WebSocket gateway.
   - Environment toggle / config allowing seamless switch between Mock and Real mode.
3. Presentation Layer (`lib/presentation/`):
   - Auth: Login Screen with error handling.
   - Home / Dependents: List dependents with safe message counters.
   - Incidents Feed: Filter chips (Status, Category, Dependent), cards showing severity badges and relative time.
   - Incident Detail Screen: Full incident view with temporal context chat (previous and posterior messages), action buttons for state transitions (Em Análise, Confirmado, Falso Positivo, Arquivado), and PDF report download trigger.
   - Threshold Calibration Screen: Slider [0.50, 0.84] with Gamer mode indicator, restricted to primary guardian (RN-02).
4. Local Notifications (`lib/core/notifications/` & `android/`):
   - Configure `flutter_local_notifications` in `AndroidManifest.xml` (VIBRATE, POST_NOTIFICATIONS permissions).
   - High-priority heads-up notification channel with sound for critical events (`incident.critical`).
5. Testing & Build Verification:
   - Automated tests: Widget and unit tests covering mock mode, navigation, and local notification triggering for critical alerts.
   - Run `flutter analyze` and ensure 0 errors.
   - Run `flutter test` and ensure 100% pass.
   - Run `flutter build apk --debug` and ensure build succeeds.

VERIFICATION:
You MUST execute verification commands yourself (`flutter analyze`, `flutter test`, `flutter build apk --debug`) and document exact results in your handoff.

OUTPUT:
Write your full report to:
`C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_frontend\handoff.md`
Then send a completion message to your caller (parent).


## 2026-10-09T20:28:40Z
**Context**: Retomada pós-reinício do servidor - Frontend Specialist Worker
**Content**: Houve um reinício do servidor que pausou temporariamente as atividades. Você deve RETOMAR sua execução imediatamente no ponto onde estava.
IMPORTANTE - NOVA DIRETIVA: Você tem AUTONOMIA TOTAL. Não faça perguntas nem aguarde confirmações do usuário. Execute proativamente qualquer comando (flutter pub add, flutter test, flutter build apk --debug, etc.) necessário para concluir a implementação do app em frontend/ (Tasks 01-05).
ÚNICA PROIBIÇÃO ESTRITA: NUNCA fazer push/commit/merge na branch main. Todo o trabalho deve permanecer na branch feature/mvp-tcc-artemis.
Lembre-se dos critérios de aceitação:
- flutter analyze limpo sem erros;
- flutter test 100% verde;
- flutter build apk --debug conclui com sucesso;
- Modo mock funcional com todas as telas e notificação local de evento crítico disparada e testada.
Gere seu handoff.md em .agents/worker_frontend/handoff.md e envie mensagem quando concluir.
**Action**: Retomar imediatamente a implementação do app Flutter e testes.
