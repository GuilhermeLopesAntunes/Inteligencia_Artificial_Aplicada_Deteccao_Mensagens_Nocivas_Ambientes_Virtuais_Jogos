# Simulador - Etapa 1: Layout e Interface do Chat

> **Objetivo:** Desenvolver a interface HTML5 e CSS3 pura do simulador web, com área de controles de simulação e feed de mensagens em estilo de mensageiro instantâneo.

---

## 1. Arquivos a Criar/Atualizar
- `simulator/index.html`
- `simulator/style.css`
- `simulator/config.js`
- `simulator/Dockerfile`

---

## 2. Detalhamento dos Componentes

### 2.1. Estrutura do Layout (`simulator/index.html`)
* **Painel Superior / Barra de Ferramentas:**
  * Identificação do simulador: *"Project Artemis — Simulador de Interações Virtuais"*.
* **Área Lateral de Controles (Sidebar):**
  * `select#dependent_select`: Lucas (`dep-001`), Ana (`dep-002`).
  * `select#room_type_select`: `jogo` (Modo Gamer) e `conversa` (Chat Comum).
  * `input#conversation_id`: ID da conversa atual (ex: `conv-game-88`) com botão "Nova Conversa" (gera `conv-<timestamp>`).
  * `input#sender_id`: ID/Nome do remetente (ex: `adversario-09` ou `lucas_gamer`).
  * `checkbox#is_from_minor`: "Mensagem enviada pelo menor monitorado".
  * `checkbox#is_direct`: "Mensagem enviada em privado (Direct/DM)".
* **Área Central de Chat:**
  * `#chat_feed`: Contêiner com rolagem automática para as mensagens.
  * `#input_area`: `textarea#message_input` e `button#send_button`.

### 2.2. Estilização (`simulator/style.css`)
* Design moderno e responsivo com tema escuro (Dark Mode) inspirado em interfaces de jogos (Discord / Steam).
* Diferenciação visual clara entre balões:
  * Mensagens do menor (alinhadas à direita, tom azul escuro).
  * Mensagens de outros usuários (alinhadas à esquerda, tom cinza/grafite).
  * Painel de auditoria fixado ao lado ou abaixo de cada balão.

---

## 3. Critérios de Aceitação da Etapa
- [ ] Interface carrega perfeitamente em qualquer navegador moderno.
- [ ] A troca de configurações (dependente, sala, remetente) reflete imediatamente nos estados JavaScript.
- [ ] Layout fluido com rolagem automática a cada nova mensagem.
