# Relatório Abrangente de Mineração de Especificações — Project Artemis

**Data:** 2026-10-09  
**Autor:** Agente Spec Miner (`spec_miner_survey_specs`)  
**Contexto:** Levantamento e Consolidação das Especificações Autoritativas para Apresentação de TCC (MVP Artemis)  
**Fontes Analisadas:**
- `ORIGINAL_REQUEST.md`
- `.agents/regras-de-negocio.md` (Fonte Primária de Regras)
- `.agents/contrato-api.md` (Fonte Primária de Contrato)
- `.agents/arquitetura.md`
- `.agents/testes.md`
- `.agents/requisitos.md`
- `.agents/casos-de-uso.md`
- `.agents/modelagem-uml.md`
- `.agents/padroes-de-projeto.md`
- `AGENTS.md` (Raiz, `backend/`, `simulator/`)
- `plano de ação/` (Módulos Backend, Frontend, Simulador e Integração)

---

## 1. Visão Geral e Hierarquia de Autoridade

O **Project Artemis** é um sistema de controle parental inteligente voltado para a detecção automatizada de ciberbullying em mensagens de texto oriundas de chats/jogos, executando inferência neural binária em CPU (modelo BERTimbau: `GuilhermeLA/modelo-tcc-final`) combinada com um detector heurístico de links externos (`DetectorDeLinks`) e comunicação em tempo real via WebSocket para um aplicativo Flutter Android.

### Regra de Prevalência em Caso de Divergência
Conforme definido em `ORIGINAL_REQUEST.md`, `regras-de-negocio.md` e `contrato-api.md`:
1. **Regras de Negócio (`regras-de-negocio.md`)** e **Contrato da API (`contrato-api.md`)** são as **fontes absolutas da verdade**. Qualquer discrepância em documentos de arquitetura, requisitos, UML ou planos de ação deve ser resolvida em favor desses dois arquivos.
2. Em particular:
   - Apenas o responsável primário calibra limiares, gera convites e exclui dados (LGPD).
   - O campo `confidence` da API é estritamente a probabilidade $P(\text{nocivo})$, e `label` é a saída bruta no limiar fixo 0.50 (sem calibração ou Modo Gamer). A decisão de negócio reside em `category` e `action_required`.
   - Mensagens seguras **nunca** são persistidas no banco; somente contadores agregados são incrementados e um buffer circular de até 3 mensagens é mantido temporariamente em memória volátil.

---

## 2. Features Discovered

