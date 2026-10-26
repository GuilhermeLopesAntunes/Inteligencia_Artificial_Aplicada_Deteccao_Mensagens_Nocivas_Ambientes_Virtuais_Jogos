
# Especificação Textual de Casos de Uso: Project Artemis

> **Sistema de Controle Parental Inteligente com Detecção de Ciberbullying via BERTimbau**  
> **Metodologia:** Casos de Uso Estruturados (Alistair Cockburn)  
> **Documento de Origem:** `requisitos.md`

---

## Sumário e Priorização dos Casos de Uso

| ID | Nome do Caso de Uso | Ator Principal | Prioridade (TCC) | Requisitos |
| :--- | :--- | :--- | :--- | :--- |
| **UC-18** | Autenticar Responsável | Responsável Legal | **Essencial** | RF-17, RNF-06 |
| **UC-01** | Analisar e Classificar Mensagens do Simulador | Simulador de Chat | **Essencial** | RF-01, RF-02, RF-03 |
| **UC-10** | Normalizar Texto para Inferência | Sistema Artemis | **Essencial** | RF-01 |
| **UC-11** | Detectar Links Externos (`DetectorDeLinks`) | Sistema Artemis | **Essencial** | RF-01 |
| **UC-13** | Aplicar Recalibração de Modo Gamer | Sistema Artemis | **Essencial** | RF-06 |
| **UC-02** | Notificar Responsável sobre Incidente Crítico | Sistema Artemis (WebSocket) | **Essencial** | RF-04, RNF-02 |
| **UC-09** | Gerenciar Status de Resolução de Incidente | Responsável Legal | **Essencial** | RF-13 |
| **UC-03** | Calibrar Limiar Comum de Sensibilidade | Responsável Legal Primário | **Essencial** | RF-05 |
| **UC-04** | Exportar Relatório de Incidente com SHA-256 | Responsável Legal | **Essencial** | RF-07, RNF-07 |
| **UC-17** | Excluir Incidente e Dados Associados (LGPD) | Responsável Legal Primário | **Essencial** | RF-18, RNF-08 |
| **UC-06** | Vincular Múltiplos Responsáveis (Código de Convite) | Responsável Legal Primário | Se sobrar tempo | RF-13 |
| **UC-12** | Escalonar Alerta Crítico para Responsáveis Vinculados| Sistema Artemis | Se sobrar tempo | RF-09 |
| **UC-07** | Fornecer Feedback de Falso Positivo da IA | Responsável Legal | Se sobrar tempo | RF-14 |
| **UC-08** | Consultar Orientações de Diálogo (CNV) e Glossário | Responsável Legal | Se sobrar tempo | RF-11, RF-12 |
| **UC-14** | Visualizar Painel Analítico de Tendências | Responsável Legal | Trabalho Futuro | RF-10 |
| **UC-15** | Ativar Modo de Acessibilidade | Responsável Legal | Trabalho Futuro | RF-15, RNF-09 |
| **UC-16** | Gerar Sumário Executivo Mensal de Segurança | Responsável Legal | Trabalho Futuro | RF-16 |
| **UC-05** | *(Removido - Modo Plantão)* | — | *Removido* | — |

---

# [UC-18] Autenticar Responsável

- **Ator Principal:** Responsável Legal
- **Pré-condições:** Usuário cadastrado no sistema (via *seed* inicial para primário ou código de convite para secundário).
- **Pós-condições:** Token de sessão JWT emitido para autenticação nas rotas protegidas da API e no canal WebSocket.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Legal** informa seu e-mail e senha no formulário de login do App Flutter.
2. O **Sistema** valida as credenciais contra o hash seguro (Argon2id/bcrypt) no banco de dados.
3. O **Sistema** gera e retorna um token de acesso JWT assinado.
4. O **App Flutter** armazena o token de forma segura e redireciona o usuário para o feed principal de incidentes.

