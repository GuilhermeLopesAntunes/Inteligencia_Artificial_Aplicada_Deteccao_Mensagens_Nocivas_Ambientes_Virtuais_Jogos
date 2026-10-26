# Handoff Report: Spec Miner Survey Plan (Project Artemis)

## 1. Observation
- Investigated `.agents/ORIGINAL_REQUEST.md` (lines 1–69), noting user constraints: MVP presentation deadline 20/10/2026, team structure with separate agents for Backend, Frontend, Simulator working in parallel, an Integration agent starting only after Backend and Frontend finish, and a Documentation agent tracking throughout.
- Investigated `plano de ação/README.md` (lines 1–79), noting the 4-axis architecture (backend, frontend, simulador, integracao) and the suggested schedule (Semana 1: Desenvolvimento Independente dos 3 Módulos; Semana 2: Integração e Validação End-to-End).
- Inspected all 5 backend task files:
  - `plano de ação/backend/01_dominio_e_regras_puras.md` (lines 1–104): defining `CategoriaAmeaca`, `AcaoRequerida`, `PapelMenor`, `StatusIncidente`, `TipoEventoWS`, `AvaliadorDecisaoRisco` with gamer room threshold elevation $L = \max(L, 0.70)$, critical threshold $0.85$, and the state transition map `TRANSIÇÕES_VALIDAS`.
  - `plano de ação/backend/02_infraestrutura_e_ia_bertimbau.md` (lines 1–69): defining `ClassificadorStrategy`, `BERTimbauEngineProxy` (Virtual Proxy), `RealBERTimbauEngine` on CPU (`GuilhermeLA/modelo-tcc-final`), `MockClassificadorFactory`, `DetectorDeLinks` (`https?://\S+|www\.\S+`), circular `InMemoryBuffer` (`deque(maxlen=3)`), and SQLAlchemy SQLite schema.
  - `plano de ação/backend/03_servicos_de_aplicacao.md` (lines 1–68): detailing `AnaliseMensagemService`, `GestaoIncidenteService`, `RelatorioService` (ReportLab template), `EscalonamentoService` (60s loop, > 15min idle critical incidents), and `AuthService`.
  - `plano de ação/backend/04_api_rest_e_websocket.md` (lines 1–67): detailing REST endpoints (`POST /predict`, `/auth`, `/dependents`, `/incidents`), WebSocket gateway `/ws?token=<jwt>`, and `src/seed.py`.
  - `plano de ação/backend/05_testes_backend_e_ci.md` (lines 1–77): Pytest suite, BVA tests, integration tests via TestClient with SQLite `:memory:`.
- Inspected all 5 frontend task files:
  - `plano de ação/frontend/01_modelos_e_mock_contracts.md` (lines 1–74): Dart models (`IncidentSummary`, `IncidentDetail`, `Dependent`, `Guardian`), `MockApiService`, and `MockWebSocketService`.
  - `plano de ação/frontend/02_autenticacao_e_feed_incidentes.md` (lines 1–49): `LoginScreen`, `IncidentsFeedScreen`, `IncidentCard`, pull-to-refresh, severity badges.
  - `plano de ação/frontend/03_detalhe_incidente_e_acoes.md` (lines 1–60): `IncidentDetailScreen`, auto `POST /view`, conversational context bubbles, timeline, modal driven by `allowed_transitions`, PDF export via `open_filex`, cascade deletion button (`is_primary == true`).
  - `plano de ação/frontend/04_calibracao_e_notificacoes_locais.md` (lines 1–55): `DependentConfigScreen` with slider restricted to [0.50, 0.84], `flutter_local_notifications` high importance channel `artemis_critical_alerts` with sound/vibration.
  - `plano de ação/frontend/05_testes_widgets_e_ui.md` (lines 1–48): `flutter test` widget tests.
- Inspected all 3 simulator task files:
  - `plano de ação/simulador/01_layout_e_interface_chat.md` (lines 1–44): HTML5/CSS3 dark mode chat layout, sidebar controls (dependent, room type, conversation generator, sender switch).
  - `plano de ação/simulador/02_criptografia_webcrypto_e_payload.md` (lines 1–93): Web Crypto API `crypto.subtle.digest("SHA-256")`, payload construction matching `POST /api/v1/predict`.
  - `plano de ação/simulador/03_botoes_cenarios_e_feedback_visual.md` (lines 1–41): 5 preset buttons and audit footer rendering.
