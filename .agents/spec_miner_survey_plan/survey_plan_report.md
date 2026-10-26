# Relatório Completo de Levantamento do Plano de Ação: Project Artemis

**Data de Emissão:** 2026-10-09  
**Autor:** Specification Miner (Teamwork Specialist)  
**Ambiente:** Windows / Git Development Branch  
**Repositório Base:** `C:\projects\Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos`  
**Fontes de Verdade Analisadas:**
- `plano de ação/README.md`
- `plano de ação/backend/` (`README.md`, `01_dominio_e_regras_puras.md`, `02_infraestrutura_e_ia_bertimbau.md`, `03_servicos_de_aplicacao.md`, `04_api_rest_e_websocket.md`, `05_testes_backend_e_ci.md`)
- `plano de ação/frontend/` (`README.md`, `01_modelos_e_mock_contracts.md`, `02_autenticacao_e_feed_incidentes.md`, `03_detalhe_incidente_e_acoes.md`, `04_calibracao_e_notificacoes_locais.md`, `05_testes_widgets_e_ui.md`)
- `plano de ação/simulador/` (`README.md`, `01_layout_e_interface_chat.md`, `02_criptografia_webcrypto_e_payload.md`, `03_botoes_cenarios_e_feedback_visual.md`)
- `plano de ação/integracao/` (`README.md`, `01_orquestracao_docker_e_conexoes.md`, `02_roteiro_de_testes_e2e.md`, `03_auditoria_sha256_e_relatorio_pdf.md`, `04_checklist_final_mvp_tcc.md`)
- `.agents/ORIGINAL_REQUEST.md`

---

## 1. Visão Executiva e Contexto do Projeto

O **Project Artemis** é um sistema inteligente de controle parental focado na detecção em tempo real de ciberbullying e ameaças virtuais (phishing, links maliciosos) em mensagens de chats de jogos e mensageiros. O projeto foi desenhado para equilibrar a segurança do menor com a preservação de sua privacidade (princípios da LGPD e não-vigilância invasiva), processando mensagens via inferência em CPU com o modelo **BERTimbau** (`GuilhermeLA/modelo-tcc-final`), retendo apenas mensagens ofensivas e descartando dados de conversas seguras.

