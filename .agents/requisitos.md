
# Especificação e Levantamento de Requisitos: Project Artemis

> **Sistema de Controle Parental Inteligente com Detecção de Ciberbullying via BERTimbau**  
> **Modelo Neural Exclusivo:** BERTimbau Binário (`normal` / `nocivo`) + Detector de Links Externos (`DetectorDeLinks`)  
> **Ambiente de Entrada:** Simulador de Chat Web (`simulator/`, HTML/JS)

---

# 1. Diagnóstico e Auditoria de Requisitos

### Anti-patterns e Refatorações Técnicas Padronizadas
| Requisito Bruto Original | Problema Identificado (Anti-pattern) | Correção e Padronização Técnica |
| :--- | :--- | :--- |
| *"O app deve ser rápido na análise das mensagens"* | RNF vago sem métrica objetiva para o MVP | Definida latência de notificação no app de $\le$ 2,0s (p99) para incidentes críticos via WebSocket e meta de inferência em CPU p95 $\le$ 350ms (RNF-11); métricas de GPU (p95 $\le$ 250ms) movidas para trabalho futuro. |
| *"Usar banco de dados criptografado e seguro"* | Decisão de design genérica e sem métrica de conformidade | Definido hash seguro de senhas (Argon2id/bcrypt), proteção de rotas com JWT e SHA-256 calculado na origem (simulador) para integridade probatória. |
| *"Layout fácil para idosos e pais leigos"* | RNF subjetivo e não auditável | Aderência à norma WCAG 2.1 Nível AA, tipografia escalável e razão de contraste $\ge$ 4.5:1. |
| *"Bloquear ciberbullying e assédio sem errar"* | RF ambíguo ignorando matriz de confusão do modelo | Modelo binário com calibração de limiar comum (0.50–0.84, crítico fixo em 0.85) e apresentação na UI como "possível ciberbullying" devido aos falsos positivos (~46%). |
| *"Os pais podem compartilhar a conta com aprovação unânime"* | Risco de deadlock em guarda conflituosa | Modelo de co-parentalidade onde o **Responsável Primário** detém autoridade para configurações, limiares e exclusão de dados. |
| *"Gravar tudo em log imutável permanente WORM"* | Violação do direito de eliminação (LGPD Art. 14) | Gravação restrita apenas a mensagens que constituam incidentes e suporte à **exclusão real** de dados pelo responsável primário. |

---

# 2. Especificação Padronizada de Requisitos (Hierarquia Sommerville)

## 2.1. Requisitos de Usuário (RU) vs. Requisitos de Sistema (RS)

### RU-01: Detecção Inteligente de Ciberbullying e Links Suspeitos
- **Descrição (Negócio):** O responsável deve receber alertas sobre mensagens com teor de ciberbullying, ofensas verbais ou links suspeitos de aliciamento geradas no simulador de chat.
- **Desdobramento em Requisitos de Sistema:**
  - **RS-01.1:** O backend de inferência deve processar o texto via modelo **BERTimbau Binário** em CPU, retornando a probabilidade normalizada $P(\text{nocivo})$ e aplicando o componente `DetectorDeLinks`, classificando em: `SEGURO`, `CIBERBULLYING` e `LINK_SUSPEITO`.
  - **RS-01.2:** O sistema deve manter em memória um buffer circular das últimas 3 mensagens da conversa para fornecer contexto temporal anterior e anexar até 3 mensagens posteriores caso um incidente seja confirmado (janela de até 10 minutos).
  - **RS-01.3:** Mensagens classificadas como `SEGURO` não devem ser gravadas em disco, retendo-se apenas contadores quantitativos agregados para auditoria.

### RU-02: Gestão de Notificações em Tempo Real no App
- **Descrição (Negócio):** O responsável deve receber avisos imediatos no aplicativo quando houver mensagens com alta probabilidade de dano.
- **Desdobramento em Requisitos de Sistema:**
  - **RS-02.1:** Para incidentes com gravidade `Crítica` ($P(\text{nocivo}) \ge 0.85$), o sistema deve emitir notificação em tempo real no app Flutter via WebSocket em até 2,0 segundos (com o app aberto).
  - **RS-02.2:** Para incidentes com gravidade `Comum` ($L \le P(\text{nocivo}) < 0.85$ ou `LINK_SUSPEITO`), o sistema deve registrar o incidente no feed do app sem emitir alerta sonoro imediato.
  - **RS-02.3 (se sobrar tempo, UC-12):** Se um alerta crítico não for visualizado pelo responsável em até 15 minutos, o sistema deve disparar notificação interna via WebSocket para os demais responsáveis vinculados à conta.