- Inspected all 4 integration task files:
  - `plano de ação/integracao/01_orquestracao_docker_e_conexoes.md` (lines 1–77): `docker-compose.yml`, CORS configuration, `AndroidManifest.xml` (`usesCleartextTraffic="true"`).
  - `plano de ação/integracao/02_roteiro_de_testes_e2e.md` (lines 1–51): 6 E2E scenarios.
  - `plano de ação/integracao/03_auditoria_sha256_e_relatorio_pdf.md` (lines 1–51): digital evidence chain and tampering detection.
  - `plano de ação/integracao/04_checklist_final_mvp_tcc.md` (lines 1–52): full checklist with 10 UCs (UC-18, UC-01, UC-10, UC-11, UC-13, UC-02, UC-09, UC-03, UC-04, UC-17), 5 RNFs (RNF-11, RNF-02, RNF-06, RNF-07, RNF-08), and 10-minute presentation guide.

## 2. Logic Chain
1. *From observation of `ORIGINAL_REQUEST.md` and module READMEs:* The project is strictly decoupled into 4 axes. Modules 1, 2, and 3 (Backend, Frontend, Simulator) are designed to be developed completely in parallel without blocking each other, utilizing mocks and local fixtures.
2. *From observation of `backend/01` to `backend/05`:* The backend follows Clean Architecture where Domain (Task 01) has no dependencies; Infrastructure (Task 02) depends only on Domain; Services (Task 03) orchestrates Domain and Infrastructure; API/WebSocket (Task 04) exposes Services; and Tests (Task 05) verifies all four.
3. *From observation of `frontend/01` to `frontend/05`:* Frontend decouples UI from backend using `MockApiService` and `MockWebSocketService`. This enables building screens (Tasks 02, 03, 04) and testing them (Task 05) entirely offline. Switching to real integration is an atomic change swapping the service implementation in `config.dart`.
4. *From observation of `simulador/01` to `simulador/03`:* Simulator is pure HTML/CSS/JS without npm tooling, calculating SHA-256 locally via Web Crypto API. It can operate in local mock mode or submit to `POST /api/v1/predict`.
5. *From observation of `integracao/01` to `integracao/04`:* Integration requires all three modules to be completed and verified before running Docker orchestration, E2E scenarios, and auditing the final checklist.
6. *Synthesis:* The complete plan has been mined and structured into `survey_plan_report.md` covering 30 discovered features, 20 edge cases, full task breakdowns, deliverables, dependencies, and the full TCC checklist.

## 3. Caveats
- No caveats regarding specification coverage. All 17 action plan files and `ORIGINAL_REQUEST.md` were thoroughly read and documented.
- The model checkpoint `GuilhermeLA/modelo-tcc-final` on Hugging Face is ~440MB; it is intended to be loaded lazily or downloaded during integration/Docker setup, while unit tests strictly use `MockClassificadorFactory`.

## 4. Conclusion
The action plan for Project Artemis is fully structured, unambiguous, and provides clear contracts, boundaries, and acceptance criteria. Development can immediately proceed with parallel tracks for Backend (tasks 01-05), Frontend (tasks 01-05), and Simulator (tasks 01-03). The comprehensive survey report is available at:
`C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\spec_miner_survey_plan\survey_plan_report.md`.

## 5. Verification Method
1. Inspect the survey report file:
   `view_file` on `C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\spec_miner_survey_plan\survey_plan_report.md`
2. Verify all sections are present:
   - Features Discovered (30 rows)
   - Edge Cases (20 rows)
   - Task Breakdown (Backend 01-05, Frontend 01-05, Simulator 01-03, Integration 01-04)
   - Dependencies and Precedence
   - Complete TCC MVP Checklist (UCs, RNFs, Presentation Script)
3. Confirm conformance with the source markdown files in `plano de ação/`.
