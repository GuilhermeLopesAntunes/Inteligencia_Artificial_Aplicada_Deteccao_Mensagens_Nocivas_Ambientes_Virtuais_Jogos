# Documentação de Implementação e Arquitetura do Backend (`Project Artemis`)

Este documento registra todas as entregas realizadas no backend (`backend/`), organizadas no formato **`feat(nome-do-modulo)`**, listando o que foi implementado em cada módulo, os arquivos correspondentes e a explicação detalhada de cada arquivo, classe e função do sistema.

---

## Sumário de Módulos (`feat`)

1. [`feat(core)`](#1-featcore--configuração-segurança-jwt-e-loader-do-modelo-bertimbau) — Configuração de Ambiente, Segurança JWT e Carregamento *Lazy* do Modelo BERTimbau
2. [`feat(domain)`](#2-featdomain--entidades-enums-e-regras-puras-de-negócio) — Entidades, Enums e Regras Puras de Negócio (Limiares, Modo Gamer, Papel do Menor e Máquina de Estados)
3. [`feat(infrastructure)`](#3-featinfrastructure--engine-bertimbau-detector-de-links-buffer-circular-e-banco-de-dados) — Engine BERTimbau (*Strategy*/*Proxy*), Detector de Links, Buffer em Memória e Persistência SQLAlchemy/SQLite
4. [`feat(services)`](#4-featservices--orquestração-de-análise-gestão-de-incidentes-e-relatório-pdf-sha-256) — Serviços de Aplicação (Pipeline de Análise, Gestão de Incidentes e Relatório Probatório PDF)
5. [`feat(api-v1)`](#5-featapi-v1--endpoints-rest-autenticação-incidentes-e-gateway-websocket) — Controladores REST (`/predict`, `/auth`, `/dependents`, `/incidents`) e Gateway WebSocket (`/ws`)
6. [`feat(tests)`](#6-feattests--suíte-de-testes-unitários-bva-integração-e-validação-real-do-bertimbau) — Testes Unitários (Análise de Valor Limite), Integração REST/WS e Validação Empírica do BERTimbau

---

## 1. `feat(core)` — Configuração, Segurança JWT e Loader do Modelo BERTimbau

### O que foi feito
* Centralização das variáveis de ambiente via `pydantic-settings` (caminhos automáticos para o diretório `models/modelo_tcc_final` e banco SQLite local/Docker).
* Implementação do carregamento preguiçoso (*Lazy Loading*) e em cache (`@lru_cache(maxsize=1)`) do modelo **BERTimbau** (`GuilhermeLA/modelo-tcc-final`) em CPU, resolvendo falhas de `mmap` do `safetensors` no Windows ao carregar o `state_dict` diretamente em memória RAM.
* Implementação da autenticação JWT (`HS256`) integrada ao esquema `HTTPBearer` para habilitar o botão **Authorize 🔒** no Swagger UI (`/docs`).

### Arquivos do módulo
* `backend/src/api/core/config.py`
* `backend/src/config.py`
* `backend/src/api/core/model_loader.py`
* `backend/src/api/core/security.py`

### Explicação de cada arquivo e suas funções

#### 📄 `backend/src/api/core/config.py` (e `backend/src/config.py`)
Define as configurações globais da aplicação a partir de variáveis de ambiente ou arquivo `.env`.
* **`Settings(BaseSettings)`**: Classe Pydantic que carrega:
  * `app_env`: Ambiente de execução (`"production"` ou `"testing"`).
  * `model_dir`: Caminho absoluto para os artefatos do modelo (`models/modelo_tcc_final`).
  * `model_version`: Identificador do modelo (`"GuilhermeLA/modelo-tcc-final"`).
  * `database_url`: String de conexão SQLite (`sqlite:///.../backend/data/artemis.db`).
  * `jwt_secret`, `jwt_algorithm` (`"HS256"`), `jwt_access_token_expire_minutes` (`1440` min = 24h).
  * `cors_origins`: Origens permitidas no CORS (`http://localhost:3000`).

#### 📄 `backend/src/api/core/model_loader.py`
Responsável pelo ciclo de vida dos pesos neurais do BERTimbau em memória e pela inferência em CPU.
* **`get_model()`**: Decorada com `@lru_cache(maxsize=1)`. Na primeira chamada, carrega o `AutoTokenizer`, o `AutoConfig` e os tensores de `model.safetensors` via `safetensors.torch.load`, instancia `AutoModelForSequenceClassification.from_config(config)`, aplica `model.load_state_dict(state_dict, strict=True)` e coloca a rede em modo de avaliação (`model.eval()`). Nas chamadas seguintes, retorna a tupla `(tokenizer, model)` instantaneamente da RAM.
* **`is_model_loaded() -> bool`**: Inspeciona `get_model.cache_info().currsize > 0` para informar ao endpoint de Health Check (`GET /`) se o modelo já foi carregado na memória.
* **`classify_text(text: str) -> tuple[str, float]`**: Tokeniza o texto com truncamento seguro (`truncation=True, max_length=512, return_tensors="pt"`), executa a passagem *forward* com `torch.no_grad()` (economizando memória e CPU), extrai a probabilidade da classe nociva via `torch.softmax(logits, dim=-1)[0][1].item()` e retorna `(label, p_nocivo)`, onde `label` é `"nocivo"` se $P \ge 0.50$ ou `"normal"` se $P < 0.50$.

#### 📄 `backend/src/api/core/security.py`
Gerencia a criação e validação de tokens JWT e a integração com o Swagger UI.
* **`bearer_scheme = HTTPBearer(auto_error=False)`**: Habilita o cadeado **Authorize 🔒** no Swagger UI (`/docs`).
* **`create_access_token(data: dict, expires_delta: Optional[timedelta]) -> str`**: Gera e assina o token JWT com `sub = guardian_id` e expiração de 24 horas.
* **`get_current_guardian_id(request: Request, credentials: HTTPAuthorizationCredentials) -> str`**: Dependency do FastAPI que extrai o token do header `Authorization: Bearer <token>` (ou query param), valida a assinatura e expiração via `PyJWT` e retorna o ID do responsável autenticado (ou lança `HTTP 401 Unauthorized`).

---

## 2. `feat(domain)` — Entidades, Enums e Regras Puras de Negócio

### O que foi feito
* Modelagem das entidades e enumerações de domínio livres de dependências externas (sem banco de dados ou frameworks web).
* Implementação da tabela de decisão de risco em ordem estrita de prioridade (Crítico $\ge 0.85$, Comum $\ge L$, Link Suspeito e Seguro).
* Implementação do **Modo Gamer** ($L = \max(\text{limiar\_comum}, 0.70)$ em salas do tipo `"jogo"`).
* Implementação da derivação determinística do papel do menor (`EMISSOR`, `VITIMA`, `ESPECTADOR`) a partir dos metadados da mensagem.
* Implementação da máquina de estados do ciclo de vida do incidente e validação de transições manuais vs automáticas.

### Arquivos do módulo
* `backend/src/domain/enums.py`
* `backend/src/domain/entities.py`
* `backend/src/domain/rules.py`
* `backend/src/domain/__init__.py`

### Explicação de cada arquivo e suas funções

#### 📄 `backend/src/domain/enums.py`
Define todas as enumerações canônicas do domínio:
* **`CategoriaAmeaca`**: `SEGURO`, `CIBERBULLYING`, `LINK_SUSPEITO`.
* **`SeveridadeIncidente`**: `NENHUMA`, `COMUM`, `CRITICO`.
* **`AcaoRequerida`**: `NONE`, `LOG_INCIDENT`, `ALERT_PARENT_CRITICAL`.
* **`PapelMenor`**: `VITIMA`, `EMISSOR`, `ESPECTADOR`.
* **`StatusIncidente`**: `DETECTADO`, `VISUALIZADO`, `EM_ANALISE`, `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO`, `RESOLVIDO`.
* **`TipoEventoWS`**: `incident.created`, `incident.critical`, `incident.escalated`, `incident.updated`, `incident.deleted`.

#### 📄 `backend/src/domain/entities.py`
Define as *dataclasses* de domínio:
* **`Mensagem`**: Representa uma mensagem analisada (`texto`, `remetente_id`, `eh_do_menor`, `timestamp`, `hash_sha256`, `sala_tipo`, `id_conversa`) e possui o método `to_context_dict()` para serialização em listas de contexto.
* **`Incidente`**: Representa um incidente detectado com sua mensagem principal, classificação (`categoria`, `severidade`, `confianca`, `tem_link`, `papel_detectado`, `acao_requerida`), validade do hash SHA-256 (`integridade_valida`), listas `contexto_antes` e `contexto_depois`, e `status`.
* **`Responsavel`** e **`Dependente`**: Entidades de domínio que representam os atores do controle parental.

#### 📄 `backend/src/domain/rules.py`
Concentra todas as funções puras de regras de negócio (`.agents/regras-de-negocio.md`):
* **`normalizar_texto(texto: str) -> str`**: Remove caracteres invisíveis (*zero-width*) e espaços redundantes, preservando emojis, pontuações e *stopwords*. Lança `ValueError` se o texto resultante for vazio.
* **`calcular_limiar_efetivo(limiar_comum: float, room_type: str) -> float`**: Retorna `limiar_comum` quando `room_type == "conversa"` e `max(limiar_comum, 0.70)` quando `room_type == "jogo"` (Modo Gamer).
* **`validar_calibracao_limiar(novo_limiar: float) -> float`**: Garante que a calibração do limiar comum pelo responsável primário esteja estritamente entre `0.50` e `0.84`.
* **`avaliar_risco(probabilidade_nocivo, limiar_comum, sala_tipo, tem_link) -> Tuple[CategoriaAmeaca, AcaoRequerida]`**: Aplica a tabela de decisão:
  1. $P \ge 0.85 \rightarrow (\text{CIBERBULLYING}, \text{ALERT\_PARENT\_CRITICAL})$
  2. $L \le P < 0.85 \rightarrow (\text{CIBERBULLYING}, \text{LOG\_INCIDENT})$
  3. $P < L \text{ e } \text{tem\_link} \rightarrow (\text{LINK\_SUSPEITO}, \text{LOG\_INCIDENT})$
  4. $P < L \text{ e não } \text{tem\_link} \rightarrow (\text{SEGURO}, \text{NONE})$
* **`AvaliadorDecisaoRisco.avaliar(...) -> ResultadoDecisaoRisco`**: Fachada de domínio que retorna um objeto imutável contendo `category`, `severity`, `action_required`, `label` e `persists_incident`.
* **`derivar_papel_menor(is_from_minor: bool, is_direct: bool) -> PapelMenor`** (e alias **`detectar_papel_menor`**):
  * `is_from_minor == True` $\rightarrow$ `EMISSOR`
  * `is_from_minor == False` e `is_direct == True` $\rightarrow$ `VITIMA`
  * `is_from_minor == False` e `is_direct == False` $\rightarrow$ `ESPECTADOR`
* **`eh_transicao_valida(status_atual, status_novo, manual=False) -> bool`**: Valida se a mudança de status respeita o grafo de estados (`TRANSIÇÕES_VALIDAS`). Quando `manual=True`, impede que `DETECTADO` ou `VISUALIZADO` sejam usados como destino manual.
* **`obter_transicoes_permitidas(status_atual) -> List[str]`**: Retorna os próximos status manuais permitidos a partir do status atual para exibição no aplicativo Flutter.

---

## 3. `feat(infrastructure)` — Engine BERTimbau, Detector de Links, Buffer Circular e Banco de Dados

### O que foi feito
* Aplicação dos padrões de projeto **Strategy**, **Virtual Proxy** e **Factory Method** sobre o motor de inferência do BERTimbau, permitindo alternar entre o modelo neural real em produção e um *Mock* determinístico ultrarrápido em testes.
* Implementação do `DetectorDeLinks` via expressão regular para capturar URLs (`http://`, `https://`, `www.`, domínios/IPs com path) sem falsos positivos em números decimais ou e-mails.
* Implementação do `InMemoryBuffer` para manter em RAM as últimas 3 mensagens de cada conversa (`context_before`) e anexar até 3 mensagens posteriores dentro de 10 minutos (`context_after`) a incidentes recém-abertos.
* Modelagem relacional SQLAlchemy (`models.py` e `database.py`) incluindo vínculo N:N entre responsáveis e dependentes com flag `is_primary` por dependente e script de `seed.py` com hashing Argon2.

### Arquivos do módulo
* `backend/src/infrastructure/bertimbau_engine.py`
* `backend/src/infrastructure/link_detector.py`
* `backend/src/infrastructure/in_memory_buffer.py`
* `backend/src/infrastructure/database.py`
* `backend/src/infrastructure/models.py`
* `backend/src/seed.py`

### Explicação de cada arquivo e suas funções

#### 📄 `backend/src/infrastructure/bertimbau_engine.py`
Implementa os padrões *Strategy*, *Proxy* e *Factory* para o classificador de linguagem natural:
* **`ClassificadorStrategy(ABC)`**: Interface base com os métodos `predict_probability(texto: str) -> float` e `predict_proba(texto: str) -> float`.
* **`RealBERTimbauEngine(ClassificadorStrategy)`**: Estratégia concreta que utiliza o tokenizer e o modelo BERTimbau real (`model_loader.py`) com truncamento em 512 tokens.
* **`BERTimbauEngineProxy(ClassificadorStrategy)`**: *Virtual Proxy* que adia a instanciação da `RealBERTimbauEngine` até a primeira chamada de predição e expõe a propriedade `is_loaded`.
* **`MockClassificadorStrategy(ClassificadorStrategy)`**: Estratégia leve usada quando `APP_ENV=testing` (suporta probabilidades customizadas e *overrides* por palavra-chave para testes de valor limite).
* **`ClassificadorFactory` / `BERTimbauFactory` / `MockClassificadorFactory`**: Fábricas que instanciam a estratégia adequada conforme o ambiente.
* **`classify_text(text: str) -> Tuple[str, float]`**: Fachada chamada pelo serviço de análise.

#### 📄 `backend/src/infrastructure/link_detector.py`
Heurística determinística complementar ao BERTimbau para detecção de links suspeitos:
* **`DetectorDeLinks.detectar_link(texto: str) -> bool`** (e método de instância **`has_link(texto: str) -> bool`**): Avalia via regex compilada (`_PATTERN_LINK`) a presença de links externos (`http://`, `https://`, `www.` ou domínios/IPs seguidos de `/caminho`), ignorando números decimais (ex: `3.14`) e endereços de e-mail.

#### 📄 `backend/src/infrastructure/in_memory_buffer.py`
Gerencia o contexto conversacional volátil em memória RAM (Regra de Negócio 7):
* **`MensagemBuffer`** (alias **`MensagemBufferItem`**): Estrutura que armazena `text`, `sender_id`, `is_from_minor` e `timestamp`, convertendo para dicionário JSON via `to_dict()`.
* **`IncidenteAbertoBuffer`**: Rastreia um incidente recém-criado que ainda aguarda até 3 mensagens posteriores dentro da janela de 10 minutos (`600` segundos).
* **`InMemoryBuffer`**:
  * `adicionar_mensagem(conversation_id, msg)`: Insere a mensagem no `deque(maxlen=3)` daquela conversa.
  * `obter_contexto_anterior(conversation_id) -> List[dict]`: Retorna cópia das até 3 mensagens anteriores presentes no buffer antes da mensagem atual.
  * `abrir_incidente_para_posteriores(conversation_id, incident_id, created_at)`: Registra um novo incidente na fila de incidentes abertos da conversa.
  * `anexar_mensagem_posterior(conversation_id, msg, now) -> List[IncidenteAbertoBuffer]`: Verifica todos os incidentes abertos da conversa; se o tempo decorrido for $\le 600\text{s}$ e houver $< 3$ mensagens posteriores, anexa a nova mensagem e retorna os incidentes atualizados para persistência no banco.

#### 📄 `backend/src/infrastructure/database.py`
Configura a conexão SQLAlchemy com o banco SQLite:
* Configura `engine` e `SessionLocal` (com `StaticPool` automático para bancos em memória e criação automática do diretório `backend/data/` para `artemis.db`).
* **`get_db()`**: Gerador de dependência do FastAPI que fornece uma sessão transacional por requisição e garante o fechamento ao final.
* **`create_tables()` / `init_db()`**: Cria todas as tabelas declaradas em `models.py`.

#### 📄 `backend/src/infrastructure/models.py`
Mapeamento Objeto-Relacional (ORM) das tabelas do banco SQLite:
* **`GuardianORM` (`guardians`)**: Tabela de responsáveis (`id`, `name`, `email`, `hashed_password`, `is_active`, `created_at`).
* **`DependentORM` (`dependents`)**: Tabela de dependentes (`id`, `name`, `common_threshold`, `safe_messages_count`, `created_at`).
* **`GuardianDependentORM` (`guardian_dependents`)**: Tabela associativa N:N entre responsáveis e dependentes com a coluna booleana `is_primary` (permitindo que um responsável seja primário de um dependente e secundário de outro).
* **`IncidentORM` (`incidents`)**: Tabela de incidentes persistidos (mensagem principal, hash SHA-256, `room_type`, `conversation_id`, categoria, severidade, confiança, papel do menor, `integrity_valid`, JSON de `context_before` e `context_after`, `status` e `escalated`).
* **`IncidentStatusHistoryORM` (`incident_status_history`)**: Trilha de auditoria de todas as mudanças de status (`from_status`, `to_status`, `note`, `guardian_name`, `changed_at`).
* **`FalsePositiveFeedbackORM` (`false_positive_feedbacks`)**: Armazena feedbacks de falsos positivos (UC-07) quando um incidente é marcado como `FALSO_POSITIVO`.
* **`CoParentingInviteORM` (`coparenting_invites`)**: Tabela de convites de co-parentalidade (UC-06).

#### 📄 `backend/src/seed.py`
Popula o banco de dados de forma idempotente com os dados canônicos de demonstração e teste:
* **`hash_password(password)`** e **`verify_password(plain_password, hashed_password)`**: Hashing e verificação segura de senhas utilizando `argon2-cffi` (`PasswordHasher`).
* **`seed_session(session)` / `seed_data(session)`**: Cria os responsáveis `resp-001` (Maria — `responsavel@exemplo.com` / `senha123`, primária de `dep-001` e `dep-002`) e `resp-002` (João — `joao@exemplo.com` / `senha456`, secundário de `dep-001`), além dos dependentes `dep-001` (Lucas) e `dep-002` (Ana) com `common_threshold = 0.50`.

---

## 4. `feat(services)` — Orquestração de Análise, Gestão de Incidentes e Relatório PDF (SHA-256)

### O que foi feito
* Implementação do pipeline completo de análise de mensagens em uma única passagem de inferência (evitando chamadas duplicadas ao BERTimbau).
* Verificação de integridade criptográfica SHA-256 sobre o texto bruto recebido antes da normalização textual.
* Persistência seletiva (LGPD): mensagens seguras nunca têm seu conteúdo gravado em disco, incrementando apenas `safe_messages_count` no dependente.
* Gestão de ciclo de vida de incidentes com visualização idempotente (`DETECTADO` $\rightarrow$ `VISUALIZADO`), validação de permissões (primário vs secundário), registro de feedback de falso positivo e exclusão definitiva (LGPD).
* Geração de relatório probatório em PDF (`ReportLab`) exibindo o hash SHA-256 de origem, o hash SHA-256 recalculado e o veredito de autenticidade (`AUTÊNTICO` vs `INTEGRIDADE DIVERGENTE`).

### Arquivos do módulo
* `backend/src/services/analise_service.py`
* `backend/src/services/gestao_incidente_service.py`
* `backend/src/services/relatorio_service.py`

### Explicação de cada arquivo e suas funções

#### 📄 `backend/src/services/analise_service.py`
Orquestra o fluxo principal de negócio na chegada de uma mensagem do simulador (Regra de Negócio 7):
* **`analisar_mensagem_completa(...) -> ResultadoAnaliseMensagem`** (e **`_executar_pipeline_analise`**):
  1. Calcula o SHA-256 em UTF-8 sobre o `texto` bruto recebido e compara com `message_hash` (`sha256_match`).
  2. Normaliza o texto via `normalizar_texto(texto)` e valida a existência do `dependent_id` no banco.
  3. **Passo 7.1:** Anexa a mensagem como contexto posterior (`context_after`) aos incidentes abertos da mesma conversa (até 3 mensagens / 10 minutos) e atualiza o banco.
  4. **Passo 7.2:** Executa `DetectorDeLinks.detectar_link`, a inferência do BERTimbau (`classify_text`), `avaliar_risco` (considerando o limiar calibrado do dependente e o Modo Gamer) e `detectar_papel_menor`.
  5. **Passo 7.3:** Se `acao_requerida != NONE`, cria o `IncidentORM` com as até 3 mensagens anteriores do buffer (`context_before`), cria o registro inicial em `IncidentStatusHistoryORM`, abre o incidente para receber mensagens posteriores e dispara notificações WebSocket (`incident.created` para todos os responsáveis vinculados e, se crítico, `incident.critical` para o responsável primário). Se for mensagem segura (`NONE`), incrementa apenas `dependent.safe_messages_count`.
  6. **Passo 7.4:** Adiciona a mensagem atual ao buffer circular (`in_memory_buffer.adicionar_mensagem`).
  7. Retorna `ResultadoAnaliseMensagem` contendo `inference_time_ms` medido com `time.perf_counter()`.

#### 📄 `backend/src/services/gestao_incidente_service.py`
Implementa as regras de negócio de consulta, tratamento e exclusão de incidentes:
* **`_verificar_vinculo_responsavel(db, guardian_id, dependent_id)`**: Verifica se o responsável está vinculado ao dependente na tabela `GuardianDependentORM`. Caso não esteja, levanta `IncidentNotFoundError` (resultando em `HTTP 404` conforme Regra 12 para não revelar a existência do recurso).
* **`marcar_incidente_visualizado(db, incident_id, guardian_id) -> Tuple[IncidentORM, bool]`**: Função **idempotente** chamada ao abrir o incidente (`POST /view`). Se o status for `DETECTADO`, muda para `VISUALIZADO` e grava no histórico; se já estiver em qualquer outro status, mantém inalterado e retorna `(incidente, False)`.
* **`mudar_status_incidente(db, incident_id, novo_status, guardian_id, nota) -> IncidentORM`**: Valida a transição com `eh_transicao_valida(..., manual=True)`, atualiza o status, grava no histórico (`IncidentStatusHistoryORM`) e, caso o novo status seja `FALSO_POSITIVO`, persiste o feedback em `FalsePositiveFeedbackORM`.
* **`excluir_incidente(db, incident_id, guardian_id) -> Tuple[str, str]`**: Verifica se o solicitante é o responsável **primário** (`link.is_primary == True`, caso contrário levanta `ForbiddenAccessError` $\rightarrow$ `HTTP 403`) e executa a exclusão física (`db.delete`) em cascata do incidente, históricos e feedbacks (Regra 14 — LGPD).
* **`obter_incidentes_dependente(...)`** e **`contar_incidentes_dependente(...)`**: Listagem filtrada por dependente, status e categoria, ordenada por `created_at DESC`, com contagem exata para paginação.

#### 📄 `backend/src/services/relatorio_service.py`
Gera o documento probatório em formato PDF (UC-04):
* **`gerar_relatorio_incidente(db: Session, incident_id: str) -> BytesIO`**:
  * Busca o incidente, o dependente e o histórico de status.
  * Recalcula o hash SHA-256 sobre `main_message_text` e compara com `main_message_hash` para emitir o selo de integridade (`AUTÊNTICO (Integridade Verificada)` ou `INTEGRIDADE DIVERGENTE`).
  * Monta em `ReportLab` (`SimpleDocTemplate`, página A4) as 4 seções do laudo:
    1. Dados Gerais do Incidente (ID, dependente, data/hora UTC, status, categoria, severidade, probabilidade $P(\text{nocivo})$, link detectado, papel do menor).
    2. Mensagem Principal e Verificação Criptográfica SHA-256 (texto, remetente, timestamp, hash de origem, hash recalculado e status de autenticidade).
    3. Contexto da Conversa (mensagens anteriores e posteriores com timestamps e remetentes).
    4. Histórico de Tratamento e Status (tabela cronológica de transições e notas dos responsáveis).

---

## 5. `feat(api-v1)` — Endpoints REST, Autenticação, Incidentes e Gateway WebSocket

### O que foi feito
* Configuração da aplicação FastAPI principal (`main.py`) com *lifespan* para inicialização automática do banco e `seed`, middleware CORS, Health Check (`GET /`) e roteamento modularizado.
* Implementação de todos os endpoints REST especificados em `.agents/contrato-api.md` e do servidor WebSocket em `/ws?token=<jwt>` com fechamento `4401` para tokens inválidos.

### Arquivos do módulo
* `backend/src/main.py`
* `backend/src/api/v1/predict.py`
* `backend/src/api/v1/auth/login.py`, `backend/src/api/v1/auth/me.py`, `backend/src/api/v1/auth/__init__.py`
* `backend/src/api/v1/dependents/list.py`, `backend/src/api/v1/dependents/threshold.py`, `backend/src/api/v1/dependents/__init__.py`
* `backend/src/api/v1/incidents/list.py`, `detail.py`, `view.py`, `status.py`, `delete.py`, `report/generate.py`, `incidents/__init__.py`
* `backend/src/api/v1/websocket/handler.py`, `backend/src/api/v1/websocket/__init__.py`, `backend/src/api/websocket.py`

### Explicação de cada arquivo e suas funções

#### 📄 `backend/src/main.py`
Ponto de entrada da aplicação FastAPI:
* **`lifespan(app: FastAPI)`**: Inicializa as tabelas do SQLite (`init_db()`) e executa `seed_data(db)` automaticamente na subida do servidor.
* **`read_root()` (`GET /`)**: Endpoint de Health Check que retorna `{"status": "online", "model_loaded": is_model_loaded()}`.
* Registra os roteadores `/api/v1/predict`, `/api/v1/auth`, `/api/v1/dependents`, `/api/v1/incidents` e `/ws`.

#### 📄 `backend/src/api/v1/predict.py`
* **`predict_message(payload: PredictPayload, db: Session)` (`POST /api/v1/predict`)**: Valida o payload recebido do simulador (`text` não vazio $\rightarrow$ `400`, `room_type` em `["jogo", "conversa"]` $\rightarrow$ `422`, `timestamp` ISO-8601 $\rightarrow$ `422`, `dependent_id` existente $\rightarrow$ `404`), chama `analisar_mensagem_completa` e retorna `PredictionResponse` com `label`, `category`, `confidence`, `has_link`, `action_required`, `detected_role`, `sha256_match`, `incident_id`, `model_version` e `inference_time_ms`.

#### 📄 `backend/src/api/v1/auth/login.py` e `backend/src/api/v1/auth/me.py`
* **`login_for_access_token` (`POST /api/v1/auth/login`)**: Autentica o responsável por e-mail e senha (via Argon2), gera o token JWT válido por 24h e retorna os dados do responsável e seus dependentes vinculados.
* **`read_guardian_me` (`GET /api/v1/auth/me`)**: Retorna o perfil do responsável logado e a lista de seus dependentes com a flag `is_primary` individualizada por dependente.

#### 📄 `backend/src/api/v1/dependents/list.py` e `backend/src/api/v1/dependents/threshold.py`
* **`list_dependents` (`GET /api/v1/dependents`)**: Retorna todos os dependentes vinculados ao responsável autenticado, incluindo `common_threshold`, `is_primary` e o contador `safe_messages_count`.
* **`update_dependent_threshold` (`PATCH /api/v1/dependents/{dependent_id}/threshold`)**: Permite exclusivamente ao responsável primário (`403` se secundário) calibrar o `common_threshold` do dependente dentro da faixa `[0.50, 0.84]` (`422` se fora da faixa).

#### 📄 `backend/src/api/v1/incidents/` (`list.py`, `detail.py`, `view.py`, `status.py`, `delete.py`, `report/generate.py`)
* **`list_incidents` (`GET /api/v1/incidents`)**: Lista resumos de incidentes (`IncidentSummary`) com filtros opcionais (`dependent_id`, `status`, `category`, `limit`, `offset`) e totalizador `total`.
* **`get_incident` (`GET /api/v1/incidents/{incident_id}`)**: Retorna os detalhes completos do incidente (`IncidentDetail`), incluindo `room_type`, `conversation_id`, `message`, `context_before`, `context_after`, `allowed_transitions` e `status_history`, sem alterar o status atual.
* **`marcar_como_visualizado` (`POST /api/v1/incidents/{incident_id}/view`)**: Endpoint idempotente que transiciona `DETECTADO` $\rightarrow$ `VISUALIZADO` e notifica os clientes conectados via WebSocket (`incident.updated`).
* **`atualizar_status_incidente` (`PATCH /api/v1/incidents/{incident_id}/status`)**: Aplica mudança manual de status com nota opcional, retornando `409 Conflict` se a transição violar a máquina de estados, e dispara evento WebSocket `incident.updated`.
* **`excluir_incidente_endpoint` (`DELETE /api/v1/incidents/{incident_id}`)**: Exclusão definitiva LGPD exclusiva do responsável primário (`204 No Content` ou `403 Forbidden`), disparando evento WebSocket `incident.deleted`.
* **`gerar_relatorio` (`GET /api/v1/incidents/{incident_id}/report`)**: Retorna o PDF probatório com headers `Content-Type: application/pdf` e `Content-Disposition: attachment; filename="incidente-<id>.pdf"`.

#### 📄 `backend/src/api/v1/websocket/handler.py`
Gateway de comunicação em tempo real com o aplicativo Flutter:
* **`ConnectionManager`**: Gerencia conexões ativas indexadas por `guardian_id`, enviando eventos JSON estruturados (`type`, `sent_at`, `data`) para responsáveis específicos (`send_event_to_guardians`) tanto a partir de corrotinas quanto de rotas síncronas (`notify_event_sync`).
* **`websocket_endpoint` (`WS /ws?token=<jwt>`)**: Valida o token JWT na query string; se ausente ou inválido, encerra o handshake com código `4401`. Mantém o canal aberto respondendo a mensagens `{"type": "ping"}` com `{"type": "pong"}`.

---

## 6. `feat(tests)` — Suíte de Testes Unitários (BVA), Integração e Validação Real do BERTimbau

### O que foi feito
* Configuração de ambiente de testes isolado com banco SQLite em memória (`StaticPool`) e *fixtures* pré-populadas.
* Cobertura completa de Análise de Valor Limite (BVA) para os limiares `0.00`, `0.49`, `0.50`, `0.51`, `0.69`, `0.70`, `0.71`, `0.84`, `0.85`, `0.86`, `1.00`, Modo Gamer e `DetectorDeLinks`.
* Validação empírica do modelo **BERTimbau real** em CPU conforme `INTEGRACAO_BACKEND_BERT.md` (Seção 4): teste de *lazy loading* (`is_model_loaded()`), invariantes numéricas ($P \in [0.0, 1.0]$), frases inócuas vs tóxicas, latência em CPU (`inference_time_ms`), truncamento acima de 512 tokens e resiliência a emojis/caracteres especiais.

### Arquivos do módulo
* `backend/tests/conftest.py`
* `backend/tests/unit/test_domain_rules.py`
* `backend/tests/unit/test_link_detector.py`
* `backend/tests/unit/test_in_memory_buffer.py`
* `backend/tests/unit/test_bertimbau_engine.py`
* `backend/tests/integration/test_predict_api.py`
* `backend/tests/integration/test_auth_api.py`
* `backend/tests/integration/test_incidents_api.py`
* `backend/tests/integration/test_websocket.py`

### Explicação de cada arquivo de teste
* **`backend/tests/conftest.py`**: Define as fixtures `db_session` (SQLite em memória limpo a cada teste com `seed_data`) e `client` (`TestClient` do FastAPI com override de `get_db`).
* **`backend/tests/unit/test_domain_rules.py`**: Testa parametrizadamente toda a matriz BVA de `AvaliadorDecisaoRisco`, Modo Gamer, calibração de limiar (`0.50` a `0.84`), derivação de papel do menor, normalização textual e máquina de estados de status.
* **`backend/tests/unit/test_link_detector.py`**: Valida a detecção de links maliciosos (`http`, `https`, `www`, domínios curtos e IPs com path) e garante ausência de falsos positivos em números decimais e e-mails.
* **`backend/tests/unit/test_in_memory_buffer.py`**: Valida a retenção máxima de 3 mensagens no buffer circular (`context_before`) e a janela de 3 mensagens / 10 minutos para `context_after`.
* **`backend/tests/unit/test_bertimbau_engine.py`**: Valida o `MockClassificadorStrategy` e executa os testes reais no modelo BERTimbau (`test_lazy_loading_e_invariantes_modelo_bertimbau_real` e `test_resiliencia_entradas_excepcionais_truncamento_512_tokens_e_emojis`).
* **`backend/tests/integration/test_predict_api.py`**: Testa o endpoint `POST /api/v1/predict` ponta a ponta tanto com mock (verificando `context_before` e `context_after`) quanto com o **BERTimbau real** (`test_predict_com_modelo_bertimbau_real_end_to_end`).
* **`backend/tests/integration/test_auth_api.py`**: Testa login JWT (`POST /api/v1/auth/login`), consulta de perfil (`GET /api/v1/auth/me`) e rejeição `401` para credenciais inválidas.
* **`backend/tests/integration/test_incidents_api.py`**: Testa o ciclo completo do incidente (listagem, visualização idempotente, transições válidas e inválidas `409`, exportação do relatório PDF, bloqueio `403` para secundário e exclusão LGPD `204` pelo primário, além da calibração de limiar).
* **`backend/tests/integration/test_websocket.py`**: Testa a rejeição `4401` para token inválido no WebSocket e o recebimento em tempo real dos eventos `incident.created` e `incident.critical`.