| # | Categoria | Feature | Descrição | Inputs | Outputs | Error Behavior | Discovered Via |
|---|-----------|---------|-----------|--------|---------|----------------|----------------|
| 1 | Saúde / Monitoramento | Checagem de Saúde da API (`GET /`) | Informa o estado da aplicação FastAPI e se os pesos do modelo foram carregados pelo proxy | N/A (Sem auth) | `{"status": "online", "model_loaded": bool}` | 500 se o servidor cair | `contrato-api.md`, `arquitetura.md` |
| 2 | Autenticação | Login de Responsável Legal (`POST /api/v1/auth/login`) | Autentica responsável por e-mail e senha, retornando token JWT (HS256, 24h) e dados do guardião | JSON: `email`, `password` | JSON: `access_token`, `token_type`, `expires_in`, `guardian: {id, name, email}` | HTTP 401 (`E-mail ou senha incorretos`) se inválido | `contrato-api.md`, `casos-de-uso.md` (UC-18) |
| 3 | Autenticação | Obtenção do Perfil Autenticado (`GET /api/v1/auth/me`) | Retorna dados do guardião logado e seus dependentes vinculados com flag `is_primary` | Header: `Authorization: Bearer <jwt>` | JSON: `id`, `name`, `email`, `dependents: [{id, name, is_primary}]` | HTTP 401 se token inválido ou ausente | `contrato-api.md` |
| 4 | Autenticação | Registro de Novo Guardião via Convite (`POST /api/v1/auth/register`) *(Se sobrar tempo)* | Cria nova conta de responsável secundário vinculada a um dependente via código de convite de 48h | JSON: `name`, `email`, `password`, `invite_code` | JSON: `access_token`, `token_type`, `expires_in`, `guardian` (HTTP 201) | HTTP 400 se código inexistente/expirado/usado; HTTP 409 se e-mail já existe | `contrato-api.md`, `regras-de-negocio.md` |
| 5 | Predição / Triagem | Predição e Triagem de Mensagem (`POST /api/v1/predict`) | Recebe mensagem do simulador, valida SHA-256, roda BERTimbau e link detector, aplica regras e despacha alerta se crítico | JSON: `text`, `message_hash`, `dependent_id`, `context_metadata: {conversation_id, room_type, sender_id, is_from_minor, is_direct, timestamp}` | JSON: `label`, `category`, `confidence`, `has_link`, `action_required`, `detected_role`, `sha256_match`, `incident_id`, `model_version`, `inference_time_ms` | HTTP 400 (texto vazio/espaços), HTTP 404 (`dependent_id` inexistente), HTTP 422 (enum/schema inválido) | `contrato-api.md`, `regras-de-negocio.md`, `arquitetura.md` |
| 6 | Gestão de Dependentes | Listagem de Dependentes (`GET /api/v1/dependents`) | Retorna dependentes vinculados ao responsável autenticado com contagem agregada de mensagens seguras | Header: `Authorization: Bearer <jwt>` | Array JSON: `[{id, name, common_threshold, is_primary, safe_messages_count}]` | HTTP 401 se não autenticado | `contrato-api.md` |
| 7 | Configuração / Limiar | Calibração de Limiar Comum (`PATCH /api/v1/dependents/{id}/threshold`) | Atualiza o limiar comum calibrado do dependente (faixa permitida 0.50 a 0.84) | Header: Bearer JWT; Path: `dependent_id`; Body: `{"common_threshold": float}` | JSON: `{"id": str, "common_threshold": float}` | HTTP 403 se usuário não primário; HTTP 422 se fora de [0.50, 0.84]; HTTP 404 se não vinculado | `contrato-api.md`, `regras-de-negocio.md` (RN-02) |
| 8 | Co-Parentalidade | Geração de Código de Convite (`POST /api/v1/dependents/{id}/invites`) *(Se sobrar tempo)* | Gera código alfanumérico de 8 caracteres, de uso único, válido por 48 horas | Header: Bearer JWT; Path: `dependent_id` | JSON: `{"invite_code": str, "expires_at": ISO8601}` (HTTP 201) | HTTP 403 se não primário; HTTP 404 se dependente não vinculado | `contrato-api.md`, `regras-de-negocio.md` (RN-13) |
| 9 | Gestão de Incidentes | Listagem Paginada de Incidentes (`GET /api/v1/incidents`) | Lista resumos de incidentes (`IncidentSummary`) do usuário com filtros opcionais, ordenados por `created_at` desc | Query: `dependent_id`, `status`, `category`, `limit` (padrão 50, máx 200), `offset` | JSON: `{"items": [IncidentSummary], "total": int}` | HTTP 401 se sem token; HTTP 422 se query params inválidos | `contrato-api.md`, `casos-de-uso.md` (UC-09) |
| 10 | Gestão de Incidentes | Detalhamento de Incidente (`GET /api/v1/incidents/{id}`) | Retorna o incidente completo com mensagens de contexto anterior/posterior, histórico de status e transições permitidas (não altera status) | Path: `incident_id`; Header: Bearer JWT | JSON: Todos campos de `IncidentSummary` + `room_type`, `conversation_id`, `message`, `context_before`, `context_after`, `allowed_transitions`, `status_history` | HTTP 404 se inexistente ou não vinculado; HTTP 401 se sem token | `contrato-api.md` |
| 11 | Gestão de Incidentes | Visualização de Incidente (`POST /api/v1/incidents/{id}/view`) | Chamado pelo app ao abrir o incidente. Se status for `DETECTADO`, transiciona para `VISUALIZADO` e grava histórico (idempotente) | Path: `incident_id`; Header: Bearer JWT | JSON: Detalhe completo do incidente atualizado (HTTP 200) | HTTP 404 se não vinculado; HTTP 401 se sem token | `contrato-api.md`, `regras-de-negocio.md` (RN-09) |
| 12 | Gestão de Incidentes | Atualização de Status de Incidente (`PATCH /api/v1/incidents/{id}/status`) | Transiciona status do incidente respeitando a máquina de estados oficial; nota opcional vira feedback em `FALSO_POSITIVO` | Path: `incident_id`; Body: `{"status": str, "note": str|null}` | JSON: Detalhe completo do incidente atualizado (HTTP 200) | HTTP 409 se transição for inválida (incluindo destino manual para DETECTADO/VISUALIZADO); HTTP 404 se não encontrado | `contrato-api.md`, `regras-de-negocio.md` (RN-09) |
| 13 | Auditoria / Probatória | Exportação de Relatório PDF (`GET /api/v1/incidents/{id}/report`) | Gera e baixa documento PDF contendo dados, contexto temporal, hash SHA-256 e validação probatória | Path: `incident_id`; Header: Bearer JWT | Binário PDF (`application/pdf`, attachment `incidente-<id>.pdf`) | HTTP 404 se não encontrado; HTTP 401 se não autenticado | `contrato-api.md`, `regras-de-negocio.md` (RN-05) |
| 14 | Privacidade / LGPD | Exclusão Definitiva de Incidente (`DELETE /api/v1/incidents/{id}`) | Exclusão real e irreversível do incidente, mensagens de contexto, histórico e feedback (sem soft-delete) | Path: `incident_id`; Header: Bearer JWT | HTTP 204 No Content | HTTP 403 se usuário não for primário; HTTP 404 se não vinculado | `contrato-api.md`, `regras-de-negocio.md` (RN-14) |
| 15 | Tempo Real | Conexão WebSocket para Notificações (`WS /ws?token=<jwt>`) | Canal bidirecional de baixa latência para entrega de notificações imediatas de incidentes e heartbeat | Query: `token=<jwt>`; Client ping: `{"type": "ping"}` | Server pong: `{"type": "pong"}`; Server events: `incident.created`, `incident.critical`, `incident.escalated`, `incident.updated`, `incident.deleted` | Fechamento de conexão com código WS 4401 se token ausente ou inválido | `contrato-api.md`, `regras-de-negocio.md` (RN-10) |
| 16 | Escalonamento | Escalonamento de Alerta Crítico (UC-12) *(Se sobrar tempo)* | Rotina em background (a cada 60s) que notifica responsáveis secundários se incidente crítico não for aberto em 15 minutos | Background asyncio loop | Evento WS `incident.escalated` para secundários; marcação `escalado = true` | N/A (silencioso no backend) | `regras-de-negocio.md` (RN-11), `contrato-api.md` |
| 17 | Simulação / Front | Simulador de Chat Web Client | Interface Web Nginx (HTML/JS puro) que emula remetentes, salas e calcula SHA-256 no cliente via Web Crypto API | Entrada do usuário no formulário do chat | Renderização de balões de mensagens com selo de severidade, confiança e ação | Exibição de mensagem de erro HTTP retornada da API | `simulator/AGENTS.md`, `plano de ação/simulador/` |
| 18 | IA / NLP | Inferência BERTimbau em CPU com Lazy Loading | Carga sob demanda dos tensores BERTimbau (`Virtual Proxy`) e inferência sem gradiente com WordPiece max 512 | Texto da mensagem | Probabilidade normalizada $P(\text{nocivo})$ (softmax índice 1) | Erro amigável se `/models/modelo_tcc_final` não existir no disco | `arquitetura.md`, `padroes-de-projeto.md`, `backend/AGENTS.md` |
| 19 | Heurística | Detecção de Links Externos (`DetectorDeLinks`) | Expressão regular determinística (`https?://\S+|www\.\S+`, case-insensitive) executada em tempo linear | Texto bruto | Booleano `has_link` | N/A | `arquitetura.md`, `regras-de-negocio.md`, `padroes-de-projeto.md` |
| 20 | Contexto Temporal | Buffer de Memória e Anexo Posterior | Mantém buffer das últimas 3 mensagens da conversa e anexa até 3 posteriores a incidentes abertos por até 10 minutos | Mensagem recebida na conversa | Contexto anterior e posterior gravados com o incidente | Buffer volátil se perde em reinício (aceitável) | `regras-de-negocio.md` (RN-07) |