### RU-03: Relatório de Incidente com Integridade Criptográfica
- **Descrição (Negócio):** O responsável deve poder exportar um relatório do incidente para apresentar à escola, conselho tutelar ou autoridades competentes.
- **Desdobramento em Requisitos de Sistema:**
  - **RS-03.1:** O sistema deve gerar um documento PDF contendo o texto do incidente, metadados contextuais, timestamp UTC e o hash SHA-256 (calculado na origem pelo simulador e conferido no backend).
  - **RS-03.2:** A tabela de incidentes deve permitir auditoria e conferência do hash probatório para assegurar que a mensagem não sofreu adulteração após a captura.

### RU-04: Apoio Pedagógico e Tradução de Contexto
- **Descrição (Negócio):** O responsável deve compreender o contexto das agressões e receber orientações de diálogo acolhedor com o filho.
- **Desdobramento em Requisitos de Sistema:**
  - **RS-04.1:** O sistema deve exibir cards de mediação parental baseados em Comunicação Não-Violenta (CNV), adaptados conforme o papel do menor (`VITIMA` ou `EMISSOR`).
  - **RS-04.2:** O sistema deve fornecer um glossário com explicações simples para gírias comuns de internet.

### RU-05: Co-Parentalidade e Gestão Multiguardião
- **Descrição (Negócio):** Múltiplos responsáveis legais devem poder acompanhar o menor com sincronização de status de resolução.
- **Desdobramento em Requisitos de Sistema:**
  - **RS-05.1:** A gestão de incidentes deve operar com o seguinte conjunto oficial de status: `DETECTADO`, `VISUALIZADO`, `EM_ANALISE`, `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO` e `RESOLVIDO`.
  - **RS-05.2:** O responsável primário tem autoridade exclusiva para alterar limiares, gerenciar vínculos de co-parentalidade via código de convite e executar a exclusão definitiva de registros (LGPD).

---

# 📋 3. Matriz de Requisitos Funcionais (RF)

| ID | Nome / Funcionalidade | Descrição Operacional | Prioridade |
| :--- | :--- | :--- | :--- |
| **RF-01** | Inferência NLP com BERTimbau Binário | Processar o texto via BERTimbau em CPU ($P(\text{nocivo})$) e `DetectorDeLinks`, classificando em `SEGURO`, `CIBERBULLYING` ou `LINK_SUSPEITO`. | Must Have |
| **RF-02** | Extração de Janela de Contexto | Manter buffer em memória das 3 mensagens anteriores e capturar até 3 posteriores para anexar ao incidente confirmado. | Must Have |
| **RF-03** | Classificação de Papel do Menor | Determinar via metadados do simulador se o menor foi `VITIMA` (recebeu diretamente), `EMISSOR` (enviou) ou `ESPECTADOR` (grupo). | Must Have |
| **RF-04** | Notificação em Tempo Real no App | Emitir alerta visual/sonoro no App Flutter via WebSocket em $\le 2\text{s}$ para incidentes críticos ($P(\text{nocivo}) \ge 0.85$). | Must Have |
| **RF-05** | Calibração de Limiares | Permitir que o responsável primário calibre o limiar comum do dependente entre $0.50$ e $0.84$ (crítico fixo em $0.85$). | Should Have |
| **RF-06** | Modo Gamer (Tolerância a Jogos) | Em salas do simulador marcadas como "jogo", o limiar comum efetivo passa a ser $L = \max(\text{limiar\_calibrado}, 0.70)$ (crítico mantido em $0.85$). | Should Have |
| **RF-07** | Relatório de Incidente com SHA-256 | Exportar relatório PDF com o texto, metadados, timestamp e verificação do hash SHA-256 gerado pelo simulador. | Should Have |
| **RF-09** | Escalonamento Interno (15 min) | Se o alerta crítico não for visualizado em 15 min, notificar os demais responsáveis vinculados no app via WebSocket. | Should Have |
| **RF-10** | Painel Analítico de Tendências | Exibir gráficos de volume de incidentes, evolução temporal e distribuição de papéis (vítima/emissor). | Could Have (Trab. Futuro) |
| **RF-11** | Glossário de Gírias da Web | Fornecer listagem consultável com significado de termos e gírias digitais. | Could Have |
| **RF-12** | Cartões Pedagógicos (CNV) | Exibir recomendações de abordagem construtiva na tela de detalhes do incidente. | Could Have |
| **RF-13** | Gestão de Múltiplos Guardiões | Permitir múltiplos guardiões vinculados via código de convite de 48h com resolução sincronizada. | Should Have |
| **RF-14** | Feedback de Falso Positivo | Permitir que os responsáveis classifiquem incidentes como falsos positivos para base de retreino. | Should Have |
| **RF-15** | Modo de Acessibilidade | Disponibilizar alto contraste, fontes ampliadas e compatibilidade com leitores de tela no Flutter. | Could Have (Trab. Futuro) |
| **RF-16** | Sumário Executivo Mensal | Gerar sumário mensal com total de mensagens processadas e incidentes tratados. | Could Have (Trab. Futuro) |
| **RF-17** | Autenticação Simples de Responsável | Login com e-mail e senha, emissão de tokens JWT e hash de senhas (Argon2id/bcrypt). | Must Have |
| **RF-18** | Exclusão Definitiva de Registros (LGPD)| Permitir que o responsável primário exclua permanentemente o incidente, contexto e feedbacks. | Must Have |

