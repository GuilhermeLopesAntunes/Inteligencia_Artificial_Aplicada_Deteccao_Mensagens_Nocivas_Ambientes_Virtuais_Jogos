# Relatório de Levantamento e Diagnóstico do Repositório (Project Artemis)

**Data:** 2026-10-09  
**Explorador:** Repository Explorer (`explorer_survey_repo`)  
**Workspace:** `C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos`  
**Branch Ativa:** `feature/mvp-tcc-artemis` (isolamento garantido conforme Requisito R6)  

---

## 1. Resumo Executivo

O **Project Artemis** é uma solução de controle parental inteligente voltada à detecção automatizada de ciberbullying em mensagens de texto em tempo quase-real usando **BERTimbau** (CPU) e heurística de detecção de links (`DetectorDeLinks`), com entrega de alertas via WebSocket para um app Android Flutter e geração de laudo probatório em PDF com hash SHA-256.

O repositório encontra-se em estágio de **esqueleto inicial (scaffolding)**, com documentação arquitetural, regras de negócio e planos de ação ricamente detalhados na pasta `.agents/` e `plano de ação/`, porém com o código-fonte de implementação ainda incipiente nos três eixos técnicos (Backend, Frontend e Simulador).

A ramificação de trabalho foi criada e ativada com sucesso em `feature/mvp-tcc-artemis`, garantindo total conformidade com o Requisito **R6** (nenhum commit direto na `main` ou `develop`).

---

## 2. Estado do Controle de Versão (Git & R6)

### 2.1. Diagnóstico Inicial
- **Ramo anterior:** `develop` (`refs/heads/develop`)
- **Ramos locais existentes:** `develop`, `main`
- **Requisito R6:** Todo o trabalho deve ser isolado em uma nova branch para que o usuário revise e realize o merge posteriormente.

### 2.2. Ação Executada
- Executado o checkout da nova branch:
  ```bash
  git checkout -b feature/mvp-tcc-artemis
  ```
- **Confirmação:** O arquivo `.git/HEAD` aponta formalmente para:
  `ref: refs/heads/feature/mvp-tcc-artemis`

---

## 3. Diagnóstico de Ferramental e CLI

| Ferramenta | Status / Versão Detectada | Observações Operacionais |
| :--- | :--- | :--- |
| **Git** | `git version 2.55.0.windows.5` | Operacional no host |
| **Docker** | `Docker version 29.7.2, build a7dcaa6` | Docker Desktop ativo e pronto para `docker compose up` |
| **Flutter SDK** | `Flutter 3.47.6 (channel stable)` | Dart `3.13.5`, DevTools `2.60.0` instalados no host |
| **Python Host** | Alias MS Store no comando `python` padrão | A execução local do backend/testes pode ser realizada via container Docker (`python:3.11-slim`), via launcher `py` do Windows ou apontando explicitamente para o interpretador Python 3.11 instalado. |

---

## 4. Diagnóstico Detalhado por Módulo

### 4.1. Raiz do Repositório (`/`)
- **`docker-compose.yml`**: Configurado com 3 serviços:
  - `backend`: Build `./backend`, porta `8000:8000`, volumes `./models:/models:ro` e `./backend/data:/app/data`, envs `APP_ENV`, `MODEL_DIR`, `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS`.
  - `simulator`: Build `./simulator`, porta `3000:80`, Nginx estático.
  - `scripts`: Build `./scripts`, profile `training`, porta `8888:8888`, GPU NVIDIA.
- **`.gitignore`**: Configurado corretamente para ignorar `.env`, `__pycache__`, `backend/data/`, `*.db`, `models/`, `frontend/build/`, datasets e checkpoints temporários.
- **`.env.example`**: Presente (`JWT_SECRET=troque-por-um-segredo-longo-e-aleatorio`).
- **`README.md` & `AGENTS.md`**: Completos e atualizados, descrevendo o monorepo, a arquitetura e as regras gerais.

---

### 4.2. Backend (`/backend`)