---

## 3. Edge Cases e Análise de Valores Limite (BVA)

| # | Feature / Cenário | Input / Condição de Teste | Comportamento Observado / Especificado |
|---|-------------------|---------------------------|----------------------------------------|
| 1 | Normalização de Texto | Texto vazio `""` ou apenas espaços `"   "` | HTTP 400 Bad Request retornado imediatamente antes de chamar o modelo ou atualizar buffer. |
| 2 | Limiar Comum - Borda Inferior | Probabilidade $P = 0.499$, $L = 0.50$, `room_type = "conversa"`, `has_link = false` | `category = "SEGURO"`, `action_required = "NONE"`, mensagem descartada do banco, apenas contador agregado incrementado. |
| 3 | Limiar Comum - Borda Exata | Probabilidade $P = 0.500$, $L = 0.50$, `room_type = "conversa"`, `has_link = false` | `category = "CIBERBULLYING"`, `action_required = "LOG_INCIDENT"`, status `DETECTADO`, salvo no banco com contexto anterior. |
| 4 | Limiar Comum - Borda Superior | Probabilidade $P = 0.849$, $L = 0.50$, `room_type = "conversa"`, `has_link = false` | `category = "CIBERBULLYING"`, `action_required = "LOG_INCIDENT"`, gravidade `COMUM`, salvo sem alerta sonoro imediato. |
| 5 | Limiar Crítico - Borda Exata | Probabilidade $P = 0.850$, qualquer $L$, qualquer sala | `category = "CIBERBULLYING"`, `action_required = "ALERT_PARENT_CRITICAL"`, gravidade `CRITICO`, salvo e emitido evento WS `incident.critical` para o primário. |
| 6 | Limiar Crítico - Valor Máximo | Probabilidade $P = 1.000$, qualquer $L$, qualquer sala | `category = "CIBERBULLYING"`, `action_required = "ALERT_PARENT_CRITICAL"`, gravidade `CRITICO`. |
| 7 | Limiar Calibrado Customizado | $L = 0.65$, $P = 0.600$, `room_type = "conversa"`, `has_link = false` | `category = "SEGURO"`, `action_required = "NONE"` (mesmo com $P > 0.50$, prevalece $L = 0.65$). |
| 8 | Limiar Calibrado Customizado | $L = 0.65$, $P = 0.650$, `room_type = "conversa"`, `has_link = false` | `category = "CIBERBULLYING"`, `action_required = "LOG_INCIDENT"`. |
| 9 | Modo Gamer - Abaixo do Piso Gamer | $L = 0.50$, $P = 0.650$, `room_type = "jogo"`, `has_link = false` | Limiar efetivo $L = \max(0.50, 0.70) = 0.70$. Como $P < 0.70 \implies$ `category = "SEGURO"`, `action_required = "NONE"`. |
| 10 | Modo Gamer - Limite do Piso Gamer | $L = 0.50$, $P = 0.700$, `room_type = "jogo"`, `has_link = false` | Limiar efetivo $L = 0.70$. Como $P \ge 0.70 \implies$ `category = "CIBERBULLYING"`, `action_required = "LOG_INCIDENT"`. |
| 11 | Modo Gamer - Limiar Superior ao Piso | $L = 0.75$, $P = 0.720$, `room_type = "jogo"`, `has_link = false` | Limiar efetivo $L = \max(0.75, 0.70) = 0.75$. Como $P < 0.75 \implies$ `category = "SEGURO"`, `action_required = "NONE"`. |
| 12 | Modo Gamer - Crítico Inalterável | $L = 0.75$, $P = 0.850$, `room_type = "jogo"` | O Modo Gamer afeta apenas o limiar comum; crítico permanece 0.85 fixo $\implies$ `ALERT_PARENT_CRITICAL`. |
| 13 | Link com Probabilidade Baixa | $P = 0.100$, `has_link = true` (ex: "http://site.com"), `room_type = "conversa"` ou `"jogo"` | `category = "LINK_SUSPEITO"`, `action_required = "LOG_INCIDENT"`. Links sempre geram incidente mesmo em jogos. |
| 14 | Link com Probabilidade Alta | $P = 0.900$, `has_link = true` | Ordem de precedência: regra 1 dispara primeiro $\implies$ `category = "CIBERBULLYING"`, `action_required = "ALERT_PARENT_CRITICAL"`, mas `has_link` segue informado como `true`. |
| 15 | Integridade SHA-256 Divergente | Hash enviado no payload difere do SHA-256 recalculado sobre `text` | Não bloqueia predição (retorna 200 OK); se virar incidente, grava `integridade_divergente = true` e relatório PDF exibe alerta. |
| 16 | Emojis e Stopwords no Texto | Texto contendo emojis e stopwords | Não remove stopwords nem altera emojis (mantidos intactos pois BERTimbau foi treinado com eles). |
| 17 | Tamanho de Texto Extenso | Texto com $> 512$ tokens WordPiece | Não estoura erro 400; tokenizer executa `truncation=True, max_length=512` silenciosamente. |
| 18 | `room_type` Inválido | `room_type = "chat"` ou qualquer valor diferente de `"conversa"` ou `"jogo"` | FastAPI/Pydantic rejeita com HTTP 422 Unprocessable Entity. |
| 19 | Calibração de Limiar Inválida | `common_threshold = 0.49` ou `common_threshold = 0.85` | Validação rejeita com HTTP 422 (faixa estrita permitida: $0.50 \le x \le 0.84$). |
| 20 | Permissão de Limiar por Secundário | Responsável secundário tenta alterar `threshold` | HTTP 403 Forbidden retornado imediatamente. |
| 21 | Acesso a Dependente Não Vinculado | Usuário solicita dados de `dependent_id` pertencente a outra família | HTTP 404 Not Found (não revelar que o recurso existe). |
| 22 | Transição Inválida de Incidente | Tentativa de mudar de `DETECTADO` diretamente para `RESOLVIDO` ou para `DETECTADO` | HTTP 409 Conflict. `DETECTADO` e `VISUALIZADO` nunca são aceitos como destino manual. |
| 23 | Visualização Concorrente / Idempotência | Múltiplas chamadas de `POST /incidents/{id}/view` quando status já é `VISUALIZADO` | Operação idempotente: não altera status nem duplica histórico, retorna 200 OK com dados atuais. |
| 24 | Contexto Posterior Limite (Janela / Quantidade) | Mensagem chega 11 minutos após a criação do incidente ou incidente já acumulou 3 mensagens posteriores | Mensagem não é anexada ao incidente fechado; apenas alimenta o buffer de mensagens anteriores. |
| 25 | Exclusão Real de Incidente | Responsável primário envia `DELETE /incidents/{id}` | Remoção física em cascata no SQLite (incidente, mensagens de contexto, histórico de status e feedback são expurgados permanentemente). |
| 26 | Conexão WebSocket com Token Inválido | Cliente conecta em `ws://host:8000/ws?token=invalido` | Servidor recusa imediatamente e fecha conexão com código de fechamento WS `4401`. |

