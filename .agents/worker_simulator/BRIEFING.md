# BRIEFING — 2026-10-09T20:10:50Z

## Mission
Implement the Artemis Chat Simulator (UI Layout, Web Crypto SHA-256 calculation, Demo Presets, Backend Integration, and Docker/Nginx packaging) with automated verification.

## 🔒 My Identity
- Archetype: worker_simulator
- Roles: implementer, qa, specialist
- Working directory: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_simulator
- Original parent: 2489206b-696d-4e56-85b3-cc96ecb71833
- Milestone: MVP TCC Artemis - Simulator (Tasks 01 to 03)

## 🔒 Key Constraints
- Strictly own `simulator/` directory only. DO NOT touch `backend/` or `frontend/`.
- No bundlers / build tools for simulator: Vanilla HTML5, CSS3, ES6 JavaScript.
- Web Crypto API SHA-256 calculation native in browser: `crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))`
- Verification of SHA-256 against CLI tools (handling accents and emojis).
- 5 Quick-demo presets tailored for academic defense committee.
- Conformance to `POST /api/v1/predict` schema.
- Nginx configuration and Dockerfile serving simulator on port 3000.
- Mandatory integrity: Genuine implementation, no hardcoded values or fake logic.
- Remain on branch `feature/mvp-tcc-artemis`.

## Current Parent
- Conversation ID: 2489206b-696d-4e56-85b3-cc96ecb71833
- Updated: not yet

## Task Summary
- **What to build**: Simulator web client simulating a gaming chat stream, computing client-side SHA-256 hash, sending payloads to `POST /api/v1/predict`, displaying audit footer, preset buttons, audio/visual cues for toxicity, and dockerized via nginx on port 3000.
- **Success criteria**: Functional gaming chat UI, accurate SHA-256 calculation matching CLI `sha256sum`, complete 5 presets, verified payload schema compliance, working automated tests, dockerfile/nginx.conf.
- **Interface contracts**: `.agents/contrato-api.md`, `.agents/PROJECT.md`
- **Code layout**: `simulator/index.html`, `simulator/style.css`, `simulator/app.js`, `simulator/config.js`, `simulator/Dockerfile`, `simulator/nginx.conf`

## Key Decisions Made
- [TBD]

## Artifact Index
- `.agents/worker_simulator/DISPATCH.md` — Assigned dispatch prompt
- `.agents/worker_simulator/BRIEFING.md` — Agent state and briefing
- `.agents/worker_simulator/progress.md` — Liveness and progress tracker
- `.agents/worker_simulator/handoff.md` — Final 5-component handoff report

## Change Tracker
- **Files modified**: None yet
- **Build status**: Pending
- **Pending issues**: None

## Quality Status
- **Build/test result**: Pending
- **Lint status**: 0 violations
- **Tests added/modified**: Pending

## Loaded Skills
- None specified by dispatch
