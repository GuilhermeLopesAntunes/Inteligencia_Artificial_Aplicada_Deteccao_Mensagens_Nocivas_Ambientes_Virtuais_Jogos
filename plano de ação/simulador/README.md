# Plano de Ação: Simulador de Chat Web (HTML5 / CSS3 / Vanilla JS)

> **Módulo:** Simulador Web de Conversas em Jogos e Chats  
> **Independência:** Totalmente desacoplado do Flutter e com suporte a modo offline / mock local para testes de interface.

---

## 1. Visão Geral do Módulo
O Simulador de Chat é a aplicação web que emula as mensagens trocadas por menores em ambientes de jogos eletrônicos e redes sociais. Ele substitui a captura direta no dispositivo do menor (escopo de trabalho futuro) e atua como a origem de dados primária do Project Artemis.

### Diretrizes de Implementação:
* **HTML5, CSS3 e JavaScript puros** (sem bundlers, npm, webpack ou frameworks).
* Servido via contêiner estático Nginx na porta `3000` (`http://localhost:3000`).
* Cálculo criptográfico de hash **SHA-256 no navegador do cliente** utilizando a **Web Crypto API** (`crypto.subtle.digest`).
* Suporte a mensagens pré-configuradas para demonstrações rápidas no TCC.

---

## 2. Roteiro Passo a Passo de Implementação

### 📄 [Etapa 1: Layout e Interface do Chat](01_layout_e_interface_chat.md)
* Painel lateral de configurações:
  * Seletor de Dependente monitorado (`Lucas` - `dep-001`, `Ana` - `dep-002`).
  * Seletor de Tipo de Sala: `jogo` (Modo Gamer) vs `conversa` (Chat Comum).
  * Gerador de `conversation_id` com botão "Nova Conversa".
  * Alternador de Remetente: "O menor" (`is_from_minor: true`) vs "Outro jogador" (`is_from_minor: false`).
  * Alternador de Destinatário: "Mensagem Direta" (`is_direct: true`) vs "No Grupo" (`is_direct: false`).
* Janela principal de chat:
  * Feed de mensagens em formato de balões bilaterais.
  * Campo de digitação de texto com envio por Enter ou clique.

### 📄 [Etapa 2: Criptografia Web Crypto API e Formato do Payload](02_criptografia_webcrypto_e_payload.md)
* Implementação da função assíncrona `sha256Hex(text)` usando `crypto.subtle.digest`.
* Formatação do payload oficial para `POST /api/v1/predict`:
  * `text` (texto original sem alterações), `message_hash` (hexadecimal minúsculo de 64 caracteres), `dependent_id` e `context_metadata`.
* Modo Mock local em JavaScript para testar o envio sem necessidade de backend ativo.

### 📄 [Etapa 3: Botões de Cenários Rápidos e Feedback Visual](03_botoes_cenarios_e_feedback_visual.md)
* Barra de botões de teste rápido com frases típicas:
  1. *Mensagem Neutra / Segura* (ex: "Bora jogar outra partida amanhã?").
  2. *Ofensa Leve / Trash Talk de Jogo* (ex: "Você joga muito mal, sai do time").
  3. *Ofensa Crítica / Ciberbullying Explícito* (ex: "Você é um inútil, ninguém gosta de você").
  4. *Tentativa de Phishing / Link Suspeito* (ex: "Ganhe skins grátis em https://jogosgratis.xyz").
* Feedback visual em tempo real após a análise:
  * Badges coloridos no balão da mensagem: **Vermelho** (`ALERT_PARENT_CRITICAL`), **Amarelo** (`LOG_INCIDENT`), **Verde/Cinza** (`SEGURO`).
  * Exibição de probabilidade $P$, tempo de inferência em milissegundos e status da integridade SHA-256.

---

## 3. Critérios de Pronto (Definition of Done) do Simulador
- [ ] Execução estática funcional acessando `http://localhost:3000`.
- [ ] O hash SHA-256 gerado no navegador é idêntico ao cálculo SHA-256 padrão de ferramentas de linha de comando.
- [ ] Botões rápidos preenchem e enviam dados com 1 clique para facilidade de demonstração.