## 🟡 Fluxos de Extensão e Tratamento de Exceções
- **2a. Credenciais inválidas:**
  1. O Sistema retorna erro HTTP 401 Unauthorized.
  2. O App Flutter exibe mensagem "E-mail ou senha incorretos".

---

# [UC-01] Analisar e Classificar Mensagens do Simulador

- **Ator Principal:** Simulador de Chat Web (`simulator/`)
- **Partes Interessadas e Interesses:**
  - *Responsáveis Legais:* Receber alertas precisos sobre ciberbullying e links suspeitos sem sobrecarga de falsos alarmes.
  - *Sistema Artemis:* Executar inferência ágil em CPU e preservar integridade dos dados contextuais.
- **Pré-condições:** O simulador Web está em execução, dependente selecionado (`dependent_id`) e hash SHA-256 computado no navegador via Web Crypto API.
- **Pós-condições de Sucesso:** Mensagem processada pelo BERTimbau e `DetectorDeLinks`, papel do menor derivado, e persistência condicional realizada apenas para incidentes.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Simulador de Chat** calcula o hash SHA-256 da mensagem via `crypto.subtle.digest` no navegador.
2. O **Simulador de Chat** envia requisição `POST /api/v1/predict` com texto, hash, `dependent_id` e metadados contextuais.
3. O **Sistema** executa a normalização textual (`UC-10`) e aplica o `DetectorDeLinks` (`UC-11`), obtendo o sinal booleano `has_link`.
4. O **Sistema** submete o texto normalizado ao modelo **BERTimbau Binário** em CPU, obtendo a probabilidade $P(\text{nocivo})$.
5. O **Sistema** recupera o limiar comum calibrado do dependente ($L$) e avalia se o Modo Gamer está ativo (`UC-13`), ajustando $L = \max(\text{limiar}, 0.70)$ se for sala de jogo.
6. O **Sistema** aplica a tabela de decisão:
   - **Se $P \ge 0.85$:** Categoria = `CIBERBULLYING`, Ação = `ALERT_PARENT_CRITICAL` (Incidente Crítico).
   - **Se $L \le P < 0.85$:** Categoria = `CIBERBULLYING`, Ação = `LOG_INCIDENT` (Incidente Comum).
   - **Se $P < L$ e `has_link = true`:** Categoria = `LINK_SUSPEITO`, Ação = `LOG_INCIDENT` (Incidente Comum).
   - **Se $P < L$ e `has_link = false`:** Categoria = `SEGURO`, Ação = `NONE` (Mensagem Segura).
7. Se for Incidente (Crítico ou Comum):
   - O Sistema copia as 3 mensagens anteriores do buffer circular em memória.
   - O Sistema grava o novo `Incidente` no banco SQLite e o registra na lista em memória de "incidentes abertos para contexto".
8. Se for Incidente Crítico, o Sistema aciona imediatamente o `UC-02` (Notificar Responsável via WebSocket).
9. O **Sistema** responde ao cliente HTTP com o payload oficial de resposta.

## 🟡 Fluxos de Extensão e Tratamento de Exceções
- **6a. Mensagem classificada como Segura ($P < L$ e sem links):**
  1. O Sistema atualiza o buffer circular da conversa e não persiste o texto. A mensagem permanece apenas no buffer circular em memória (últimas 3, regra 7), que nunca vai a disco e se perde ao reiniciar.
  2. O Sistema atualiza apenas o contador agregado e finaliza o caso de uso.
- **7a. Chegada de mensagem posterior para incidente aberto na mesma conversa:**
  1. O Sistema identifica se há incidentes criados nos últimos 10 minutos naquela conversa que ainda tenham menos de 3 mensagens posteriores anexadas.
  2. O Sistema anexa a mensagem atual ao registro de contexto posterior do incidente no banco de dados.
- **2a. Hash SHA-256 divergente (`sha256_match = false`):**
  1. O Sistema processa o texto normalmente.
  2. Se virar incidente, registra o campo `integridade_divergente = true` no banco para constar no relatório.

