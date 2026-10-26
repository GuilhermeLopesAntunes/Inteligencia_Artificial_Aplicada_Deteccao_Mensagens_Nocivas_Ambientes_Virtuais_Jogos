# Integração - Etapa 2: Roteiro de Testes End-to-End (E2E)

> **Objetivo:** Estabelecer um roteiro padronizado de validação de fluxo cruzado entre o Simulador Web, o Backend FastAPI e o App Mobile Flutter.

---

## 1. Roteiro Passo a Passo de Teste Integrado

### Cenário 1: Login do Guardião e Conexão em Tempo Real
1. Abrir o App Flutter no emulador Android.
2. Inserir credenciais de teste do seed (`maria@exemplo.com` / `senha123`).
3. Confirmar que o login é realizado com sucesso e o feed inicial é carregado.
4. Verificar no terminal do backend que o cliente conectou no canal WebSocket `/ws?token=<jwt>`.

### Cenário 2: Envio de Mensagem Segura e Atualização de Contador
1. No Simulador (`http://localhost:3000`), selecionar Lucas (`dep-001`) e sala `conversa`.
2. Digitar e enviar: *"Oi, você já terminou a lição de casa?"*.
3. **Resultado Esperado no Simulador:** Selo verde `SEGURO`, ação `NONE`, tempo de inferência $< 350$ms.
4. **Resultado Esperado no App:** Nenhum incidente gerado no feed; contador de mensagens seguras incrementado.

### Cenário 3: Envio de Mensagem em Sala de Jogo (Modo Gamer)
1. No Simulador, alterar o tipo de sala para `jogo`.
2. Enviar: *"Você joga muito mal, sai logo do time"* (probabilidade moderada ~0.62).
3. **Resultado Esperado:** O Modo Gamer eleva o limiar para 0.70; a mensagem é classificada como segura em contexto de jogo sem disparar falso positivo para os pais.

### Cenário 4: Disparo de Ciberbullying Crítico e Notificação Sonora
1. No Simulador, enviar: *"Você é um lixo inútil, ninguém quer você por perto!"* (probabilidade > 0.85).
2. **Resultado Esperado no Backend:**
   - Classificação: `CIBERBULLYING` / `ALERT_PARENT_CRITICAL`.
   - Disparo simultâneo de evento `incident.created` e `incident.critical` no WebSocket.
3. **Resultado Esperado no App:**
   - Notificação local disparada com som e vibração no Android.
   - Novo card vermelho de incidente crítico adicionado ao topo do feed.

### Cenário 5: Recepção de Contexto Posterior
1. Imediatamente após a mensagem crítica, enviar duas mensagens adicionais na mesma conversa no simulador (ex: *"Vai chorar?"* e *"Nem adianta tentar"*).
2. Abrir a tela de detalhes do incidente no App.
3. **Resultado Esperado:** As mensagens posteriores aparecem no balão de contexto conversacional (`context_after`).

### Cenário 6: Transição de Status e Resolução
1. Na tela de detalhes do incidente no App, tocar em "Atualizar Status".
2. Selecionar "Conversei com meu filho" e inserir uma nota explicativa.
3. Confirmar e verificar a atualização na timeline de histórico.
4. Mudar o status para "Incidente resolvido" e verificar o fechamento do ciclo.

---

## 2. Critérios de Aceitação da Etapa
- [ ] Todos os 6 cenários executam do início ao fim sem falhas ou exceções não tratadas.
- [ ] Tempo total entre o clique no Simulador e a notificação sonora no App é $\le 2.0$ segundos.