---

## 4. Especificação Completa das Regras de Negócio (RN-01 a RN-14)

### RN-01: Probabilidade $P$ e Semântica dos Campos
- **Modelo:** BERTimbau Binário com saída Softmax (`[0 = normal, 1 = nocivo]`).
- **`confidence`:** Representa rigorosamente a probabilidade da classe `nocivo`, isto é, $P \in [0.0, 1.0]$. Nunca deve refletir a confiança da classe prevista pelo modelo.
- **`label`:** Saída bruta da rede neural aplicando limiar fixo padrão de 0.50:
  $$\text{label} = \begin{cases} \text{"nocivo"}, & \text{se } P \ge 0.50 \\ \text{"normal"}, & \text{se } P < 0.50 \end{cases}$$
  Não sofre interferência do limiar calibrado pelo usuário nem do Modo Gamer.
- **Decisão Final:** Determinada exclusivamente pelos campos `category` e `action_required`.

### RN-02: Gestão de Limiares
- **Limiar Crítico:** Fixo em **$0.85$**, imutável por qualquer usuário ou perfil.
- **Limiar Comum Calibrado:** Armazenado por `Dependente` (padrão $0.50$, intervalo válido permitido $[0.50, 0.84]$). Somente alterável pelo **Responsável Primário**.
- **Limiar Comum Efetivo ($L$):**
  - Se `room_type = "conversa"`: $L = \text{limiar\_comum}$.
  - Se `room_type = "jogo"` (Modo Gamer): $L = \max(\text{limiar\_comum}, 0.70)$.

### RN-03: Tabela Oficial de Decisão de Risco
Avaliador puro (`AvaliadorDecisaoRisco` em `src/domain/rules.py`), avaliado em ordem sequencial estrita, parando na primeira condição verdadeira:
1. **Se $P \ge 0.85$:**
   - `category = "CIBERBULLYING"`
   - `action_required = "ALERT_PARENT_CRITICAL"`
   - *Tipo:* Incidente Crítico.
2. **Se $L \le P < 0.85$:**
   - `category = "CIBERBULLYING"`
   - `action_required = "LOG_INCIDENT"`
   - *Tipo:* Incidente Comum.
3. **Se $P < L$ e `has_link == true`:**
   - `category = "LINK_SUSPEITO"`
   - `action_required = "LOG_INCIDENT"`
   - *Tipo:* Incidente Comum.
4. **Se $P < L$ e `has_link == false`:**
   - `category = "SEGURO"`
   - `action_required = "NONE"`
   - *Tipo:* Mensagem Segura.

*Nota:* O `DetectorDeLinks` pesquisa expressões regulares `https?://\S+|www\.\S+` (sem sensibilidade a maiúsculas/minúsculas).

### RN-04: Derivação do Papel do Menor (`detected_role`)
Derivado deterministicamente a partir dos metadados recebidos:
- Se `is_from_minor == true` $\implies$ `Papel = "EMISSOR"`.
- Se `is_from_minor == false` e `is_direct == true` $\implies$ `Papel = "VITIMA"`.
- Se `is_from_minor == false` e `is_direct == false` $\implies$ `Papel = "ESPECTADOR"`.
*(Cards pedagógicos aplicam texto de `VITIMA` para `ESPECTADOR`)*.

### RN-05: Integridade Criptográfica Probatória (SHA-256)
- O cliente/simulador calcula o hash SHA-256 (hexadecimal em letras minúsculas) sobre a string UTF-8 do texto **exatamente como digitado**, antes de qualquer tratamento.
- O backend recalcula o SHA-256 sobre o campo `text` recebido e compara:
  $$\text{sha256\_match} = (\text{hash\_calculado} == \text{message\_hash.lower()})$$
- Hash divergente **não interrompe a triagem**. Se resultar em incidente, persiste com a marcação `integridade_divergente = true`.

### RN-06: Pré-processamento e Normalização Textual
- Remoção de múltiplos espaços em branco redundantes e padronização de quebras de linha (`\r\n` $\rightarrow$ `\n`).
- Preservação integral de emojis e stopwords.
- Truncamento seguro pelo tokenizer WordPiece: `truncation=True, max_length=512`.
- Texto em branco ou composto exclusivamente por espaços retorna HTTP 400.

### RN-07: Janela de Contexto Temporal do Incidente
- **Buffer Circular em Memória:** Mantém as últimas 3 mensagens da conversa (`conversation_id`), sejam elas seguras ou ofensivas. Não é salvo em disco e reinicializa se o backend reiniciar.
- **Contexto Anterior:** Ao criar um incidente, copiam-se as até 3 mensagens presentes no buffer **imediatamente anteriores** à mensagem ofensiva.
- **Contexto Posterior:** Todo incidente criado permanece em uma lista volátil de "incidentes abertos para contexto". Novas mensagens recebidas na mesma conversa são anexadas como contexto posterior se o incidente tiver **menos de 3 mensagens posteriores** e tiver sido gerado há **no máximo 10 minutos**.
- **Ordem de Execução ao Receber Mensagem:**
  1. Anexar mensagem como posterior a incidentes abertos da conversa.
  2. Classificar a mensagem.
  3. Se for incidente, criar registro com contexto anterior e incluir na lista de incidentes abertos para posteriores.
  4. Adicionar a mensagem ao buffer circular da conversa.