#### Situação Atual dos Arquivos:
- `Dockerfile`: Presente (`python:3.11-slim`, instala `build-essential`, `curl`, dependências de `requirements.txt`, expõe 8000, inicia com 1 worker uvicorn).
- `requirements.txt`: Contém `fastapi==0.110.1`, `uvicorn[standard]==0.29.0`, `pydantic==2.6.4`, `pydantic-settings==2.2.1`, `torch` (via extra-index CPU), `transformers`, `sqlalchemy>=2.0`, `argon2-cffi`, `PyJWT`, `reportlab`, `pytest`, `httpx`.
- `src/main.py`: App FastAPI básico com CORS e rota de health check `GET /`.
- `src/api/core/config.py`: Settings com `pydantic-settings` (`app_env`, `model_dir`, `database_url`, `jwt_secret`, `cors_origins`).
- `src/api/core/model_loader.py`: Lazy loader (`@lru_cache`) para carregar BERTimbau de disco.
- `src/api/v1/predict.py`: Rota protótipo simples que aceita `{ "text": "..." }` e devolve `{ "text", "label", "confidence" }`.
- `AGENTS.md`: Guia de arquitetura limpa em camadas para o backend.

#### Lacunas Críticas Identificadas:
1. **Divergência de Contrato em `/api/v1/predict`:** O endpoint atual espera apenas `text`. O contrato oficial (`.agents/contrato-api.md`) exige `text`, `message_hash`, `dependent_id`, `context_metadata` (`conversation_id`, `room_type`, `sender_id`, `is_from_minor`, `is_direct`, `timestamp`), e deve devolver `category`, `confidence`, `has_link`, `action_required`, `detected_role`, `sha256_match`, `incident_id`, `inference_time_ms`.
2. **Estrutura de Camadas Faltante:** Não existem ainda as pastas e módulos:
   - `src/domain/` (`entities.py`, `enums.py`, `rules.py` com `AvaliadorDecisaoRisco`).
   - `src/infrastructure/` (`database.py`, repositórios SQLAlchemy, `link_detector.py`, `in_memory_buffer.py`).
   - `src/services/` (`analise_service.py`, `gestao_incidente_service.py`, `relatorio_service.py`, `escalonamento_service.py`).
3. **Rotas da API Ausentes:** Faltam implementar:
   - `/api/v1/auth/login` e `/api/v1/auth/me` (JWT e guardiões).
   - `/api/v1/dependents` e `/api/v1/dependents/{id}/threshold`.
   - `/api/v1/incidents` (listagem com paginação e filtros).
   - `/api/v1/incidents/{id}` e `/incidents/{id}/view` (marcação de visualizado).
   - `/api/v1/incidents/{id}/status` (transições e falso positivo com feedback).
   - `/api/v1/incidents/{id}/report` (geração de PDF ReportLab com SHA-256).
   - `/api/v1/incidents/{id}` (exclusão definitiva LGPD).
   - `/ws?token=<jwt>` (Gateway WebSocket para push em tempo real).
4. **Seed de Demonstração:** Falta `src/seed.py` com `resp-001`, `resp-002`, `dep-001`, `dep-002`.
5. **Testes Automatizados:** Não existem `tests/`, `conftest.py` nem `pytest.ini`.

---

### 4.3. Frontend (`/frontend`)

#### Situação Atual dos Arquivos:
- Projeto Flutter padrão gerado.
- `pubspec.yaml`: Apenas dependências padrão (`flutter`, `cupertino_icons`, `flutter_lints`).
- `lib/main.dart`: Código padrão do Flutter Counter (contador de cliques).
- `test/widget_test.dart`: Teste padrão do contador.
- `AGENTS.md`: Guia de implementação do app parental para Android.

#### Lacunas Críticas Identificadas:
1. **Dependências Ausentes no `pubspec.yaml`:**
   - `http` (comunicação REST).
   - `web_socket_channel` (alertas em tempo real).
   - `flutter_secure_storage` (armazenamento de token JWT).
   - `flutter_local_notifications` (som e notificação para incidentes críticos).
   - `path_provider` e `open_filex` (download e abertura do PDF do laudo).
2. **Configurações de Android (`AndroidManifest.xml`):**
   - Falta incluir `android:usesCleartextTraffic="true"` para comunicação HTTP sem TLS com `http://10.0.2.2:8000`.
   - Falta permissão `android.permission.INTERNET`.
   - Falta permissão `android.permission.POST_NOTIFICATIONS` (Android 13+).
3. **Camadas e Telas Ausentes em `lib/`:**
   - `config.dart` (`API_BASE_URL` via `--dart-define`).
   - `models/`: `incident.dart`, `dependent.dart`, `guardian.dart` (compatíveis com `.agents/contrato-api.md`).
   - `services/`: `api_service.dart`, `websocket_service.dart`, `notification_service.dart`.
   - `screens/`: Login (UC-18), Feed de Incidentes (UC-09), Detalhe do Incidente (UC-09/04/17), Configurações do Dependente/Calibração (UC-03).
   - Mock Service para desacoplamento e testes offline.