---

# [UC-02] Notificar Responsável sobre Incidente Crítico

- **Ator Principal:** Sistema Artemis (WebSocket Gateway)
- **Pré-condições:** Incidente com $P(\text{nocivo}) \ge 0.85$ confirmado pelo `UC-01`.
- **Pós-condições:** Mensagem WebSocket despachada e recebida pelo App Flutter (com o app aberto), exibindo alerta sonoro e notificação local.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Sistema** despacha o evento de notificação em tempo real via WebSocket para as conexões ativas do **responsável primário** do dependente (`incident.critical`); os demais recebem apenas `incident.created`, sem som (regra 10).
2. O **App Flutter** recebe o evento, exibe aviso visual na tela e dispara notificação local com som prioritário.
3. O **Responsável Legal** abre o alerta no app.
4. O **Sistema** atualiza o status do incidente para `VISUALIZADO`.

## 🟡 Fluxos de Extensão e Tratamento de Exceções
- **3a. Responsável primário não visualiza o alerta em até 15 minutos:**
  1. O Sistema executa o escalonamento interno (`UC-12`), disparando notificação interna aos demais guardiões vinculados.

---

# [UC-03] Calibrar Limiar Comum de Sensibilidade

- **Ator Principal:** Responsável Legal Primário
- **Pré-condições:** Responsável Primário autenticado no app.
- **Pós-condições:** Novo valor de `limiarComum` salvo no registro do `Dependente`.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Primário** acessa as Configurações de Monitoramento do dependente.
2. O **Sistema** exibe o slider de calibração na faixa permitida ($0.50$ a $0.84$).
3. O **Responsável Primário** ajusta o valor (ex: $0.65$) e confirma.
4. O **Sistema** valida e grava o novo limiar comum no banco de dados.

---

# [UC-04] Exportar Relatório de Incidente com SHA-256

- **Ator Principal:** Responsável Legal
- **Pré-condições:** Incidente persistido no banco de dados.
- **Pós-condições:** Arquivo PDF do relatório gerado com conferência de hash SHA-256.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Legal** solicita "Exportar Relatório PDF" na tela de detalhes do incidente.
2. O **Backend** compila os dados contextuais, timestamps UTC, texto original e o hash SHA-256 recebido da origem.
3. O **Backend** valida o hash localmente e atesta a correspondência no documento.
4. O **Backend** renderiza o arquivo PDF e o App Flutter realiza o download local.

---

# [UC-06] Vincular Múltiplos Responsáveis (Código de Convite)

- **Ator Principal:** Responsável Legal Primário
- **Pré-condições:** Responsável Primário autenticado.
- **Pós-condições:** Código alfanumérico de convite gerado com validade de 48 horas.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Primário** solicita "Adicionar Guardião" no perfil do dependente.
2. O **Sistema** gera um código de convite temporário (48h) exibido na tela.
3. O **Novo Responsável** realiza cadastro no app informando esse código de convite.
4. O **Sistema** valida o código e vincula o novo guardião como responsável secundário do dependente.

---

# [UC-07] Fornecer Feedback de Falso Positivo da IA

- **Ator Principal:** Responsável Legal
- **Pré-condições:** Incidente visualizado no app.
- **Pós-condições:** Feedback de predição incorreta gravado e status alterado para `FALSO_POSITIVO`.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Legal** identifica uma detecção inadequada e clica em "Marcar como Falso Positivo".
2. O **Responsável Legal** insere uma justificativa opcional e confirma.
3. O **Sistema** atualiza o status do incidente para `FALSO_POSITIVO` e armazena o registro para futuro retreino.

---

# [UC-08] Consultar Orientações de Diálogo (CNV) e Glossário

- **Ator Principal:** Responsável Legal
- **Pré-condições:** Incidente aberto ou aba de ajuda acessada.
- **Pós-condições:** Conteúdo pedagógico e glossário consultados.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Legal** visualiza o card pedagógico sugerindo diálogo baseado em CNV adaptado ao papel (`VITIMA` ou `EMISSOR`).
2. O **Responsável Legal** pode consultar o glossário estático para entender gírias digitais.