---

# 4. Requisitos Não-Funcionais (RNF) Quantificados

### 4.1. Requisitos do MVP
| ID | Categoria | Descrição do RNF | Métrica e Critério de Aceite |
| :--- | :--- | :--- | :--- |
| **RNF-02** | Latência de Notificação | Entrega de alerta crítico no App Flutter | Entrega via WebSocket em $\le 2,0\text{s}$ (p99) após confirmação de $P(\text{nocivo}) \ge 0.85$ (meta não medida formalmente). |
| **RNF-06** | Segurança e Autenticação | Proteção de credenciais e rotas da API | Senhas com hash forte (Argon2id ou bcrypt) e endpoints protegidos via Bearer JWT. |
| **RNF-07** | Integridade Probatória | Hash SHA-256 calculado na origem | Hash calculado pelo simulador via Web Crypto API e conferido pelo backend FastAPI. |
| **RNF-08** | Privacidade / LGPD (Art. 14) | Proteção de dados e eliminação | Mensagens seguras nunca são gravadas em disco (só o contador agregado e o buffer volátil de 3 mensagens); suporte à exclusão real de incidentes pelo responsável primário. |
| **RNF-09** | Acessibilidade | Padrões visuais do App Flutter | Contraste mínimo 4.5:1 nas telas do MVP. Conformidade completa com WCAG 2.1 AA e modo de acessibilidade (UC-15) são trabalho futuro. |
| **RNF-11** | Desempenho / CPU | Latência de inferência em CPU por mensagem | Meta p95 $\le 350\text{ms}$ em CPU (meta não validada formalmente). |

### 4.2. Requisitos de Produção (Trabalho Futuro)
| ID | Categoria | Descrição do Requisito de Produção |
| :--- | :--- | :--- |
| **RNF-01** | Desempenho GPU | Latência p95 $\le$ 250ms em GPU dedicada NVIDIA com lotes de inferência simultânea. |
| **RNF-03** | Alta Disponibilidade | SLA mensal $\ge$ 99,9% com cluster distribuído e balanceador de carga. |
| **RNF-04** | Eficiência Energética | Consumo de bateria $\le$ 1,5%/dia em agente Android nativo de monitoramento em background. |
| **RNF-05** | Consumo de Dados Móveis | Tráfego $\le$ 15 MB/mês por dependente em redes 4G/5G. |
| **RNF-10** | Alta Escalabilidade | Sustentação de até 1.000 requisições simultâneas de predição com auto-scaling. |

---

# 5. Premissas de Projeto, Limitações e Trabalho Futuro Consolidado

1. **Simulador como Fonte de Dados:** As mensagens são geradas pelo simulador Web em HTML/JS (`simulator/`), onde remetentes e salas são parametrizados para testes e demonstrações.
2. **Modelo Binário e Taxonomia:** O modelo BERTimbau opera com rótulos `normal` e `nocivo`. A taxonomia do MVP é `SEGURO`, `CIBERBULLYING` e `LINK_SUSPEITO`.
3. **Limitações e Esclarecimentos Métricos:**
   - O limiar crítico de $0.85$ é **provisório e não validado** por curva precisão $\times$ revocação.
   - As metas de latência de inferência (RNF-11, p95 $\le$ 350ms) e de notificação (RNF-02, $\le$ 2,0s) são **metas não medidas formalmente**.
   - As métricas citadas do modelo (Acurácia 79,45%, Precisão 53,86%, Revocação 73,92%, F1-Score 62,32%) referem-se estritamente ao limiar padrão de 0,50.
4. **Trabalho Futuro Consolidado:**
   - Captura real de mensagens no dispositivo do menor (Android nativo) e modo offline (SQLCipher).
   - Treinamento de modelo multiclasse (severidade, assédio, grooming, extorsão).
   - Explicabilidade de predições via SHAP ou Integrated Gradients.
   - Conversão semântica de emojis (com retreino do modelo).
   - Push notifications reais (FCM/APNs), alertas com app fechado e contingência via SMS.
   - HTTPS/TLS 1.3, criptografia AES-256 em repouso e autenticação com 2FA.
   - Envio de convites de co-parentalidade por e-mail.
   - Assinatura digital ICP-Brasil e carimbo de tempo auditável.
   - Relato de falsos negativos pelo responsável.
   - Painel analítico (UC-14), modo de acessibilidade (UC-15) e sumário mensal (UC-16).
   - Validação empírica de personas e requisitos com usuários reais em ambiente de produção.
   - Avaliação jurídica (LGPD/ECA) para uso com dados reais de terceiros.
