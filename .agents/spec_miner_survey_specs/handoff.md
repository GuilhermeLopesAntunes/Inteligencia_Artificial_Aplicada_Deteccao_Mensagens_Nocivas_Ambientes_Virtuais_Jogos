# Handoff Report — Spec Miner Survey Specs

## 1. Observation
- Inspected `ORIGINAL_REQUEST.md` (lines 1–69): project goals, MVP timeline (20/10/2026), acceptance criteria for Backend, Frontend, Simulator, Integration, and Documentation.
- Inspected `.agents/regras-de-negocio.md` (lines 1–139):
  - Section 1 (lines 5–11): `confidence` is always $P(\text{nocivo})$, `label` is raw threshold 0.50 (`"nocivo"` if $P \ge 0.50$ else `"normal"`), business decision in `category` and `action_required`.
  - Section 2 (lines 12–22): Critical threshold fixed at 0.85; common threshold calibrated per dependent ($0.50$ to $0.84$); Gamer Mode effective threshold $L = \max(\text{limiar\_comum}, 0.70)$ when `room_type = "jogo"`.
  - Section 3 (lines 23–37): Decision table evaluated sequentially: (1) $P \ge 0.85 \implies \text{CIBERBULLYING} / \text{ALERT\_PARENT\_CRITICAL}$; (2) $L \le P < 0.85 \implies \text{CIBERBULLYING} / \text{LOG\_INCIDENT}$; (3) $P < L$ and `has_link` $\implies \text{LINK\_SUSPEITO} / \text{LOG\_INCIDENT}$; (4) $P < L$ and not `has_link` $\implies \text{SEGURO} / \text{NONE}$.
  - Section 4 (lines 38–49): Role derivation (`is_from_minor` $\implies$ `EMISSOR`; not minor and direct $\implies$ `VITIMA`; not minor and not direct $\implies$ `ESPECTADOR`).
  - Section 5 (lines 50–55): SHA-256 integrity calculated on raw text in client, validated on backend; mismatch does not block, sets `integridade_divergente = true`.
  - Section 6 (lines 56–62): Normalization preserves emojis and stopwords; tokenizer truncates to 512; empty/whitespace text returns HTTP 400.
  - Section 7 (lines 63–78): Circular buffer in memory (last 3 messages per conversation); incident copies up to 3 prior messages and accepts up to 3 subsequent messages within 10 minutes.
  - Section 8 (lines 79–83): Safe messages are not persisted to database, only increment aggregate counter.
  - Section 9 (lines 84–101): Lifecycle states (`DETECTADO` $\rightarrow$ `VISUALIZADO` via system view; `VISUALIZADO` $\rightarrow$ `EM_ANALISE`, `FALSO_POSITIVO`; `EM_ANALISE` $\rightarrow$ `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO`, `RESOLVIDO`; final states `FALSO_POSITIVO` and `RESOLVIDO`; invalid transition returns HTTP 409).
  - Section 10 (lines 102–112): WebSocket notification delivery: `incident.created` (all guardians, no sound), `incident.critical` (only primary, sound), `incident.escalated` (secondary guardians, sound), `incident.updated`/`incident.deleted` (all guardians, no sound).
  - Section 11 (lines 113–120): Escalation task runs every 60s for critical incidents pending visual inspection $> 15$ min.
  - Section 12 (lines 121–129): Permissions: only primary can calibrate threshold, generate invite, delete incident. Non-linked entity returns 404; unauthorized primary action by secondary returns 403.
  - Section 14 (lines 136–139): LGPD hard deletion of incident, context messages, history, and feedback.
