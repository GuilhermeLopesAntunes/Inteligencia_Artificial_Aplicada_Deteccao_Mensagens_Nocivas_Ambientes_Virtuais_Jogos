# Project: Artemis — Cyberbullying Detection in Gaming Chats

## Architecture
Clean Architecture with Hexagonal / Ports & Adapters design, separating Domain, Services, Infrastructure, and Presentation.
- **Backend (Python 3.11+ / FastAPI)**:
  - `src/domain/`: Pure business logic, entities, value objects, risk decision evaluator (`AvaliadorDecisaoRisco`), regex link detector (`DetectorDeLinks`), status state machine, in-memory volatile context buffer. Zero external dependencies.
  - `src/services/`: Application services, JWT authentication, inference orchestration with Virtual Proxy lazy loading BERTimbau (`GuilhermeLA/modelo-tcc-final`), notification dispatch.
  - `src/infrastructure/`: SQLite with SQLAlchemy (`StaticPool`), ReportLab PDF generator with SHA-256 validation, WebSocket connection manager.
  - `src/presentation/` (or `src/api/`): FastAPI routers matching `.agents/contrato-api.md`.
- **Frontend (Flutter 3.x Android)**:
  - Architecture: Presentation, Domain, Data layers with Riverpod/Provider state management.
  - Dual Mode: Full Mock Mode (`MockApiService`, `MockWebSocketService`) for offline demo and real network mode.
  - Features: Login, Dependents, Incidents Feed, Incident Detail with timeline & context chat, Threshold Calibration, High-priority Local Notifications.
- **Simulator (Web Vanilla)**:
  - Pure HTML5, CSS3, ES6 JavaScript served on Nginx (port 3000).
  - Client-side SHA-256 calculation via Web Crypto API matching CLI sha256sum.
  - 5 Demo Presets for quick evaluation by the academic committee.
- **Integration & Real-Time**:
  - Docker Compose orchestrating Backend (:8000) and Simulator (:3000).
  - WebSocket at `/ws?token=<jwt>` delivering immediate critical alerts (< 2s E2E latency).
  - CPU inference latency target <= 350ms.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Health Check (`GET /`) | API status and model load status indicator | M1 | contrato-api.md |