---

# [UC-09] Gerenciar Status de Resolução de Incidente

- **Ator Principal:** Responsável Legal
- **Pré-condições:** Incidente existente no banco de dados.
- **Pós-condições:** Status atualizado conforme as regras de transição válidas.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Legal** acessa o incidente em andamento.
2. O **Sistema** disponibiliza apenas as transições manuais permitidas:
   - De `VISUALIZADO` $\rightarrow$ `EM_ANALISE` ou `FALSO_POSITIVO`.
   - De `EM_ANALISE` $\rightarrow$ `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO` ou `RESOLVIDO`.
   - De `CONVERSADO_COM_FILHO` ou `ENCAMINHADO_A_ESCOLA` $\rightarrow$ `RESOLVIDO`.
3. O **Responsável Legal** seleciona o novo estado e confirma.
4. O **Sistema** atualiza o registro no banco de dados.

---

# [UC-10] Normalizar Texto para Inferência

- **Ator Principal:** Sistema Artemis
- **Pré-condições:** Texto bruto recebido via API.
- **Pós-condições:** Espaços higienizados e truncamento seguro realizado pelo tokenizer (`max_length=512`).

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Sistema** remove espaços redundantes e normaliza quebras de linha.
2. O **Sistema** delega ao tokenizer WordPiece a aplicação de `truncation=True, max_length=512`.
3. O **Sistema** entrega o texto preservando emojis e stopwords intactos para a inferência.

---

# [UC-11] Detectar Links Externos (`DetectorDeLinks`)

- **Ator Principal:** Sistema Artemis
- **Pré-condições:** Mensagem em análise.
- **Pós-condições:** Retorno booleano `has_link = true/false`.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Sistema** avalia a mensagem através do componente `DetectorDeLinks` usando regex para URLs (`http://`, `https://`, `www.`).
2. Se qualquer link for encontrado, retorna `has_link = true`; caso contrário, `false`.

---

# [UC-12] Escalonar Alerta Crítico para Responsáveis Vinculados

- **Ator Principal:** Sistema Artemis (Escalonamento Scheduler)
- **Pré-condições:** Incidente crítico ($P \ge 0.85$) com status `DETECTADO` há mais de 15 minutos.
- **Pós-condições:** Notificação interna WebSocket emitida aos demais responsáveis vinculados.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Sistema** localiza incidentes críticos pendentes de visualização há mais de 15 minutos.
2. O **Sistema** envia notificação WebSocket para os guardiões secundários vinculados ao dependente e marca `escalonado = true`.

---

# [UC-13] Aplicar Recalibração de Modo Gamer

- **Ator Principal:** Sistema Artemis
- **Pré-condições:** Mensagem recebida com metadado `room_type: "jogo"`.
- **Pós-condições:** Limiar comum ajustado para $\max(\text{limiar\_calibrado}, 0.70)$.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Sistema** identifica o contexto gamer na sala.
2. O **Sistema** eleva o limiar comum para 0.70 (ou mantém o valor calibrado se este for superior), tolerando jargões competitivos lúdicos.

---

# [UC-17] Excluir Incidente e Dados Associados (LGPD)

- **Ator Principal:** Responsável Legal Primário
- **Pré-condições:** Responsável Primário autenticado no app.
- **Pós-condições:** Incidente, mensagens de contexto e feedbacks excluídos permanentemente do banco de dados.

## 🟢 Fluxo Principal de Sucesso (Happy Path)
1. O **Responsável Primário** seleciona a opção "Excluir Incidente Permanentemente".
2. O **Sistema** exibe modal de confirmação explícita alertando sobre a perda irreversível da evidência.
3. O **Responsável Primário** confirma a operação.
4. O **Sistema** remove o registro do banco de dados (exclusão real) e finaliza o caso de uso.