4. **Testes Automatizados:** Testes de widget e de fluxo de tela com mock service.

---

### 4.4. Simulador de Chat Web (`/simulator`)

#### Situação Atual dos Arquivos:
- `Dockerfile`: Imagem `nginx:alpine` copiando os arquivos estáticos para `/usr/share/nginx/html`.
- `AGENTS.md`: Especificação completa do simulador.

#### Lacunas Críticas Identificadas:
1. **Arquivos Inexistentes:** A pasta não possui `index.html`, `style.css`, `config.js` nem `app.js`.
2. **Implementação Requerida:**
   - `index.html`: Interface com seletores de dependente (`CONFIG.DEPENDENTS`), tipo de sala (`jogo` ou `conversa`), `conversation_id`, quem envia (`is_from_minor`), tipo de mensagem (`is_direct`), área de histórico de chat e botões de cenários rápidos de teste.
   - `app.js`: Implementação em JavaScript Vanilla usando `crypto.subtle.digest("SHA-256", ...)` e `fetch` para disparar `POST /api/v1/predict`.
   - `style.css`: Estilização limpa e responsiva com badges visuais para os níveis de severidade/ação requerida.

---

### 4.5. Modelos (`/models`)

#### Situação Atual:
- O diretório `models/` **não existe** localmente no disco (e está no `.gitignore`).
- Repositório remoto do checkpoint: `GuilhermeLA/modelo-tcc-final` no Hugging Face Hub.
- Estratégia de execução:
  - Nos testes unitários e de integração do backend, `APP_ENV=testing` deve ativar um classificador simulado (mock) em conformidade com as regras de negócio, sem exigir download de pesos ou GPU.
  - Para o teste de integração E2E final com pesos reais, o checkpoint pode ser baixado via CLI `hf download GuilhermeLA/modelo-tcc-final --local-dir models/modelo_tcc_final` ou montado no volume Docker correspondente.

---

## 5. Matriz de Rastreabilidade e Conformidade (Fontes de Verdade)

| Documento de Referência | Papel no Projeto | Status de Alinhamento |
| :--- | :--- | :--- |
| `.agents/regras-de-negocio.md` | **Fonte Suprema de Regras** (Limiares 0.50/0.70/0.85, buffer 3 msgs, ciclo de vida de status, LGPD) | Esqueleto atual diverge; precisa de implementação integral na camada de domínio. |
| `.agents/contrato-api.md` | **Fonte Suprema de API** (Schemas REST, rotas, códigos HTTP, WebSocket) | Rota atual `/predict` é protótipo incompatível; deve ser refatorada para o schema completo. |
| `plano de ação/backend/` | Roteiro das tasks 01 a 05 | Mapeado e pronto para execução pelo Agente Backend. |
| `plano de ação/frontend/` | Roteiro das tasks 01 a 05 | Mapeado e pronto para execução pelo Agente Frontend. |
| `plano de ação/simulador/` | Roteiro das tasks 01 a 03 | Mapeado e pronto para execução pelo Agente Simulador. |
| `plano de ação/integracao/` | Roteiro das tasks 01 a 04 | Aguardará a conclusão de Backend e Frontend. |

---

## 6. Próximos Passos Recomendados para a Equipe de Agentes

1. **Agente Backend:**
   - Implementar camada `domain/` (`rules.py`, `enums.py`, `entities.py`) com testes unitários BVA de limiares.
   - Implementar `infrastructure/` (`database.py`, `link_detector.py`, `in_memory_buffer.py`) e refatorar `model_loader.py` com factory mock quando `APP_ENV=testing`.
   - Implementar `services/` e rotas completas em `api/v1/` e `websocket.py` alinhadas a `.agents/contrato-api.md`.
   - Criar `seed.py`, `conftest.py` e bateria de testes `pytest` 100% verde.
2. **Agente Frontend:**
   - Atualizar `pubspec.yaml` com pacotes necessários e configurar `AndroidManifest.xml`.
   - Criar contratos de mock, modelos de dados e serviços desacoplados.
   - Implementar as 4 telas essenciais e testes de widget (`flutter test`).
3. **Agente Simulador:**
   - Criar `index.html`, `style.css`, `config.js` e `app.js` com SHA-256 Web Crypto API e cenários rápidos de demonstração.
4. **Agente de Documentação:**
   - Acompanhar e registrar comandos de execução, configurações e evidências de testes para a monografia e banca.