| 2 | Guardian Login (`POST /api/v1/auth/login`) | JWT authentication with Argon2id / bcrypt password verification | M1 | contrato-api.md, UC-18 |
| 3 | Authenticated Profile (`GET /api/v1/auth/me`) | Guardian profile and linked dependents list | M1 | contrato-api.md |
| 4 | Predict & Triage (`POST /api/v1/predict`) | SHA-256 check, BERTimbau inference, link detection, risk decision, alert dispatch | M1 | contrato-api.md, RN-01..RN-06 |
| 5 | List Dependents (`GET /api/v1/dependents`) | Dependents list with safe messages count | M1 | contrato-api.md |
| 6 | Calibrate Threshold (`PATCH /api/v1/dependents/{id}/threshold`) | Common threshold calibration [0.50, 0.84] for primary guardian | M1 | contrato-api.md, RN-02 |
| 7 | List Incidents (`GET /api/v1/incidents`) | Paginated incident summary list with filters (status, category, dependent) | M1 | contrato-api.md, UC-09 |
| 8 | Incident Detail (`GET /api/v1/incidents/{id}`) | Full incident with context messages, history, allowed transitions | M1 | contrato-api.md, UC-02 |
| 9 | Mark Incident Viewed (`POST /api/v1/incidents/{id}/view`) | Idempotent transition from DETECTADO to VISUALIZADO | M1 | contrato-api.md, RN-09 |
| 10 | Update Incident Status (`PATCH /api/v1/incidents/{id}/status`) | State machine transition (EM_ANALISE, CONFIRMADO, FALSO_POSITIVO, ARQUIVADO) | M1 | contrato-api.md, RN-09 |
| 11 | Export Incident PDF (`GET /api/v1/incidents/{id}/report`) | PDF report with tamper-evident SHA-256 hash validation | M1 | contrato-api.md, RN-05 |
| 12 | Delete Incident LGPD (`DELETE /api/v1/incidents/{id}`) | Irreversible physical deletion of incident and context messages | M1 | contrato-api.md, RN-14 |
| 13 | WebSocket Gateway (`WS /ws?token=<jwt>`) | Real-time incident alert broadcast with heartbeat ping/pong | M1 | contrato-api.md, RN-10 |
| 14 | Temporal Context Buffer | In-memory circular buffer (3 before, up to 3 after within 10 min) | M1 | regras-de-negocio.md RN-07 |
| 15 | Lazy Loading Virtual Proxy | Deferred model loading ensuring Uvicorn boot < 2.0s | M1 | arquitetura.md, padroes-de-projeto.md |
| 16 | Link Detector Heuristic | Deterministic regex for URLs (`https?://\S+\|www\.\S+`) | M1 | arquitetura.md, regras-de-negocio.md |
| 17 | BVA Testing Suite | 100% passing tests for all thresholds (0.50, 0.84, Gamer 0.70, critical 0.85) | M1 | testes.md |
| 18 | Flutter Domain Models & DTOs | Dart models representing entities, responses, and enums | M2 | plano de ação/frontend task 01 |
| 19 | Flutter Mock Service Layer | Offline simulation mode (`MockApiService`, `MockWebSocketService`) | M2 | plano de ação/frontend task 02 |
| 20 | Flutter Auth & Navigation | Login screen, session storage, protected routing | M2 | plano de ação/frontend task 03 |
| 21 | Flutter Incidents Feed & Detail | Incidents list, filter chips, detail view with context chat & action buttons | M2 | plano de ação/frontend task 03 |
| 22 | Flutter Threshold Calibration Screen | Slider/picker [0.50, 0.84] restricted to primary guardian | M2 | plano de ação/frontend task 03 |
| 23 | Flutter Local Notifications | High-priority heads-up notifications with sound for critical alerts | M2 | plano de ação/frontend task 04 |
| 24 | Flutter Build & Widget Tests | 100% green widget/unit tests and successful `flutter build apk --debug` | M2 | plano de ação/frontend task 05 |
| 25 | Simulator UI & Layout | Responsive gaming chat simulator in pure HTML/CSS/JS | M3 | plano de ação/simulador task 01 |
| 26 | Simulator Web Crypto SHA-256 | Native in-browser SHA-256 calculation matching CLI sha256sum | M3 | plano de ação/simulador task 02 |
| 27 | Simulator Presets & API Integration | 5 defense presentation presets sending JSON to `POST /api/v1/predict` | M3 | plano de ação/simulador task 03 |
| 28 | Docker Compose Orchestration | Single command `docker compose up` for backend (:8000) and simulator (:3000) | M4 | plano de ação/integracao task 01 |
| 29 | E2E Real Model Test Suite | Automated end-to-end test with Hugging Face BERTimbau model | M4 | plano de ação/integracao task 02 |
| 30 | Performance & Latency Benchmark | Logged benchmark measuring CPU inference <= 350ms and E2E latency < 2s | M4 | plano de ação/integracao task 03 |
| 31 | Tamper-Evident SHA-256 Verification | Test validating hash match in PDF report vs simulator input | M4 | plano de ação/integracao task 03 |
| 32 | Final MVP Checklist Verification | Evidence-backed audit completing `04_checklist_final_mvp_tcc.md` | M4 | plano de ação/integracao task 04 |
| 33 | Continuous Technical Documentation | API documentation, README setup guides, defense presentation metrics | M-Doc | ORIGINAL_REQUEST.md R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend Core & API | Tasks 01–05: Domain, Lazy Proxy BERTimbau, REST endpoints, WebSocket, BVA Pytest | feature/mvp-tcc-artemis branch | PLANNED |
| M2 | Frontend App (Flutter) | Tasks 01–05: Mock mode, UI screens, Local Notifications, tests, APK build | feature/mvp-tcc-artemis branch | PLANNED |
| M3 | Web Chat Simulator | Tasks 01–03: Vanilla HTML/CSS/JS, Web Crypto SHA-256, Presets, API integration | feature/mvp-tcc-artemis branch | PLANNED |
| M-Doc | Continuous Documentation | README, API docs sync, defense presentation materials with metrics | Ongoing parallel | PLANNED |
| M4 | E2E Integration & Verification | Tasks 01–04: Docker compose, E2E real model tests, benchmarks, PDF audit, checklist 04 | M1, M2, M3 | BLOCKED (waits for M1, M2, M3) |
| M-Victory | Final Victory Audit | Forensic Auditor check against all acceptance criteria | M4 | BLOCKED (waits for M4) |