### RN-08: Persistência Condicional e Privacidade (LGPD)
- **Persistência Efetiva:** Gravação em SQLite apenas para incidentes ($P \ge L$ ou link suspeito), mensagem em si, mensagens de contexto anterior e posterior, histórico de transição de status e feedbacks de falso positivo.
- **Mensagens Seguras:** Jamais são salvas em tabelas relacionais ou disco. Incrementa-se exclusivamente um contador inteiro agregado no registro do dependente (`safe_messages_count += 1`).

### RN-09: Máquina de Estados e Ciclo de Vida do Incidente
Status oficial: `DETECTADO`, `VISUALIZADO`, `EM_ANALISE`, `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO`, `RESOLVIDO`.
- Novo incidente inicia invariavelmente como `DETECTADO`.
- **Transições Permitidas:**
  - `DETECTADO` $\rightarrow$ `VISUALIZADO` *(Executado automaticamente pelo sistema via endpoint `/view` quando o responsável abre o incidente)*.
  - `VISUALIZADO` $\rightarrow$ `EM_ANALISE` ou `FALSO_POSITIVO`.
  - `EM_ANALISE` $\rightarrow$ `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO` ou `RESOLVIDO`.
  - `CONVERSADO_COM_FILHO` $\rightarrow$ `RESOLVIDO`.
  - `ENCAMINHADO_A_ESCOLA` $\rightarrow$ `RESOLVIDO`.
- **Regras Estritas:**
  - `FALSO_POSITIVO` e `RESOLVIDO` são estados terminais.
  - Qualquer transição fora deste grafo retorna **HTTP 409 Conflict**.
  - `DETECTADO` e `VISUALIZADO` são proibidos como destino em alterações manuais.
  - Toda mudança grava histórico com status anterior, novo, data/hora UTC, ID/nome do responsável e nota textual facultativa.
  - Transição para `FALSO_POSITIVO` armazena a nota como registro de feedback para retreinamento.

### RN-10: Política de Despacho de Notificações
- Eventos despachados via WebSocket para conexões ativas do aplicativo móvel:
  - `incident.created`: Enviado para todos os guardiões vinculados ao dependente (sem alerta sonoro).
  - `incident.critical`: Enviado **exclusivamente para o responsável primário** (com alerta sonoro prioritário no aplicativo).
  - `incident.escalated`: Enviado para guardiões secundários (com alerta sonoro).
  - `incident.updated` e `incident.deleted`: Enviados para todos os guardiões do dependente (sem som).
- Sem buffer ou fila de retenção offline: se o app estiver desconectado, a sincronização ocorre via `GET /api/v1/incidents` ao abrir o app.

### RN-11: Política de Escalonamento Automático (UC-12)
- Tarefa assíncrona periódica a cada 60 segundos.
- Consulta incidentes críticos com status `DETECTADO`, `escalonado = false` e criados há mais de 15 minutos.
- Despacha evento `incident.escalated` para responsáveis secundários e marca `escalonado = true` no banco. Não altera o status do incidente.

### RN-12: Matriz de Permissões e Acessos
- **Responsável Vinculado (Qualquer um):** Visualizar incidentes daquele dependente, acionar endpoint `/view`, alterar status de incidentes, exportar relatório PDF e registrar falsos positivos.
- **Responsável Primário (Exclusivo):** Calibrar limiar comum ($0.50$ a $0.84$), emitir código de convite para co-parentalidade e efetuar exclusão definitiva de incidentes.
- **Isolamento de Segurança:** Requisições a dependentes/incidentes não associados ao usuário logado retornam **HTTP 404 Not Found**. Ações exclusivas do primário requisitadas por secundário retornam **HTTP 403 Forbidden**.

### RN-13: Co-Parentalidade e Convites (UC-06)
- Primário solicita convite $\rightarrow$ sistema gera token de 8 caracteres com expiração em 48 horas.
- Novo usuário informa token no registro $\rightarrow$ conta criada e associada como secundária.
- Cada dependente possui exatamente um responsável primário.

### RN-14: Exclusão Definitiva (LGPD Art. 14 / UC-17)
- Remoção definitiva (*hard delete*): apaga fisicamente o registro do incidente, suas mensagens vinculadas (contexto anterior e posterior), o histórico de transições de status e apontamentos de feedback.

---

## 5. Contrato Completo da API e WebSocket

### 5.1. Padrões Globais
- **Host Base:** `http://<host>:8000` (desenvolvimento/Docker).
- **Prefixo REST:** `/api/v1`.
- **Formatação:** JSON em `snake_case`. Timestamps em ISO-8601 UTC (`2026-10-07T14:30:00Z`). IDs em formato `string`.
- **Formato Padrão de Erro:** `{"detail": "mensagem descritiva"}`.
- **Códigos HTTP de Erro Padronizados:**
  - `400`: Violação de regras de entrada (texto em branco, convite inválido/usado).
  - `401`: Token JWT ausente, expirado ou inválido; falha de login.
  - `403`: Ação restrita ao guardião primário realizada por secundário.
  - `404`: Entidade inexistente ou não vinculada ao usuário autenticado.
  - `409`: Conflito de transição de status; e-mail duplicado.
  - `422`: Falha de validação Pydantic (schema/enums/tipagem).
- **Autenticação:** Header `Authorization: Bearer <jwt>` em todas as rotas, com exceção de:
  - `GET /`
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/register`
  - `POST /api/v1/predict`

---

### 5.2. Especificação Detalhada dos Endpoints REST

#### 1. `GET /` — Verificação de Integridade e Carga do Modelo
- **Autenticação:** Nenhuma.
- **Sucesso (200 OK):**
  ```json
  {
    "status": "online",
    "model_loaded": false
  }
  ```
  *Nota: `model_loaded` passa para `true` apenas após a execução da primeira inferência via Virtual Proxy.*

---

#### 2. `POST /api/v1/auth/login` — Autenticação de Guardião (UC-18)
- **Autenticação:** Nenhuma.
- **Request Body:**
  ```json
  {
    "email": "responsavel@exemplo.com",
    "password": "senhaSegura123"
  }
  ```
- **Sucesso (200 OK):**
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 86400,
    "guardian": {
      "id": "resp-001",
      "name": "Responsável Primário",
      "email": "responsavel@exemplo.com"
    }
  }
  ```