O plano de ação está estruturado em **4 eixos autônomos e desacoplados**:
1. **Backend (Python / FastAPI / PyTorch CPU / SQLite):** Domínio puro, Lazy Virtual Proxy de IA, buffer circular de contexto e endpoints REST/WebSocket.
2. **Frontend (Flutter / Android):** Aplicativo para os responsáveis, com suporte a modo 100% Mock, notificações sonoras locais, gestão de ciclo de vida de incidentes e visualização pericial em PDF.
3. **Simulador (HTML5 / Vanilla JS / Web Crypto API):** Interface web estática que simula conversas de jogos, gera hashes criptográficos SHA-256 no browser e injeta cenários de teste pré-configurados.
4. **Integração (Docker Compose / E2E):** Orquestração dos serviços, roteiro de validação ponta a ponta, auditoria forense de integridade probatória e checklist final para o TCC (prazo: 20/10/2026).

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Backend Domain | Avaliação de Risco e Tabela de Decisão | Combina probabilidade $P(\text{nocivo})$, flag `has_link`, limiar comum do dependente e tipo de sala para definir severidade e ação requerida. | `probabilidade` (float 0.0-1.0), `limiar_comum` (float 0.50-0.84), `room_type` ("jogo" ou "conversa"), `has_link` (bool) | Tupla `(CategoriaAmeaca, AcaoRequerida)`: `CIBERBULLYING`, `LINK_SUSPEITO` ou `SEGURO`; `ALERT_PARENT_CRITICAL`, `LOG_INCIDENT` ou `NONE` | Valores fora de limites devem ser validados antes; limiar gamer elevado automaticamente | `backend/01_dominio_e_regras_puras.md` |
| 2 | Backend Domain | Modo Gamer | Eleva dinamicamente o limiar de tolerância de ciberbullying para $L = \max(L, 0.70)$ caso a sala seja de jogo (`room_type == "jogo"`), evitando falsos positivos com trash talk e gírias. | `room_type == "jogo"`, `limiar_comum` | Limiar efetivo $L \ge 0.70$ | Se `room_type != "jogo"`, mantém `limiar_comum` original | `backend/01_dominio_e_regras_puras.md`, `README.md` |
| 3 | Backend Domain | Limiar Crítico Fixo | Dispara alerta crítico imediato quando a confiança do modelo atinge ou ultrapassa $0.85$, sobrepondo qualquer configuração parental. | `probabilidade >= 0.85` | `(CIBERBULLYING, ALERT_PARENT_CRITICAL)` | Irrevogável; ignora limiar do guardião | `backend/01_dominio_e_regras_puras.md` |
| 4 | Backend Domain | Derivação do Papel do Menor | Determina se o dependente monitorado foi vítima, agressor ou espectador da mensagem com base nos metadados da transmissão. | `is_from_minor` (bool), `is_direct` (bool) | `PapelMenor`: `EMISSOR` (se `is_from_minor`), `VITIMA` (se não for do menor e mensagem direta), `ESPECTADOR` (se grupo) | Lógica determinística estrita | `backend/01_dominio_e_regras_puras.md` |
| 5 | Backend Domain | Máquina de Estados e Transições de Status | Controla o ciclo de vida do incidente impedindo saltos ilegais ou inconsistências processuais. | `status_atual`, `novo_status` | Status atualizado ou lista de transições permitidas (`allowed_transitions`) | Rejeição com erro 409 Conflict se transição não pertencer a `TRANSIÇÕES_VALIDAS` | `backend/01_dominio_e_regras_puras.md`, `backend/03_servicos_de_aplicacao.md` |
| 6 | Backend Infrastructure | Virtual Proxy BERTimbau (Lazy Loading) | Adia o carregamento de pesos de IA PyTorch em CPU até a primeira inferência, garantindo boot rápido do FastAPI ($< 2$ s). | Primeira chamada a `predict_probability(texto)` | Instanciação transparente de `RealBERTimbauEngine` e cálculo de $P(\text{nocivo})$ | Se arquivos de modelo ausentes, lança erro de inicialização; em testes usa `MockClassificadorFactory` | `backend/02_infraestrutura_e_ia_bertimbau.md` |
| 7 | Backend Infrastructure | Detector de Links Determinístico | Identifica URLs e links suspeitos por meio de expressão regular pré-compilada de alta velocidade (`https?://\S+|www\.\S+`). | `texto` (str) | `has_link` (bool) | Avalia em tempo linear sem regex backtracking catastrófico | `backend/02_infraestrutura_e_ia_bertimbau.md` |
| 8 | Backend Infrastructure | Buffer Circular de Contexto em Memória | Retém até as últimas 3 mensagens por `conversation_id` em fila circular `deque(maxlen=3)` para contextualização de incidentes. | `conversation_id`, objeto de mensagem | Contexto anterior (até 3 msgs) para incidentes | Mensagens antigas são descartadas da memória por FIFO | `backend/02_infraestrutura_e_ia_bertimbau.md` |
| 9 | Backend Infrastructure | Captura de Contexto Posterior | Coleta até 3 mensagens subsequentes que chegarem no mesmo `conversation_id` dentro de uma janela temporal de 10 minutos. | Mensagens subsequentes da mesma conversa | Inclusão em `mensagens_contexto` com flag `AFTER` | Mensagens que chegam após 10 minutos da criação do incidente são ignoradas para anexo posterior | `backend/02_infraestrutura_e_ia_bertimbau.md`, `backend/03_servicos_de_aplicacao.md` |
| 10 | Backend Services | Verificação de Integridade SHA-256 | Compara o hash informado pelo cliente com o SHA-256 recalculado pelo servidor para assegurar cadeia probatória. | `text`, `message_hash` | `sha256_match` (bool), persistência de `integrity_mismatch = !sha256_match` | Mensagens com divergência não são rejeitadas, mas sim sinalizadas para auditoria pericial | `backend/03_servicos_de_aplicacao.md`, `integracao/03_auditoria_sha256_e_relatorio_pdf.md` |
| 11 | Backend Services | Não Retenção de Mensagens Seguras (LGPD) | Mensagens avaliadas como `SEGURO` nunca são gravadas no banco de dados, incrementando apenas um contador cumulativo. | Mensagem segura avaliada como `NONE` | Incremento de `safe_messages_count` no dependente; `incident_id = None` retornado | Texto é descartado da persistência | `backend/03_servicos_de_aplicacao.md`, `integracao/04_checklist_final_mvp_tcc.md` |
| 12 | Backend Services | Gestão e Transição com Feedback | Permite avançar o status do incidente gravando histórico com notas e registrando feedback caso marcado como falso positivo. | `incident_id`, `novo_status`, `note`, `guardian_id` | Histórico gravado, registro em `feedbacks_falso_positivo` se aplicável | 409 se transição inválida; 404 se incidente não existir | `backend/03_servicos_de_aplicacao.md` |
| 13 | Backend Services | Exclusão Definitiva em Cascata (LGPD) | Remove completamente o incidente e seus registros associados (contexto, histórico, feedback) mediante permissão primária. | `incident_id`, `guardian_id` | Status 204 No Content, emissão de evento `incident.deleted` via WebSocket | 403 Forbidden se solicitante for responsável secundário; 404 se não encontrado | `backend/03_servicos_de_aplicacao.md`, `backend/04_api_rest_e_websocket.md` |
| 14 | Backend Services | Emissão de Relatório Pericial em PDF | Gera documento formal com cabeçalho institucional, veredito de custódia SHA-256, balões de contexto e histórico. | `incident_id`, `guardian_id` | Fluxo de bytes binários `application/pdf` gerado via ReportLab | 404 se incidente não existir; 403 se guardião não tiver acesso ao dependente | `backend/03_servicos_de_aplicacao.md`, `integracao/03_auditoria_sha256_e_relatorio_pdf.md` |
| 15 | Backend Services | Escalonamento Automático de Incidentes Críticos | Rotina periódica em segundo plano (a cada 60 s) que busca incidentes críticos pendentes de visualização há $> 15$ minutos e alerta responsáveis secundários. | Loop assíncrono em `created_at < (now - 15min)` e `status == DETECTADO` | Disparo de evento `incident.escalated` no WebSocket e marcação `escalated = True` | Idempotente; executa sem bloquear requisições HTTP | `backend/03_servicos_de_aplicacao.md` |
| 16 | Backend API | Endpoint de Predição Neural | `POST /api/v1/predict` público para ingestão de mensagens de jogos. | JSON com `text`, `message_hash`, `dependent_id`, `context_metadata` | JSON com label, categoria, confiança, ação, papel, sha256_match, incident_id, tempo_ms | 400 Bad Request se texto vazio; 404 Not Found se dependente inexistente | `backend/04_api_rest_e_websocket.md` |
| 17 | Backend API | Autenticação Parental JWT | `POST /api/v1/auth/login` e `GET /api/v1/auth/me` usando hashes de senha Argon2id e tokens PyJWT (HS256, 24h). | E-mail e senha | Token JWT e perfil do guardião com dependentes | 401 Unauthorized para credenciais incorretas ou tokens expirados | `backend/04_api_rest_e_websocket.md` |
| 18 | Backend API | Calibração de Sensibilidade | `PATCH /api/v1/dependents/{id}/threshold` para ajuste do limiar comum ($0.50 \le L \le 0.84$). | `threshold` (float) | Status 200 OK com dependente atualizado | 400 se fora da faixa [0.50, 0.84]; 403 se guardião não for primário | `backend/04_api_rest_e_websocket.md` |
| 19 | Backend API | WebSocket Gateway em Tempo Real | `/ws?token=<jwt>` para envio bidirecional de eventos e monitoramento contínuo. | Conexão WS com JWT na query; frames ping/pong | Mensagens JSON (`incident.created`, `incident.critical`, `incident.escalated`, `incident.updated`, `incident.deleted`) | Desconexão limpa caso token expire ou socket caia | `backend/04_api_rest_e_websocket.md` |
| 20 | Frontend Models | Modelagem Desacoplada Dart e Mocks | Estrutura de classes Dart e serviços abstratos com implementações `MockApiService` e `MockWebSocketService`. | Parâmetros de métodos de serviço | Modelos fortemente tipados (`IncidentSummary`, `IncidentDetail`, etc.) | Retorno de mocks estáticos com delays simulados de 300 ms | `frontend/01_modelos_e_mock_contracts.md` |
| 21 | Frontend UI | Feed de Incidentes com Filtros e Badges | Lista de cards com severidade colorida, indicação de papel do menor, filtro por dependente e pull-to-refresh. | Interações de toque e seleção do usuário | Renderização reativa da lista de incidentes | Exibe estado vazio amigável quando não houver incidentes | `frontend/02_autenticacao_e_feed_incidentes.md` |
| 22 | Frontend UI | Detalhe do Incidente e Visualização Automática | Abre o incidente e dispara automaticamente `POST /view` (DETECTADO $\rightarrow$ VISUALIZADO), exibindo balões de contexto anterior e posterior. | Toque em card de incidente | Mudança transparente de status e renderização de chat | Trata falha de rede sem travar a navegação | `frontend/03_detalhe_incidente_e_acoes.md` |
| 23 | Frontend UI | Transição de Status com Tradução | Diálogo modal alimentado dinamicamente por `allowed_transitions` com rótulos amigáveis em português e campo de observação. | Seleção do novo status e texto opcional/obrigatório | Disparo de `PATCH /status` e atualização da timeline | Validação de campo de nota para falsos positivos | `frontend/03_detalhe_incidente_e_acoes.md` |
| 24 | Frontend UI | Painel de Calibração com Restrição Primária | Slider com intervalo restrito de $0.50$ a $0.84$ com legendas explicativas e bloqueio para guardiões secundários. | Arraste do slider pelo usuário | Atualização do limiar via API | Desabilita interação se `is_primary == false` | `frontend/04_calibracao_e_notificacoes_locais.md` |
| 25 | Frontend Services | Notificações Locais Sonoras | Canal Android prioritário (`artemis_critical_alerts`) disparado por eventos WebSocket críticos e de escalonamento. | Evento WebSocket `incident.critical` ou `incident.escalated` | Notificação push do sistema com som e vibração | Solicita permissão `POST_NOTIFICATIONS` no Android 13+ | `frontend/04_calibracao_e_notificacoes_locais.md` |
| 26 | Simulator UI | Interface Web Vanilla de Conversas | Página HTML/CSS puro inspirada em interfaces gamer (Discord/Steam) com modo escuro e seletores de contexto. | Digitação de texto, seletores de dependente, sala e remetente | Balões de mensagem bilaterais com rolagem automática | Layout estático servido via Nginx sem necessidade de build node | `simulador/01_layout_e_interface_chat.md` |
| 27 | Simulator Crypto | Assinatura SHA-256 no Navegador | Gera hash SHA-256 diretamente no navegador via Web Crypto API nativa (`crypto.subtle.digest`). | String da mensagem enviada | Hexadecimal minúsculo de 64 caracteres | Compatível com codificação UTF-8 (acentos e emojis) | `simulador/02_criptografia_webcrypto_e_payload.md` |
| 28 | Simulator Demo | Presets de Demonstração Rápida | Botões com mensagens pré-configuradas para demonstração perante a banca (Segura, Modo Gamer, Crítica, Link, Hash Divergente). | Clique no botão de atalho | Envio automático da requisição com payload formatado | Disparo em um clique | `simulador/03_botoes_cenarios_e_feedback_visual.md` |
| 29 | Simulator UI | Rodapé de Auditoria e Selo Visual | Exibe no balão do simulador a probabilidade, tempo de inferência, status SHA-256 e selo de severidade recebidos do backend. | Resposta JSON da API | Emblema visual (Verde, Amarelo ou Vermelho) e métricas técnicas | Mostra mensagem de erro amigável caso backend esteja offline | `simulador/03_botoes_cenarios_e_feedback_visual.md` |
| 30 | Integration | Orquestração Docker Compose | Sobe simultaneamente o container do backend (porta 8000) e do simulador (porta 3000) com volumes mapeados. | Comando `docker compose up` | Ambientes operacionais interconectados | Configura políticas de reinicialização e variáveis de ambiente | `integracao/01_orquestracao_docker_e_conexoes.md` |

