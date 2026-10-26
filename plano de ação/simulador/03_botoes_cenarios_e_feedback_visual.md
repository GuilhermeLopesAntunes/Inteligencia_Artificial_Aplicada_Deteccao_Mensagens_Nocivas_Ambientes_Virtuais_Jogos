# Simulador - Etapa 3: Botões de Cenários Rápidos e Feedback Visual

> **Objetivo:** Implementar botões de injeção rápida de mensagens para demonstração de bancada do TCC e renderização gráfica dos resultados de classificação da IA.

---

## 1. Arquivos a Criar/Atualizar
- `simulator/index.html`
- `simulator/app.js`
- `simulator/style.css`

---

## 2. Detalhamento dos Componentes

### 2.1. Botões de Ação Rápida (Presets de Demonstração)
* Localizados no painel inferior do simulador:
  1. 🟢 **"Mensagem Segura"**: *"Bora jogar de novo hoje à noite?"*
  2. 🟡 **"Trash Talk Moderado (Jogo)"**: *"Você joga muito mal, sai do time!"* (Mostra a atuação do Modo Gamer: em conversa seria incidente, em jogo é absorvido).
  3. 🔴 **"Ciberbullying Crítico"**: *"Você é um inútil, ninguém gosta de você, suma daqui!"* (Aciona alerta crítico imediato e WebSocket).
  4. 🟣 **"Link Suspeito"**: *"Ganhe moedas grátis acessando https://recompensas-jogos.com/promo"* (Aciona heurística do Detector de Links).
  5. ⚠️ **"Mensagem Corrompida (Integridade)"**: Dispara uma mensagem com hash propositalmente adulterado para demonstrar o teste de integridade probatória.

### 2.2. Feedback Visual e Painel de Auditoria no Balão
* Cada mensagem inserida no feed exibe um rodapé técnico contendo:
  * **Selo de Severidade:**
    * 🔴 `ALERT_PARENT_CRITICAL`: Fundo vermelho com ícone de sirene.
    * 🟡 `LOG_INCIDENT`: Fundo amarelo com ícone de alerta.
    * 🟢 `NONE`: Fundo verde/cinza com ícone de segurança.
  * **Métricas do Modelo:**
    * Confiança $P(\text{nocivo})$ em porcentagem (ex: `93.4%`).
    * Tempo de Inferência: `142ms`.
    * Papel Detectado: `VITIMA`, `EMISSOR` ou `ESPECTADOR`.
    * Indicador de Hash: `SHA-256 Verificado ✅` ou `Hash Divergente ❌`.

---

## 3. Critérios de Aceitação da Etapa
- [ ] Os botões de atalho preenchem e enviam a mensagem com apenas um clique.
- [ ] O rodapé de auditoria renderiza as métricas e o selo de cor correspondente à resposta da API.