- Inspected `.agents/contrato-api.md` (lines 1–345):
  - Endpoints: `GET /`, `POST /api/v1/auth/login`, `GET /api/v1/auth/me`, `POST /api/v1/auth/register` (optional), `POST /api/v1/predict`, `GET /api/v1/dependents`, `PATCH /api/v1/dependents/{id}/threshold`, `POST /api/v1/dependents/{id}/invites` (optional), `GET /api/v1/incidents`, `GET /api/v1/incidents/{id}`, `POST /api/v1/incidents/{id}/view`, `PATCH /api/v1/incidents/{id}/status`, `GET /api/v1/incidents/{id}/report`, `DELETE /api/v1/incidents/{id}`, `WS /ws?token=<jwt>`.
  - Seed entities: `resp-001`, `resp-002`, `dep-001`, `dep-002`.
- Inspected `.agents/arquitetura.md`, `padroes-de-projeto.md`, `testes.md`, `requisitos.md`, `casos-de-uso.md`, `modelagem-uml.md`, and module `AGENTS.md` files:
  - Architecture: Layered Clean Architecture (`domain/`, `services/`, `infrastructure/`, `api/`).
  - Domain isolation: `domain/` contains zero framework dependencies (no PyTorch, no SQLAlchemy).
  - Design Patterns: Virtual Proxy (Lazy Loading model weights for $< 2$s boot), Strategy (checkpoints), Factory Method (Mock vs Real model based on `APP_ENV`), Observer (WebSocket dispatch), Template Method (ReportLab PDF export).
  - BVA Matrix: Exact boundaries at 0.00, 0.499, 0.500, 0.849, 0.850, 1.000, Gamer mode floor 0.70, customized thresholds.

## 2. Logic Chain
1. *Premise:* Any divergence between documentation files must resolve strictly according to the stated hierarchy (`regras-de-negocio.md` and `contrato-api.md` take absolute precedence over architectural sketches or secondary requirements).
2. *Deduction on Field Semantics:* Because Section 1 of `regras-de-negocio.md` explicitly dictates that `confidence` is always $P(\text{nocivo})$ and `label` is evaluated against 0.50 regardless of room type or calibration, frontend and simulator consumers must rely on `category` and `action_required` for business behavior.
3. *Deduction on Performance:* Because acceptance criteria mandate Uvicorn boot in $< 2$ seconds while PyTorch model weights take $\sim 440$ MB, the Virtual Proxy pattern is required to defer disk I/O until the first prediction request.
4. *Deduction on Test Architecture:* By implementing a `ClassificadorFactory` conditioned on `APP_ENV=testing`, unit and integration tests run in milliseconds without downloading or loading 440 MB neural weights.
5. *Deduction on Proving Integrity:* The client computes SHA-256 via Web Crypto API over the verbatim text. Backend validates this hash, flags divergence if needed, and embeds both the hash and validation verdict into the generated PDF report.

## 3. Caveats
- Production features explicitly categorized as "Trabalho Futuro" (e.g. UC-14 analytics dashboard, UC-15 accessibility mode, UC-16 executive summary, native Android background message capture, real FCM push notifications) are not part of the MVP and should not be implemented in this cycle.
- "Se sobrar tempo" features (UC-06 co-parental invite codes, UC-12 15-minute escalation, UC-07 false positive feedback notes, UC-08 pedagogical CNV cards) are secondary and must only be touched once core MVP test suites are 100% green.

## 4. Conclusion
The authoritative specifications have been exhaustively surveyed, reconciled, and documented into `C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\spec_miner_survey_specs\survey_specs_report.md`. The implementation teams for Backend, Frontend, Simulator, and Integration now possess an unambiguous, verified, and complete blueprint of all business rules, thresholds, API schemas, design patterns, and test criteria.

## 5. Verification Method
1. Inspect the generated report: `C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\spec_miner_survey_specs\survey_specs_report.md`.
2. Cross-reference all 14 business rules with `.agents/regras-de-negocio.md`.
3. Cross-reference all 14 endpoints and 5 WebSocket events with `.agents/contrato-api.md`.
4. Invalidation condition: Any change in `.agents/regras-de-negocio.md` or `.agents/contrato-api.md` that modifies threshold formulas, route schemas, or state transitions would require regenerating sections 4 and 5 of the report.