---

## 3. Edge Cases

| # | Feature | Input | Observed / Specified Behavior |
|---|---------|-------|-------------------------------|
| 1 | Predição Neural (`POST /predict`) | Texto contendo apenas espaços (`text = "   "`) | Rejeição imediata com código HTTP **400 Bad Request**; inferência não é executada. |
| 2 | Predição Neural (`POST /predict`) | `dependent_id` inexistente na base de dados (ex: `dep-999`) | Retorno de erro HTTP **404 Not Found** com detalhe indicando dependente não localizado. |
| 3 | Verificação Criptográfica | `message_hash` enviado no payload diverge do SHA-256 real do texto (simulação de adulteração em trânsito) | Requisição é aceita com HTTP **200 OK**, mas `sha256_match = False`. O incidente é persistido com flag `integrity_mismatch = True`. O app mobile exibe alerta visual de divergência e o relatório PDF imprime o carimbo pericial de `INTEGRIDADE DIVERGENTE`. |
| 4 | Limiar Crítico Fixo | Mensagem com probabilidade exatamente $0.850$ ($P = 0.850$) | Classificada imediatamente como `CIBERBULLYING` e ação `ALERT_PARENT_CRITICAL`. Dispara simultaneamente eventos `incident.created` e `incident.critical` no WebSocket, mesmo se o limiar do pai estivesse configurado em $0.84$. |
| 5 | Limiar Crítico de Borda Inferior | Mensagem com probabilidade $P = 0.849$ em sala de conversa com limiar do pai em $0.80$ | Classificada como `CIBERBULLYING` com ação `LOG_INCIDENT`. O incidente é registrado no banco e exibido no feed do app, mas NÃO dispara alerta com sirene nem evento `incident.critical`. |
| 6 | Modo Gamer em Sala de Jogo | `room_type = "jogo"`, `limiar_comum = 0.50`, mensagem com $P = 0.65$ | O sistema eleva o limiar efetivo para $L = \max(0.50, 0.70) = 0.70$. Como $0.65 < 0.70$, a mensagem é classificada como `SEGURO` e ação `NONE`, absorvendo a linguagem competitiva do jogo sem alarmar os pais. |
| 7 | Modo Gamer em Sala de Jogo | `room_type = "jogo"`, `limiar_comum = 0.80`, mensagem com $P = 0.75$ | O limiar efetivo permanece $L = \max(0.80, 0.70) = 0.80$. Como $0.75 < 0.80$, a mensagem é considerada `SEGURO`. |
| 8 | Detecção de Link em Mensagem Neutra | Texto contendo link legítimo (ex: `https://escola.edu.br`) e $P(\text{nocivo}) = 0.12$ | Como contém link e $P < L$, o classificador atribui categoria `LINK_SUSPEITO` e ação `LOG_INCIDENT`, registrando para auditoria dos pais. |
| 9 | Limite do Buffer de Mensagens Anteriores | Mais de 3 mensagens enviadas na mesma conversa antes do incidente | O buffer circular (`deque(maxlen=3)`) descarta as mensagens mais antigas por FIFO e preserva estritamente as 3 mensagens imediatamente precedentes ao incidente. |
| 10 | Janela Temporal de Contexto Posterior | Mensagem subsequente enviada 11 minutos após a ocorrência do incidente na mesma conversa | Como ultrapassou a janela de 10 minutos estabelecida para o incidente aberto, a mensagem é processada isoladamente e NÃO é anexada ao `context_after` do incidente anterior. |
| 11 | Limite de Quantidade de Contexto Posterior | Quarta mensagem subsequente enviada dentro da janela de 10 minutos | Como o limite máximo de mensagens posteriores por incidente é 3, a quarta mensagem é processada mas não anexa ao contexto posterior. |
| 12 | Transição Ilegal de Status | Tentativa de mudar de `DETECTADO` diretamente para `RESOLVIDO` ou de `RESOLVIDO` para qualquer outro status | O serviço valida contra o grafo de `TRANSIÇÕES_VALIDAS` e rejeita a requisição com HTTP **409 Conflict**. |
| 13 | Idempotência da Marcação de Visualização | Chamada repetida a `POST /incidents/{id}/view` quando o incidente já está em `VISUALIZADO` ou `EM_ANALISE` | A operação é idempotente: mantém o status corrente, não gera duplicidade no histórico de transições e retorna HTTP 200 com o detalhe atualizado. |
| 14 | Permissões de Responsável Secundário (LGPD) | Guardião secundário (`is_primary == false`) tenta executar `DELETE /incidents/{id}` | Ação rejeitada imediatamente com HTTP **403 Forbidden**. Apenas o guardião primário pode solicitar a exclusão de dados. |
| 15 | Permissões de Responsável Secundário (Threshold) | Guardião secundário tenta executar `PATCH /dependents/{id}/threshold` | Ação rejeitada com HTTP **403 Forbidden**. O app mobile renderiza o slider em modo somente leitura com aviso visual. |
| 16 | Limites de Calibração do Limiar | Tentativa de definir limiar menor que $0.50$ ou maior que $0.84$ (ex: $0.45$ ou $0.90$) | A API rejeita a requisição com HTTP **400 Bad Request** informando violação dos limites de calibragem permitidos pelo domínio. |
| 17 | Escalonamento de Incidente Crítico Abandonado | Incidente crítico ($P \ge 0.85$) permanece no status `DETECTADO` por mais de 15 minutos sem visualização do primário | O `EscalonamentoService` identifica a pendência no ciclo de 60 s, marca `escalated = True` e envia evento WebSocket `incident.escalated` para os responsáveis secundários cadastrados. |
| 18 | Descarte de Mensagem Segura (LGPD) | Mensagem com $P = 0.10$ sem links em sala de conversa | A mensagem é processada, alimenta o buffer em memória, incrementa `safe_messages_count` e é descartada. Nenhum registro é gravado nas tabelas `incidentes` ou `mensagens_contexto`. |
| 19 | Exclusão em Cascata (LGPD) | Exclusão definitiva de um incidente com contexto, histórico e feedback | O banco remove fisicamente em cascata o registro do incidente, todas as mensagens de contexto (`BEFORE` e `AFTER`), as entradas de `historico_status` e o feedback de falso positivo, sem deixar registros órfãos. |
| 20 | Caracteres Especiais, Emojis e Acentuação no SHA-256 | Mensagem contendo emojis e acentos (ex: "Você é um lixo 😡!") | A codificação UTF-8 uniforme no cliente (`TextEncoder`) e no servidor (`texto.encode('utf-8')`) garante que o hash gerado pela Web Crypto API coincida perfeitamente com o calculado em Python. |