- **Erros:**
  - `401 Unauthorized`: `{"detail": "E-mail ou senha incorretos"}`.

---

#### 3. `GET /api/v1/auth/me` — Obtenção do Perfil e Dependentes
- **Autenticação:** Bearer Token.
- **Sucesso (200 OK):**
  ```json
  {
    "id": "resp-001",
    "name": "Maria",
    "email": "responsavel@exemplo.com",
    "dependents": [
      {
        "id": "dep-001",
        "name": "Lucas",
        "is_primary": true
      }
    ]
  }
  ```

---

#### 4. `POST /api/v1/auth/register` — Registro via Convite (UC-06)
- **Autenticação:** Nenhuma.
- **Request Body:**
  ```json
  {
    "name": "João",
    "email": "joao@exemplo.com",
    "password": "senhaSegura123",
    "invite_code": "K7P2QX9M"
  }
  ```
- **Sucesso (201 Created):** Retorna o mesmo payload do login (com token emitido).
- **Erros:**
  - `400 Bad Request`: `{"detail": "Código de convite inválido ou expirado"}`.
  - `409 Conflict`: `{"detail": "E-mail já cadastrado"}`.

---

#### 5. `POST /api/v1/predict` — Inferência e Triagem (UC-01)
- **Autenticação:** Nenhuma (rota pública usada pelo simulador).
- **Request Body:**
  ```json
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
  ```
- **Sucesso (200 OK):**
  ```json
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
- **Valores Permitidos:**
  - `room_type`: `"jogo"` ou `"conversa"`.
  - `label`: `"normal"` ou `"nocivo"`.
  - `category`: `"SEGURO"`, `"CIBERBULLYING"`, `"LINK_SUSPEITO"`.
  - `action_required`: `"NONE"`, `"LOG_INCIDENT"`, `"ALERT_PARENT_CRITICAL"`.
  - `detected_role`: `"VITIMA"`, `"EMISSOR"`, `"ESPECTADOR"`.
  - `incident_id`: ID em string se virou incidente, ou `null` se `action_required = "NONE"`.
- **Erros:**
  - `400 Bad Request`: Texto vazio ou composto só por espaços.
  - `404 Not Found`: `dependent_id` não cadastrado.
  - `422 Unprocessable Entity`: Campo obrigatório faltante ou `room_type` inválido.

---

#### 6. `GET /api/v1/dependents` — Listagem de Dependentes
- **Autenticação:** Bearer Token.
- **Sucesso (200 OK):**
  ```json
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

---

#### 7. `PATCH /api/v1/dependents/{dependent_id}/threshold` — Calibração de Sensibilidade (UC-03)
- **Autenticação:** Bearer Token (Exclusivo Responsável Primário).
- **Request Body:**
  ```json
  {
    "common_threshold": 0.65
  }
  ```
- **Sucesso (200 OK):**
  ```json
  {
    "id": "dep-001",
    "common_threshold": 0.65
  }
  ```
- **Erros:**
  - `403 Forbidden`: Usuário autenticado é secundário.
  - `404 Not Found`: Dependente não vinculado.
  - `422 Unprocessable Entity`: Limiar fora do intervalo $[0.50, 0.84]$.

---

#### 8. `POST /api/v1/dependents/{dependent_id}/invites` — Geração de Convite (UC-06)
- **Autenticação:** Bearer Token (Exclusivo Primário).
- **Sucesso (201 Created):**
  ```json
  {
    "invite_code": "K7P2QX9M",
    "expires_at": "2026-10-11T14:30:00Z"
  }
  ```
- **Erros:**
  - `403 Forbidden`: Usuário não primário.
  - `404 Not Found`: Dependente inexistente/não vinculado.

---

#### 9. `GET /api/v1/incidents` — Listagem Paginada de Incidentes (UC-09)
- **Autenticação:** Bearer Token.
- **Query Params:**
  - `dependent_id` *(opcional, string)*: filtra por dependente.
  - `status` *(opcional, string)*: filtra por status.
  - `category` *(opcional, string)*: filtra por categoria (`CIBERBULLYING` ou `LINK_SUSPEITO`).
  - `limit` *(opcional, int, padrão: 50, máx: 200)*.
  - `offset` *(opcional, int, padrão: 0)*.
- **Sucesso (200 OK):**
  ```json
  {
    "items": [
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
    ],
    "total": 12
  }
  ```
  *Nota: `severity` é `"CRITICO"` se `confidence >= 0.85`, senão `"COMUM"`. `preview` possui os primeiros 60 caracteres do texto.*

---

#### 10. `GET /api/v1/incidents/{incident_id}` — Detalhes Completos do Incidente
- **Autenticação:** Bearer Token.
- **Comportamento:** Apenas recupera as informações completas. **Não modifica status**.
- **Sucesso (200 OK):**
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
    "created_at": "2026-10-07T14:30:01Z",
    "room_type": "jogo",
    "conversation_id": "conv-game-88",
    "message": {
      "text": "Você é um inútil, ninguém gosta de você",
      "sender_id": "user-adversario-09",
      "is_from_minor": false,
      "timestamp": "2026-10-07T14:30:00Z",
      "message_hash": "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
    },
    "context_before": [
      {
        "text": "vamos jogar de novo",
        "sender_id": "lucas",
        "is_from_minor": true,
        "timestamp": "2026-10-07T14:28:10Z"
      }
    ],
    "context_after": [],
    "allowed_transitions": [
      "EM_ANALISE",
      "FALSO_POSITIVO"
    ],
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

---