## Interface Contracts
### Simulator ↔ Backend (`POST /api/v1/predict`)
- **Request Body**:
  ```json
  {
    "text": "string (1..1000 chars, not only spaces)",
    "message_hash": "string (64 chars hex sha256)",
    "dependent_id": "string (uuid)",
    "context_metadata": {
      "conversation_id": "string",
      "room_type": "conversa | jogo",
      "sender_id": "string",
      "is_from_minor": false,
      "is_direct": true,
      "timestamp": "2026-10-09T20:00:00Z"
    }
  }
  ```
- **Response Body (200 OK)**:
  ```json
  {
    "label": "nocivo | normal",
    "category": "CIBERBULLYING | LINK_SUSPEITO | SEGURO",
    "confidence": 0.88,
    "has_link": false,
    "action_required": "ALERT_PARENT_CRITICAL | LOG_INCIDENT | NONE",
    "detected_role": "EMISSOR | VITIMA | ESPECTADOR",
    "sha256_match": true,
    "incident_id": "string (uuid) | null",
    "model_version": "BERTimbau-v1",
    "inference_time_ms": 120.5
  }
  ```

### Frontend ↔ Backend (REST API & WebSocket)
- **REST Auth**: `POST /api/v1/auth/login` -> `{ "access_token": "...", "token_type": "bearer", "expires_in": 86400, "guardian": {...} }`
- **REST Dependents**: `GET /api/v1/dependents`, `PATCH /api/v1/dependents/{id}/threshold`
- **REST Incidents**: `GET /api/v1/incidents`, `GET /api/v1/incidents/{id}`, `POST /api/v1/incidents/{id}/view`, `PATCH /api/v1/incidents/{id}/status`, `DELETE /api/v1/incidents/{id}`
- **REST Report**: `GET /api/v1/incidents/{id}/report` -> `application/pdf`
- **WebSocket**: `/ws?token=<jwt>`
  - Event payload envelope:
    ```json
    {
      "event": "incident.created | incident.critical | incident.escalated | incident.updated | incident.deleted",
      "timestamp": "2026-10-09T20:00:00Z",
      "data": { ... }
    }
    ```

## Code Layout & Write Boundaries
- **Backend Worker**: Strictly owns `backend/` (`backend/src/`, `backend/tests/`, `backend/pyproject.toml`, etc.). Must NOT touch `frontend/` or `simulator/`.
- **Frontend Worker**: Strictly owns `frontend/` (`frontend/lib/`, `frontend/test/`, `frontend/android/`, `frontend/pubspec.yaml`, etc.). Must NOT touch `backend/` or `simulator/`.
- **Simulator Worker**: Strictly owns `simulator/` (`simulator/index.html`, `simulator/style.css`, `simulator/app.js`, `simulator/config.js`, `simulator/Dockerfile`). Must NOT touch `backend/` or `frontend/`.
- **Documentation Worker**: Strictly owns `docs/`, `README.md`, and technical documentation files.
- **Integration Worker**: Owns `docker-compose.yml`, root integration tests (`tests/e2e/`), and `plano de ação/integracao/04_checklist_final_mvp_tcc.md`.