---

## 4. Detalhamento Tarefa a Tarefa por Módulo/Eixo

### EIXO 1: BACKEND (Python / FastAPI / PyTorch CPU / SQLite)

#### Task 01: Domínio e Regras Puras
- **Objetivo:** Estabelecer o núcleo de regras de negócio em Python puro sem dependências externas (sem PyTorch, FastAPI ou SQLAlchemy).
- **Entregáveis e Arquivos:**
  - `backend/src/domain/__init__.py`
  - `backend/src/domain/enums.py`
  - `backend/src/domain/entities.py`
  - `backend/src/domain/rules.py`
- **Passos de Implementação:**
  1. Definir os Enums de domínio: `CategoriaAmeaca` (`SEGURO`, `CIBERBULLYING`, `LINK_SUSPEITO`), `AcaoRequerida` (`NONE`, `LOG_INCIDENT`, `ALERT_PARENT_CRITICAL`), `PapelMenor` (`VITIMA`, `EMISSOR`, `ESPECTADOR`), `StatusIncidente` (`DETECTADO`, `VISUALIZADO`, `EM_ANALISE`, `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO`, `RESOLVIDO`) e `TipoEventoWS`.
  2. Implementar a tabela de decisão em `AvaliadorDecisaoRisco`:
     - $P \ge 0.85 \implies$ `(CIBERBULLYING, ALERT_PARENT_CRITICAL)`.
     - $L = \text{limiar}$ (se `room_type == "jogo"`, $L = \max(\text{limiar}, 0.70)$).
     - Se $P \ge L \implies$ `(CIBERBULLYING, LOG_INCIDENT)`.
     - Se `has_link == True` $\implies$ `(LINK_SUSPEITO, LOG_INCIDENT)`.
     - Senão $\implies$ `(SEGURO, NONE)`.
  3. Implementar a função `derivar_papel_menor(is_from_minor, is_direct)`.
  4. Mapear o dicionário de transições válidas de status `TRANSIÇÕES_VALIDAS` e a função auxiliar `obter_transicoes_permitidas(status_atual)`.
- **Critérios de Aceitação e Testes:**
  - Testes unitários para `AvaliadorDecisaoRisco` cobrindo todos os casos de BVA (Boundary Value Analysis).
  - Testes de transição de status cobrindo caminhos permitidos e rejeição de saltos proibidos.
  - Zero dependências de bibliotecas de terceiros no pacote `src/domain/`.

#### Task 02: Infraestrutura e IA BERTimbau
- **Objetivo:** Implementar os adaptadores de infraestrutura para inferência em CPU via Virtual Proxy, detecção de links por regex, buffer circular e banco SQLite via SQLAlchemy 2.0.
- **Entregáveis e Arquivos:**
  - `backend/src/infrastructure/__init__.py`
  - `backend/src/infrastructure/bertimbau_engine.py`
  - `backend/src/infrastructure/link_detector.py`
  - `backend/src/infrastructure/in_memory_buffer.py`
  - `backend/src/infrastructure/database.py`
  - `backend/src/infrastructure/repositories.py`
  - `backend/src/config.py`
- **Passos de Implementação:**
  1. Criar a interface abstrata `ClassificadorStrategy` e a classe `BERTimbauEngineProxy` (Lazy Proxy). Instanciar `RealBERTimbauEngine` apenas na primeira chamada a `predict_probability`.
  2. Implementar `RealBERTimbauEngine` utilizando `AutoTokenizer` e `AutoModelForSequenceClassification` apontando para `GuilhermeLA/modelo-tcc-final`, com inferência em CPU, `torch.no_grad()` e Softmax binário.
  3. Criar `MockClassificadorFactory` para injeção rápida de dependência quando `APP_ENV == "testing"`.
  4. Desenvolver `DetectorDeLinks` usando o regex `https?://\S+|www\.\S+` ignorando maiúsculas/minúsculas.
  5. Implementar `InMemoryBuffer` com dicionário de `deque(maxlen=3)` por `conversation_id` e controle de incidentes abertos (janela de 10 min e até 3 mensagens posteriores).
  6. Configurar o SQLAlchemy com SQLite (`DATABASE_URL = sqlite:////app/data/artemis.db`) e declarar os modelos ORM: `responsaveis`, `dependentes`, `responsaveis_dependentes`, `incidentes`, `mensagens_contexto`, `historico_status`, `feedbacks_falso_positivo`, `convites_coparentalidade`.
- **Critérios de Aceitação e Testes:**
  - O aplicativo deve iniciar em $< 2$ segundos sem carregar pesos de IA pesados no boot.
  - Validação de URLs com `http://`, `https://` e `www.` pelo `DetectorDeLinks`.
  - Buffer circular retém exatamente as últimas 3 mensagens e anexa posteriores conforme janela temporal.
  - Criação automática e integridade das tabelas SQLite no startup.

#### Task 03: Serviços de Aplicação
- **Objetivo:** Desenvolver a camada de orquestração de casos de uso sem vazar lógica para os controladores de rota.
- **Entregáveis e Arquivos:**
  - `backend/src/services/__init__.py`
  - `backend/src/services/analise_service.py`
  - `backend/src/services/gestao_incidente_service.py`
  - `backend/src/services/relatorio_service.py`
  - `backend/src/services/escalonamento_service.py`
  - `backend/src/services/auth_service.py`