#### 11. `POST /api/v1/incidents/{incident_id}/view` — Marcação de Visualização (UC-02)
- **Autenticação:** Bearer Token.
- **Comportamento:** Se o status atual for `DETECTADO`, transiciona para `VISUALIZADO` e registra no histórico. Em qualquer outro estado, não efetua alteração. Idempotente.
- **Sucesso (200 OK):** Retorna o detalhe completo do incidente atualizado (mesmo formato do `GET`).

---

#### 12. `PATCH /api/v1/incidents/{incident_id}/status` — Atualização de Ciclo de Vida (UC-09, UC-07)
- **Autenticação:** Bearer Token.
- **Request Body:**
  ```json
  {
    "status": "EM_ANALISE",
    "note": "Entrarei em contato com a coordenação pedagógica"
  }
  ```
- **Sucesso (200 OK):** Retorna o detalhe completo do incidente atualizado.
- **Erros:**
  - `409 Conflict`: `{"detail": "Transição de status inválida"}`.
  - `404 Not Found`: Incidente inexistente ou não vinculado.

---

#### 13. `GET /api/v1/incidents/{incident_id}/report` — Relatório Probatório PDF (UC-04)
- **Autenticação:** Bearer Token.
- **Headers de Resposta:**
  - `Content-Type: application/pdf`
  - `Content-Disposition: attachment; filename="incidente-<id>.pdf"`
- **Sucesso (200 OK):** Fluxo binário do PDF renderizado via ReportLab com mensagem principal, contexto temporal, hash de origem, resultado da validação e timestamp de geração.

---

#### 14. `DELETE /api/v1/incidents/{incident_id}` — Exclusão Definitiva LGPD (UC-17)
- **Autenticação:** Bearer Token (Exclusivo Primário).
- **Sucesso (204 No Content):** Sem corpo. Registros expurgados permanentemente.
- **Erros:**
  - `403 Forbidden`: Usuário não primário.
  - `404 Not Found`: Incidente não vinculado.

---

### 5.3. Especificação do Canal WebSocket (`/ws`)

- **URL de Conexão:** `ws://<host>:8000/ws?token=<jwt>`
- **Validação de Acesso:** Token verificado no handshake. Token inválido, expirado ou ausente fecha a conexão imediatamente com código **4401**.
- **Heartbeat:** Cliente envia `{"type": "ping"}`; servidor replica `{"type": "pong"}`.
- **Envelope de Evento:**
  ```json
  {
    "type": "incident.critical",
    "sent_at": "2026-10-07T14:30:01Z",
    "data": { ... }
  }
  ```
- **Catálogo de Eventos do Servidor:**
  1. `incident.created` (`data`: `IncidentSummary`): Notifica todos os responsáveis do dependente para atualizar a lista/feed. Sem som.
  2. `incident.critical` (`data`: `IncidentSummary`): Despachado **somente ao responsável primário**. Dispara som de alerta urgente e banner no aplicativo.
  3. `incident.escalated` (`data`: `IncidentSummary`): Despachado aos responsáveis secundários após 15 minutos sem visualização. Dispara som de alerta.
  4. `incident.updated` (`data`: `IncidentSummary`): Notifica mudança de status para todos os guardiões. Sem som.
  5. `incident.deleted` (`data`: `{"id": "inc-9876", "dependent_id": "dep-001"}`): Notifica exclusão para remoção imediata da UI em todos os guardiões. Sem som.

---

### 5.4. Dados de Demonstração / Seed Oficial (`python -m src.seed`)
- `resp-001`: Responsável Primário (vinculado como primário a `dep-001` e `dep-002`).
- `resp-002`: Responsável Secundário (vinculado como secundário a `dep-001`, utilizado para testes de escalonamento e restrições de permissão).
- `dep-001`: Dependente "Lucas" (`common_threshold = 0.50`).
- `dep-002`: Dependente "Ana" (`common_threshold = 0.50`).

---

## 6. Arquitetura de Software e Padrões de Projeto

### 6.1. Arquitetura em Camadas (Clean / Ports and Adapters)
Conforme estabelecido em `arquitetura.md` e `backend/AGENTS.md`:

```
backend/src/
├── main.py              # Ponto de entrada, Lifespan, CORS, Routers
├── config.py            # Pydantic Settings (ENVs)
├── seed.py              # Carga de dados determinísticos de demonstração
├── api/                 # Apresentação: Controladores FastAPI, Schemas Pydantic, WS
│   ├── v1/
│   │   ├── predict.py   # Triagem pública do simulador
│   │   ├── auth.py      # Autenticação e perfil
│   │   ├── incidents.py # CRUD e transições de incidentes
│   │   └── dependents.py# Limiares e convites
│   └── websocket.py     # Gerenciador de conexões em memória
├── services/            # Casos de uso / Orquestração de negócio
│   ├── analise_service.py
│   ├── gestao_incidente_service.py
│   ├── relatorio_service.py
│   └── escalonamento_service.py
├── domain/              # Domínio puro (Zero dependências externas)
│   ├── entities.py      # Modelos puros: Incidente, Mensagem, Responsavel, Dependente
│   ├── enums.py         # Status, Categorias, Papéis, Ações
│   └── rules.py         # AvaliadorDecisaoRisco (função pura de cálculo de limiares)
└── infrastructure/      # Adaptadores e saídas técnicas
    ├── bertimbau_engine.py  # Model loader, tokenização, proxy
    ├── link_detector.py     # Regex determinístico de URLs
    ├── in_memory_buffer.py  # Buffer circular e janelas temporais
    ├── notifier.py          # WebSocket Notification Gateway
    └── database.py          # SQLAlchemy 2.x ORM e SQLite
```

#### Regras Rígidas de Dependência:
- A camada `domain/` **não deve conter nenhuma dependência de infraestrutura**: proibido importar PyTorch, Transformers, FastAPI ou SQLAlchemy.
- A camada `api/` apenas repassa comandos para `services/` e formata respostas; lógica de negócio dentro de rotas é estritamente vedada.
- Uvicorn opera com **1 único worker**, viabilizando o gerenciamento do buffer e dos observadores em memória sem sincronização distribuída.

---

### 6.2. Catálogo de Padrões de Projeto (GoF)

