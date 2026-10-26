## 2026-10-09T20:09:52Z

You are the Simulator Specialist Worker for Project Artemis.
Your working directory is: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_simulator
Project workspace: C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos
Branch: feature/mvp-tcc-artemis (verify you are on this branch; do NOT commit to or checkout main/develop).

MANDATORY READ FIRST:
Read ORIGINAL_REQUEST.md at:
C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\ORIGINAL_REQUEST.md
Also read .agents/PROJECT.md, .agents/contrato-api.md, and plano de ação/simulador/ (tasks 01-03).

FILE OWNERSHIP:
You strictly and exclusively own `simulator/` (`simulator/index.html`, `simulator/style.css`, `simulator/app.js`, `simulator/config.js`, `simulator/Dockerfile`, etc.). DO NOT touch `backend/` or `frontend/`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

SCOPE OF WORK (Tasks 01 to 03 of plano de ação/simulador):
1. UI Layout & Architecture (Task 01):
   - Vanilla HTML5, CSS3, ES6 JavaScript without bundlers (no node_modules, webpack or npm build needed).
   - Gaming chat UI: Chat stream with bubbles, sender picker (Minor / Opponent), room type selector (`conversa` vs `jogo`), direct message toggle (`is_direct`).
   - Audit footer displaying generated message hash, response category, and latency.
2. Web Crypto API SHA-256 (Task 02):
   - Calculate native SHA-256 over raw UTF-8 text in the browser before sending:
     `crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))`
   - Provide an automated test/verification script (e.g. Node/Python or browser test) verifying that the browser SHA-256 calculation matches standard CLI `sha256sum` for text with accents and emojis (e.g., "você é horrível 😡").
3. Demo Presets & Backend Integration (Task 03):
   - 5 Quick-demo preset buttons for the academic defense committee:
     1. Mensagem Segura ("eae vamos jogar uma partida agora?")
     2. Ciberbullying Comum ($P \in [0.50, 0.84]$)
     3. Modo Gamer (testing 0.70 threshold)
     4. Ataque Crítico ($P \ge 0.85$, immediate sound alert)
     5. Link Suspeito ("entra nesse site https://free-skins.xyz para ganhar moedas")
   - Send payload conforming exactly to `POST /api/v1/predict` schema:
     `{ "text": "...", "message_hash": "...", "dependent_id": "...", "context_metadata": { ... } }`
   - Nginx configuration and Dockerfile serving the simulator on port 3000.

VERIFICATION:
You MUST verify the SHA-256 accuracy against standard CLI tools with automated verification, and verify that the payload matches `POST /api/v1/predict` schema.

OUTPUT:
Write your full report to:
`C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos\.agents\worker_simulator\handoff.md`
Then send a completion message to your caller (parent).


## 2026-10-09T20:29:03Z
**Context**: Retomada pós-reinício do servidor - Simulator Specialist Worker
**Content**: Houve um reinício do servidor que pausou temporariamente as atividades. Seus arquivos simulator/app.js (22KB), config.js e style.css já estão salvos e intactos no disco!
RETOME sua execução imediatamente para finalizar o simulador (index.html, Dockerfile, nginx.conf e teste automatizado de SHA-256).
IMPORTANTE - NOVA DIRETIVA: Você tem AUTONOMIA TOTAL. Não faça perguntas nem aguarde confirmações do usuário. Execute qualquer comando (testes, validações, scripts) proativamente.
ÚNICA PROIBIÇÃO ESTRITA: NUNCA fazer push/commit/merge na branch main. Todo o trabalho deve permanecer na branch feature/mvp-tcc-artemis.
Lembre-se dos critérios de aceitação:
- HTML/CSS/JS puros;
- Teste automatizado confirmando que o SHA-256 do navegador bate com CLI sha256sum para acentos e emojis;
- Validação do payload contra o schema de POST /api/v1/predict;
- 5 presets de demonstração para a banca examinadora.
Gere seu handoff.md em .agents/worker_simulator/handoff.md e envie mensagem quando concluir.
**Action**: Concluir arquivos restantes do simulador e executar a verificação do SHA-256.