- **Passos de Implementação:**
  1. `AnaliseMensagemService`:
     - Anexar mensagem como posterior em incidentes abertos da mesma conversa.
     - Validar integridade SHA-256 (`message_hash.lower() == recalculado`).
     - Obter limiar do dependente e executar inferência + detector de links.
     - Executar `AvaliadorDecisaoRisco` e derivar papel do menor.
     - Se `NONE`: atualizar contador cumulativo, adicionar ao buffer e retornar sem persistir texto.
     - Se incidente: buscar contexto anterior, persistir tudo no SQLite, abrir janela de contexto posterior, notificar observers (WebSocket) e retornar `incident_id`.
  2. `GestaoIncidenteService`:
     - Métodos para listagem paginada por guardião, obtenção de detalhes, marcação de visualizado idempotente, atualização de status com registro de feedback e exclusão LGPD com checagem de primariedade.
  3. `RelatorioService`:
     - Implementar Template Method usando ReportLab gerando documento pericial com cabeçalho institucional, auditoria SHA-256, confiança, mensagens e histórico.
  4. `EscalonamentoService`:
     - Scheduler assíncrono a cada 60 s para alertar guardiões secundários caso incidente crítico com $P \ge 0.85$ permaneça em `DETECTADO` por $> 15$ minutos.
  5. `AuthService`:
     - Autenticação com Argon2id e geração/validação de tokens PyJWT.
- **Critérios de Aceitação e Testes:**
  - O fluxo de predição atende aos requisitos de não-retenção para mensagens seguras.
  - Exclusão LGPD remove dados em cascata sem registros órfãos.
  - O relatório PDF é gerado sem erros e com integridade visual e criptográfica.

#### Task 04: API REST e WebSocket Gateway
- **Objetivo:** Expor os endpoints REST e a conexão WebSocket em conformidade estrita com o contrato oficial de `.agents/contrato-api.md`.
- **Entregáveis e Arquivos:**
  - `backend/src/api/v1/predict.py`
  - `backend/src/api/v1/auth.py`
  - `backend/src/api/v1/dependents.py`
  - `backend/src/api/v1/incidents.py`
  - `backend/src/api/websocket.py`
  - `backend/src/api/schemas.py`
  - `backend/src/main.py`
  - `backend/src/seed.py`
- **Passos de Implementação:**
  1. Definir esquemas Pydantic rígidos para requisições e respostas em `schemas.py`.
  2. Implementar rota pública `POST /api/v1/predict` com validação de texto não-vazio e dependente existente.
  3. Implementar rotas de autenticação `POST /api/v1/auth/login` e `GET /api/v1/auth/me`.
  4. Implementar rotas de dependentes `GET /api/v1/dependents` e `PATCH /api/v1/dependents/{id}/threshold` (com validação de faixa 0.50-0.84 e 403 se secundário).
  5. Implementar rotas de incidentes (`GET /incidents`, `GET /{id}`, `POST /{id}/view`, `PATCH /{id}/status`, `GET /{id}/report`, `DELETE /{id}`).
  6. Desenvolver `ConnectionManager` para WebSocket em `/ws?token=<jwt>` com suporte a ping/pong e padrão Observer para emissão de eventos direcionados.
  7. Criar script de dados de teste `python -m src.seed` com os dados canônicos (`resp-001`, `resp-002`, `dep-001`, `dep-002`).
- **Critérios de Aceitação e Testes:**
  - Documentação Swagger (`/docs`) e OpenAPI refletem 100% dos esquemas de `.agents/contrato-api.md`.
  - Rotas protegidas barram acessos não autorizados com código 401.
  - Rotas de guardião primário rejeitam guardiões secundários com código 403.
  - O gateway WebSocket conecta, autentica e distribui eventos JSON.

#### Task 05: Testes de Backend e CI/CD
- **Objetivo:** Garantir a robustez do backend com suítes de testes unitários e de integração automatizados.
- **Entregáveis e Arquivos:**
  - `backend/tests/conftest.py`
  - `backend/tests/unit/test_domain_rules.py`
  - `backend/tests/unit/test_link_detector.py`
  - `backend/tests/unit/test_in_memory_buffer.py`
  - `backend/tests/unit/test_bertimbau_engine.py`
  - `backend/tests/integration/test_predict_api.py`
  - `backend/tests/integration/test_auth_api.py`
  - `backend/tests/integration/test_incidents_api.py`
  - `backend/tests/integration/test_websocket.py`
- **Passos de Implementação:**
  1. Configurar `conftest.py` com `APP_ENV = "testing"`, banco SQLite em memória (`sqlite:///:memory:`) e injeção do seed.
  2. Escrever testes unitários BVA cobrindo todos os limiares críticos, comuns e Modo Gamer.
  3. Testar a máquina de estados, o detector de links e o buffer circular de mensagens.
  4. Escrever testes de integração para todos os endpoints utilizando o `TestClient` do FastAPI.
  5. Validar o fluxo de autenticação, permissões e emissão de relatórios.
- **Critérios de Aceitação e Testes:**
  - `APP_ENV=testing pytest` passa 100% em $< 5$ segundos.
  - Cobertura de testes superior a 85% em domínio e serviços.
  - Nenhum download externo de modelos durante a suíte de testes.

---

### EIXO 2: FRONTEND (Flutter / Android)

#### Task 01: Modelos e Contratos de Mock
- **Objetivo:** Estruturar as classes de modelo em Dart e interfaces desacopladas com mocks para permitir o desenvolvimento visual 100% independente do backend.
- **Entregáveis e Arquivos:**
  - `frontend/lib/models/incident.dart`
  - `frontend/lib/models/dependent.dart`
  - `frontend/lib/models/guardian.dart`
  - `frontend/lib/models/context_message.dart`
  - `frontend/lib/models/status_history.dart`
  - `frontend/lib/services/api_service.dart`
  - `frontend/lib/services/mock_api_service.dart`
  - `frontend/lib/services/websocket_service.dart`
  - `frontend/lib/services/mock_websocket_service.dart`
  - `frontend/lib/config.dart`
- **Passos de Implementação:**
  1. Definir os modelos Dart com factories `fromJson` e métodos `toJson` espelhando os esquemas da API.
  2. Criar a interface abstrata `ApiService` com métodos CRUD completos.
  3. Implementar `MockApiService` com base de dados simulada em memória e atraso proposital de 300 ms.
  4. Criar a interface abstrata `WebSocketService` e implementar `MockWebSocketService` com `StreamController.broadcast()`, fornecendo gatilho para simular alertas críticos.
- **Critérios de Aceitação e Testes:**
  - Todos os modelos serializam e deserializam JSONs do contrato sem inconsistências.
  - Chamadas às funções mock retornam dados consistentes em memória.

#### Task 02: Autenticação e Feed de Incidentes
- **Objetivo:** Desenvolver as telas de Login e Feed de Incidentes garantindo clareza e atualização dinâmica.
- **Entregáveis e Arquivos:**
  - `frontend/lib/screens/login_screen.dart`
  - `frontend/lib/screens/incidents_feed_screen.dart`
  - `frontend/lib/widgets/incident_card.dart`
  - `frontend/lib/widgets/dependent_selector.dart`
  - `frontend/lib/widgets/severity_badge.dart`
- **Passos de Implementação:**
  1. Desenvolver `LoginScreen` com validação de campos, chamada à API/Mock, tratamento de erro 401 e armazenamento seguro do token via `flutter_secure_storage`.
  2. Criar `IncidentsFeedScreen` com AppBar contendo seletor por dependente ("Todos", "Lucas", "Ana") e botão de configurações.
  3. Implementar pull-to-refresh e cards de incidentes contendo badges de severidade (Vermelho para Crítico, Amarelo/Laranja para Comum), carimbo de data/hora amigável, papel do dependente e prévia do texto truncada em 60 caracteres.