1. **Virtual Proxy (Lazy Loading) no Carregamento do BERTimbau:**
   - *Motivação:* O modelo possui ~440 MB de pesos no disco. Carregá-lo durante o boot da aplicação violaria o critério de aceitação de boot em $< 2$ segundos.
   - *Implementação:* A classe `BERTimbauEngineProxy` implementa a interface `IClassificadorEngine`. A instância do modelo real (`RealBERTimbauEngine`) só é carregada do disco (`/models/modelo_tcc_final`) no momento exato em que a primeira requisição chega em `predict_probability()`. O boot da API ocorre em milissegundos.
2. **Strategy nos Checkpoints do Modelo:**
   - *Motivação:* Isolar a execução de inferência permitindo alternar entre o checkpoint original e versões calibradas ou rebalanceadas sem alterar `AnaliseMensagemService`.
   - *Implementação:* Interface `ClassificadorStrategy` com método `predict_probability(texto: str) -> float`.
3. **Factory Method na Instanciação de Classificadores:**
   - *Motivação:* Permitir alternância dinâmica entre motor real e motor simulado para execução de testes unitários ultrarrápidos em CI.
   - *Implementação:* `ClassificadorFactory` que avalia a variável de ambiente `APP_ENV`. Se `APP_ENV == "testing"`, instancia `MockClassificadorFactory`; caso contrário, instancia `BERTimbauFactory`.
4. **Observer (Pub/Sub) na Disseminação de Eventos e Alertas:**
   - *Motivação:* Desacoplar a triagem de mensagens (`AnaliseMensagemService`) dos múltiplos destinos de eventos (transmissão WebSocket para mobile, log de auditoria e escalonamento).
   - *Implementação:* Interface `IncidenteObserver` (`onEvento(tipo, dados)`). `WebSocketNotifier` e `AuditLogNotifier` atuam como observadores registrados.
5. **Template Method na Emissão de Relatórios:**
   - *Motivação:* Padronizar a sequência algorítmica invariante de auditoria (busca de dados $\rightarrow$ validação criptográfica SHA-256 $\rightarrow$ formatação de metadados $\rightarrow$ renderização).
   - *Implementação:* Classe abstrata `RelatorioIncidenteTemplate` com método de molde `gerarRelatorio()`, especializando-se em `RelatorioPdfExporter`.

---

## 7. Especificação de Testes e Metodologia TDD

### 7.1. Pirâmide de Testes e Metas de Desempenho
- **Testes de Unidade (~70%):**
  - Tempo de execução alvo: $< 10\text{ ms}$ por teste.
  - Abrangência: Funções puras em `domain/rules.py` (BVA exaustivo), `DetectorDeLinks`, normalização de texto, manipulação do buffer circular, validação de transições de status e truncamento seguro do tokenizer com mocks de PyTorch.
- **Testes de Integração (~20%):**
  - Tempo de execução alvo: $< 150\text{ ms}$ por teste.
  - Abrangência: Endpoints FastAPI com `TestClient`, autenticação JWT, SQLite em memória com `StaticPool`, geração de PDF e ciclo de vida completo de incidentes.
- **Testes Ponta a Ponta (E2E) (~10%):**
  - Tempo de execução alvo: $< 2\text{ s}$ por teste.
  - Abrangência: Fluxo completo com o modelo BERTimbau real (download do Hugging Face permitido na montagem do volume): Simulador $\rightarrow$ API $\rightarrow$ WebSocket.

### 7.2. Configuração da Suíte de Testes do Backend (`conftest.py`)
- Deve forçar `APP_ENV=testing`.
- Banco de dados de teste configurado com `sqlite://` em memória com `StaticPool` para manter estado consistente entre transações do teste.
- Sobrescrever dependência `get_db` do FastAPI.
- Fixture automática populando o seed (`dep-001`, `resp-001`, `resp-002`).

### 7.3. Metas de Latência e Critérios de Aceitação Verificáveis
1. **Boot da Aplicação:** Uvicorn deve inicializar em $< 2,0\text{ s}$ sem carregar os pesos da rede neural na subida (verificado via Lazy Loading).
2. **Latência de Inferência em CPU:** $\le 350\text{ ms}$ por mensagem em ambiente de produção (medida no campo `inference_time_ms` da resposta).
3. **Latência de Alerta Crítico E2E:** Recebimento do alerta no aplicativo Flutter via WebSocket em $\le 2,0\text{ s}$ após o envio pelo simulador.
4. **Verificação de Contrato OpenAPI:** Teste automatizado de compatibilidade entre as rotas/schemas do FastAPI e o contrato documentado em `contrato-api.md`.
5. **Consistência Criptográfica do Simulador:** Teste automatizado comparando o hash SHA-256 gerado pelo browser via Web Crypto com ferramenta de CLI/Python para payloads com acentuação e emojis.

---

## 8. Alinhamento dos Eixos e Módulos do Sistema

| Módulo | Repositório | Tecnologias Principais | Modos de Operação |
|---|---|---|---|
| **Backend** | `backend/` | Python 3.11, FastAPI, PyTorch (CPU), Transformers, SQLAlchemy (SQLite), ReportLab | `production` (pesos reais de `/models`) ou `testing` (mock factory para testes rápidos) |
| **Frontend** | `frontend/` | Flutter 3.x, Dart (Mobile Android) | Modo Mock (100% desacoplado sem rede) e Modo Real (conectado a `http://10.0.2.2:8000` e WebSocket) |
| **Simulador** | `simulator/` | HTML5, CSS3, Vanilla JavaScript, Web Crypto API | Execução local na porta 3000 servido via Nginx estático |
| **Treinamento** | `scripts/` | JupyterLab, Datasets CSV | Perfil opcional `docker compose --profile training up` na porta 8888 |

---

## 9. Conclusão da Mineração

Todas as especificações técnicas, regras de negócio, tabelas de decisão, máquinas de estado, contratos de API e modelos de arquitetura foram completamente mapeados e conferidos. As regras de prevalência foram respeitadas e o projeto dispõe de documentação autoritativa pronta para balizar a implementação dos eixos de Backend, Frontend, Simulador e Integração.