- **Critérios de Aceitação e Testes:**
  - Fluxo de login funcional com persistência de token.
  - Feed exibe cards ordenados e atualiza instantaneamente ao alternar o seletor de dependentes.

#### Task 03: Detalhe do Incidente e Ações do Responsável
- **Objetivo:** Construir a tela detalhada de incidente, visualização do histórico de mensagens em estilo de chat, fluxo de mudança de status, download de PDF e exclusão LGPD.
- **Entregáveis e Arquivos:**
  - `frontend/lib/screens/incident_detail_screen.dart`
  - `frontend/lib/widgets/context_chat_bubble.dart`
  - `frontend/lib/widgets/status_timeline.dart`
  - `frontend/lib/widgets/status_transition_dialog.dart`
  - `frontend/lib/widgets/confirm_delete_dialog.dart`
- **Passos de Implementação:**
  1. Disparar `POST /incidents/{id}/view` automaticamente ao abrir a tela.
  2. Exibir cabeçalho com categoria, confiança percentual, papel do dependente e alerta caso `integrity_mismatch == true`.
  3. Renderizar o balão da mensagem principal em destaque e os balões das mensagens de contexto anterior e posterior em formato de conversa.
  4. Renderizar a timeline visual do histórico de status.
  5. Criar diálogo modal preenchido com as opções de `allowed_transitions` traduzidas para português.
  6. Implementar botão de download e abertura nativa de PDF via pacote `open_filex`.
  7. Adicionar botão de exclusão LGPD com confirmação irreversível, visível exclusivamente para guardiões primários (`is_primary == true`).
- **Critérios de Aceitação e Testes:**
  - Abertura da tela avança o status de `DETECTADO` para `VISUALIZADO`.
  - Modal de status obedece às transições permitidas.
  - Exclusão restrita a responsáveis primários.
  - Abertura de PDF opera com sucesso.

#### Task 04: Calibração de Sensibilidade e Notificações com Áudio
- **Objetivo:** Desenvolver o painel de ajuste do limiar de detecção e configurar o serviço de notificações locais com som.
- **Entregáveis e Arquivos:**
  - `frontend/lib/screens/dependent_config_screen.dart`
  - `frontend/lib/services/notification_service.dart`
  - `frontend/android/app/src/main/AndroidManifest.xml`
  - `frontend/pubspec.yaml`
- **Passos de Implementação:**
  1. Desenvolver `DependentConfigScreen` com slider restrito à faixa de $0.50$ a $0.84$, exibindo legendas explicativas (Máxima Proteção, Equilibrado, Tolerante), aviso sobre o Modo Gamer automático e exibição de `safe_messages_count`.
  2. Bloquear edição do slider caso `is_primary == false`.
  3. Configurar canal de notificações prioritário `artemis_critical_alerts` com `flutter_local_notifications` com som e vibração.
  4. Requisitar permissão `POST_NOTIFICATIONS` no Android 13+.
  5. Integrar o serviço ao listener de WebSocket para disparar alerta sonoro nos eventos `incident.critical` e `incident.escalated`, abrindo direto no detalhe do incidente ao tocar.
- **Critérios de Aceitação e Testes:**
  - O slider bloqueia valores fora do intervalo [0.50, 0.84].
  - Guardiões secundários não conseguem salvar calibração.
  - Notificação sonora é disparada no dispositivo ao receber evento crítico simulado ou real.

#### Task 05: Testes de Widgets e UI
- **Objetivo:** Validar a integridade da interface do Flutter através de testes de widget automatizados.
- **Entregáveis e Arquivos:**
  - `frontend/test/widget_test.dart`
  - `frontend/test/feed_screen_test.dart`
  - `frontend/test/detail_screen_test.dart`
  - `frontend/test/config_screen_test.dart`
- **Passos de Implementação:**
  1. Criar testes para renderização do feed, verificação de badges e navegação com `MockApiService`.
  2. Criar testes para a tela de detalhes validando balões de contexto, chamada a `markIncidentViewed` e exibição condicional do botão de exclusão.
  3. Criar testes para o slider de calibração na tela de configurações.
- **Critérios de Aceitação e Testes:**
  - `flutter test` passa 100% verde sem acoplamento a serviços de rede reais.

---

### EIXO 3: SIMULADOR (HTML5 / CSS3 / Vanilla JS)

#### Task 01: Layout e Interface do Chat
- **Objetivo:** Construir a interface web estática em estilo mensageiro instantâneo com painel de controle de parâmetros e feed de mensagens.
- **Entregáveis e Arquivos:**
  - `simulator/index.html`
  - `simulator/style.css`
  - `simulator/config.js`
  - `simulator/Dockerfile`
- **Passos de Implementação:**
  1. Criar layout HTML5 sem frameworks com sidebar de configurações: seletor de dependente (Lucas `dep-001`, Ana `dep-002`), seletor de sala (`jogo`, `conversa`), ID da conversa com botão gerador, campo de remetente e checkboxes para `is_from_minor` e `is_direct`.
  2. Criar área central de mensagens com contêiner com rolagem automática e campo de texto com envio por Enter ou botão.
  3. Estilizar via CSS3 em tema escuro (Dark Mode) inspirado em Discord e Steam.
- **Critérios de Aceitação e Testes:**
  - Interface carrega em qualquer navegador moderno sem erros de console.
  - Alternância de controles altera os estados globais da aplicação.

#### Task 02: Criptografia Web Crypto API e Formatação de Payload
- **Objetivo:** Implementar o cálculo criptográfico nativo de SHA-256 no browser do cliente e a formatação exata da requisição para a API.
- **Entregáveis e Arquivos:**
  - `simulator/app.js`
  - `simulator/config.js`
- **Passos de Implementação:**
  1. Desenvolver `calcularSha256(texto)` utilizando `crypto.subtle.digest("SHA-256", dados)` e `TextEncoder`, convertendo para hexadecimal minúsculo com padding de 2 dígitos.
  2. Implementar a montagem do payload compatível com `POST /api/v1/predict` (`text`, `message_hash`, `dependent_id`, `context_metadata`).
  3. Configurar tratamento de exceção amigável caso a API retorne erros ou esteja offline.
- **Critérios de Aceitação e Testes:**
  - O hash calculado coincide rigorosamente com ferramentas padrão de terminal (`sha256sum`, `openssl`).
  - O payload gerado valida perfeitamente contra os esquemas da API.

#### Task 03: Botões de Cenários Rápidos e Feedback Visual
- **Objetivo:** Adicionar botões de disparo rápido de cenários para demonstração na banca de TCC e rodapé de auditoria em cada balão de mensagem.
- **Entregáveis e Arquivos:**
  - `simulator/index.html`
  - `simulator/app.js`
  - `simulator/style.css`
- **Passos de Implementação:**
  1. Inserir 5 botões de atalho rápido no painel inferior:
     - 🟢 "Mensagem Segura" (*"Bora jogar de novo hoje à noite?"*)
     - 🟡 "Trash Talk Moderado (Jogo)" (*"Você joga muito mal, sai do time!"*)
     - 🔴 "Ciberbullying Crítico" (*"Você é um inútil, ninguém gosta de você, suma daqui!"*)
     - 🟣 "Link Suspeito" (*"Ganhe moedas grátis acessando https://recompensas-jogos.com/promo"*)
     - ⚠️ "Mensagem Corrompida (Integridade)" (envia hash alterado para teste forense)
  2. Renderizar em cada mensagem do chat um rodapé com:
     - Badge de severidade colorido (Vermelho para `ALERT_PARENT_CRITICAL`, Amarelo para `LOG_INCIDENT`, Verde/Cinza para `NONE`).
     - Percentual de confiança $P(\text{nocivo})$ e tempo de inferência em ms.
     - Papel detectado do menor.
     - Indicador de status de integridade do SHA-256.
- **Critérios de Aceitação e Testes:**
  - Disparo de cenários em 1 clique.
  - Exibição visual fiel das respostas da API.

---

### EIXO 4: INTEGRAÇÃO E VALIDAÇÃO END-TO-END

#### Task 01: Orquestração Docker Compose e Redes
- **Objetivo:** Orquestrar o ecossistema com Docker Compose e resolver a comunicação de rede entre navegador, contêineres e emulador Android.
- **Entregáveis e Arquivos:**
  - `docker-compose.yml`
  - `.env` / `.env.example`
  - `frontend/android/app/src/main/AndroidManifest.xml`
  - `frontend/lib/config.dart`
- **Passos de Implementação:**
  1. Configurar `docker-compose.yml` com serviço `backend` (FastAPI na porta 8000, volume `./models` e `./backend/data`) e serviço `simulator` (Nginx na porta 3000:80).
  2. Configurar CORS no backend para aceitar requisições de `http://localhost:3000`.
  3. Configurar `android:usesCleartextTraffic="true"` no `AndroidManifest.xml` do Flutter.
  4. Mapear resoluções de URL:
     - Simulador $\rightarrow$ `http://localhost:8000/api/v1/predict`
     - Emulador Android $\rightarrow$ `http://10.0.2.2:8000`
     - Dispositivo Físico $\rightarrow$ IP da LAN local.
- **Critérios de Aceitação e Testes:**
  - Um único comando `docker compose up -d` sobe os serviços sem erros.
  - Simulador consome a API sem bloqueios de CORS.
  - App Flutter no emulador conecta no backend e no canal WebSocket.

#### Task 02: Roteiro de Testes End-to-End (E2E)
- **Objetivo:** Executar e validar o fluxo completo entre os três sistemas em 6 cenários padronizados.
- **Entregáveis e Arquivos:**
  - Script/Relatório de testes E2E executados.
- **Passos de Implementação (6 Cenários):**
  1. *Cenário 1 (Login e WS):* Guardião loga no app móvel com dados de seed e conecta no WebSocket `/ws`.
  2. *Cenário 2 (Mensagem Segura):* Envio de mensagem neutra pelo simulador; verifica selo verde, tempo $< 350$ ms e incremento de `safe_messages_count` sem geração de incidente no feed.
  3. *Cenário 3 (Modo Gamer):* Envio de ofensa moderada em sala de jogo; limiar elevado para 0.70 absorve a mensagem sem alarme.
  4. *Cenário 4 (Alerta Crítico):* Envio de ciberbullying explícito ($P \ge 0.85$); verifica disparo de `incident.critical` no backend e notificação sonora imediata no Android.
  5. *Cenário 5 (Contexto Posterior):* Envio de mensagens subsequentes na mesma conversa; verifica que aparecem no balão de `context_after` nos detalhes do app.
  6. *Cenário 6 (Transição de Status):* Responsável altera status para "Conversei com meu filho" com nota explicativa e finaliza em "Incidente resolvido".
- **Critérios de Aceitação e Testes:**
  - Todos os 6 cenários operam com sucesso ponta a ponta.
  - Latência total do clique no simulador até o toque sonoro no app $\le 2.0$ segundos.

#### Task 03: Auditoria SHA-256 e Relatório PDF
- **Objetivo:** Comprovar a preservação probatória da cadeia de custódia e a emissão de relatórios periciais.
- **Entregáveis e Arquivos:**
  - Rotina de verificação pericial e arquivo PDF exportado de teste.
- **Passos de Implementação:**
  1. Executar teste de integridade positiva: enviar mensagem pelo simulador, abrir no app e gerar relatório PDF; checar seção de auditoria com status `AUTÊNTICO (SHA-256 VÁLIDO)` e hashes coincidentes.
  2. Executar teste de adulteração: enviar requisição com hash propositalmente corrompido; checar badge de aviso no app e carimbo de `INTEGRIDADE DIVERGENTE` no PDF gerado.
- **Critérios de Aceitação e Testes:**
  - Geração e download do relatório PDF em $< 1$ segundo.
  - Identificação precisa de autenticidade ou divergência criptográfica.

#### Task 04: Checklist Final do MVP para o TCC
- **Objetivo:** Auditar todos os casos de uso, requisitos não-funcionais e ensaiar o roteiro de apresentação perante a banca examinadora do TCC.
- **Entregáveis e Arquivos:**
  - `plano de ação/integracao/04_checklist_final_mvp_tcc.md` auditado e preenchido com evidências.
- **Passos de Implementação:**
  - Preencher e auditar os 10 Casos de Uso prioritários e os 5 Requisitos Não-Funcionais.
  - Simular o roteiro de apresentação de 10 minutos para a banca.
- **Critérios de Aceitação e Testes:**
  - Todos os itens do checklist marcados como concluídos com evidências comprovadas.

---

## 5. Mapeamento de Dependências e Ordem de Execução

### 5.1. Dependências Internas do Backend
```
Etapa 01 (Domínio e Regras Puras)
  │
  ▼
Etapa 02 (Infraestrutura e IA BERTimbau)
  │
  ▼
Etapa 03 (Serviços de Aplicação)
  │
  ▼
Etapa 04 (API REST e WebSocket Gateway)
  │
  ▼
Etapa 05 (Testes Automatizados e CI)
```
- A Etapa 01 não possui dependências.
- A Etapa 02 depende das entidades e enums da Etapa 01.
- A Etapa 03 orquestra os repositórios da Etapa 02 e as regras da Etapa 01.
- A Etapa 04 expõe os serviços da Etapa 03 em rotas HTTP e sockets.
- A Etapa 05 consolida a validação de todas as camadas anteriores.

### 5.2. Dependências Internas do Frontend
```
Etapa 01 (Modelos Dart e Mock Services)
  │
  ├───────────────────────────────┐
  ▼                               ▼
Etapa 02 (Login e Feed)       Etapa 04 (Calibração e Notificações Locais)
  │                               │
  ▼                               │
Etapa 03 (Detalhes e Ações)       │
  │                               │
  └───────────────┬───────────────┘
                  ▼
Etapa 05 (Testes de Widgets e UI)
```
- A Etapa 01 é o alicerce fundamental para todas as telas (desacoplamento via Mock).
- A Etapa 02 (Login e Feed) e a Etapa 04 (Calibração) podem ser desenvolvidas em paralelo.
- A Etapa 03 (Detalhes) requer os cards e modelos da Etapa 02.
- A Etapa 05 valida os widgets construídos nas etapas 02, 03 e 04.

### 5.3. Dependências Internas do Simulador
```
Etapa 01 (Layout HTML/CSS)
  │
  ▼
Etapa 02 (Web Crypto SHA-256 e Formatação do Payload)
  │
  ▼
Etapa 03 (Botões de Cenários Rápidos e Rodapé de Auditoria)
```
- A Etapa 01 cria a casca visual e os seletores de contexto.
- A Etapa 02 injeta a função assíncrona de hash e o disparo HTTP.
- A Etapa 03 conecta os botões pré-programados e o painel de métricas aos retornos da Etapa 02.

### 5.4. Dependências Globais e Início da Integração
```
   [ BACKEND ]          [ FRONTEND ]          [ SIMULADOR ]
 (Tasks 01 a 05)      (Tasks 01 a 05)       (Tasks 01 a 03)
        │                    │                     │
        └────────────────────┼─────────────────────┘
                             │ (Todos concluídos)
                             ▼
                    [ INTEGRAÇÃO E2E ]
                     (Tasks 01 a 04)
```
- **Regra Rígida do Projeto:** O agente de Integração só inicia o trabalho quando os módulos de Backend, Frontend e Simulador estiverem com suas tarefas e testes unitários 100% concluídos e verdes.
- No Frontend, a transição para integração real resume-se à substituição do `MockApiService` e `MockWebSocketService` por suas implementações reais de rede conectadas em `http://10.0.2.2:8000`.

---

## 6. Checklist Completo do MVP para o TCC (de `04_checklist_final_mvp_tcc.md`)

Abaixo estão transcritos de forma fidedigna e integral todos os itens, tabelas e roteiros estabelecidos no checklist oficial de entrega do MVP:

### 6.1. Tabela de Verificação de Casos de Uso do MVP

| ID | Caso de Uso | Componente Principal | Status / Verificação |
| :--- | :--- | :--- | :--- |
| **UC-18** | Autenticação Parental | Backend JWT / Flutter Login | [ ] Concluído |
| **UC-01** | Triagem Neural de Texto | Backend BERTimbau (CPU) / Simulador | [ ] Concluído |
| **UC-10** | Modo Gamer (Limiar 0.70) | Backend `AvaliadorDecisaoRisco` | [ ] Concluído |
| **UC-11** | Detecção de Links Externos | Backend `DetectorDeLinks` | [ ] Concluído |
| **UC-13** | Captura de Contexto (Antes/Depois) | Backend `InMemoryBuffer` | [ ] Concluído |
| **UC-02** | Alerta Crítico em Tempo Real | Backend WebSocket / Flutter Notificações | [ ] Concluído |
| **UC-09** | Gestão do Ciclo de Status | Backend API / Flutter Feed & Detalhe | [ ] Concluído |
| **UC-03** | Calibração de Sensibilidade | Backend API / Flutter Slider (0.50-0.84) | [ ] Concluído |
| **UC-04** | Relatório de Incidente com SHA-256 | Backend ReportLab / Flutter PDF Viewer | [ ] Concluído |
| **UC-17** | Exclusão de Incidente (LGPD) | Backend Cascade Delete / Flutter Modal | [ ] Concluído |

### 6.2. Requisitos Não-Funcionais e Desempenho

| RNF | Descrição | Meta do Projeto | Método de Validação |
| :--- | :--- | :--- | :--- |
| **RNF-11** | Latência de Inferência em CPU | $\le 350\text{ ms}$ (p95) | Medido no campo `inference_time_ms` retornado pela API. |
| **RNF-02** | Tempo de Notificação WebSocket | $\le 2,0\text{ s}$ | Tempo decorrido do clique no simulador até a notificação no celular. |
| **RNF-06** | Segurança de Senhas | Hash forte Argon2id | Verificação no repositório de autenticação. |
| **RNF-07** | Cadeia de Custódia SHA-256 | Validação ponta a ponta | Teste pericial no relatório PDF. |
| **RNF-08** | Privacidade / Não Retenção | Descarte de msgs seguras | Banco armazena apenas contadores agregados para textos seguros. |

### 6.3. Roteiro Sugerido para Apresentação da Banca Examinadora (10 Minutos)

1. **Introdução Teórica (2 min):**
   - Apresentar a arquitetura em camadas e Clean Architecture adotada no projeto.
   - Explicar o modelo BERTimbau fine-tuned (`GuilhermeLA/modelo-tcc-final`) operando sob inferência exclusiva em CPU.
   - Enfatizar a proposta de controle parental sem vigilância abusiva: apenas o que é nocivo gera alerta; mensagens inofensivas não são armazenadas.
2. **Demonstração Prática do Simulador (3 min):**
   - Enviar mensagem segura: apontar o selo verde no simulador e demonstrar que o contador de mensagens seguras é incrementado sem gerar incidente no banco.
   - Enviar mensagem de jogo em sala classificada como `jogo`: demonstrar a atuação do Modo Gamer (limiar elevado automaticamente para 0.70 prevenindo falsos alarmes com gírias e rivalidades de partidas).
   - Enviar link malicioso: demonstrar a interceptação determinística pelo `DetectorDeLinks` (expressão regular linear).
3. **Demonstração do Alerta Crítico e Mobile App (3 min):**
   - Enviar mensagem de ciberbullying explícito com confiança severa ($P \ge 0.85$).
   - Exibir o smartphone Android recebendo instantaneamente a notificação sonora/vibração do sistema.
   - Abrir o aplicativo Flutter, navegar pelo balão do incidente principal, contexto conversacional prévio e posterior, e timeline.
   - Executar a transição de status para *"Conversei com meu filho"* registrando nota de acompanhamento.
4. **Auditoria e Encerramento (2 min):**
   - Exportar o relatório pericial em PDF exibindo a cadeia de integridade com o SHA-256 conferindo perfeitamente com o calculado na Web Crypto API do simulador.
   - Demonstrar o painel de calibração de sensibilidade com slider limitado de $0.50$ a $0.84$.
   - Demonstrar a exclusão definitiva em cascata por guardião primário em conformidade estrita com a LGPD.

---

## 7. Decisões Arquiteturais e Critérios de Qualidade (Gates)

1. **Lazy Loading de IA (Virtual Proxy):**
   - O carregamento dos pesos neurais é adiado até a primeira requisição real.
   - Em ambiente de testes (`APP_ENV=testing`), o factory retorna `MockClassificadorFactory`, permitindo que os testes rodem em $< 5$ s sem consumir 440 MB de memória de pesos reais.
2. **Desacoplamento por Mocks no Frontend:**
   - O aplicativo móvel Flutter implementa interfaces de serviço abstratas, permitindo que 100% da interface de usuário e fluxos de navegação sejam construídos e validados visualmente antes da conexão com o backend.
3. **Criptografia na Origem (Web Crypto API):**
   - O cálculo do hash SHA-256 ocorre no navegador antes de qualquer transmissão via rede, simulando a assinatura de evidência que seria gerada pelo agente do dispositivo do menor.
4. **Integridade da Branch Git:**
   - Todo o desenvolvimento deve ocorrer em branch nova de desenvolvimento (sem commits na branch principal ou merges desautorizados), cabendo ao usuário a revisão final.
5. **Critério Estrito de Pronto (Definition of Done) Global:**
   - Backend: `APP_ENV=testing pytest` 100% verde com BVA completo.
   - Frontend: `flutter analyze` sem erros, `flutter test` 100% verde e build APK de depuração executado com sucesso.
   - Simulador: Cálculo SHA-256 no browser idêntico ao utilitário de CLI.
   - Integração: `docker compose up` operacional e fluxo E2E $\le 2$ s.
