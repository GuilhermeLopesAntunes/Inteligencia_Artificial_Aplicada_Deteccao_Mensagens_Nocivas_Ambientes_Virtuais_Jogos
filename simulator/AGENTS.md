# Simulador de Chat

Página web que gera as mensagens analisadas pelo sistema, substituindo a captura real no celular do menor. É uma ferramenta de demonstração: simples e clara vale mais que bonita.

## Restrições

- **HTML, CSS e JavaScript puros.** Sem frameworks, sem npm, sem bundler, sem etapa de build. Os arquivos são servidos como estão pelo Nginx.
- Bibliotecas externas: nenhuma. `fetch` e `crypto.subtle` bastam.
- Nada de `localStorage` ou persistência: o estado vive em memória e some ao recarregar a página.

## Arquivos

```
simulator/
├── Dockerfile    # nginx:alpine copiando os arquivos para /usr/share/nginx/html
├── index.html
├── style.css
├── config.js     # URL da API e dependentes do seed
└── app.js
```

`config.js`:

```js
const CONFIG = {
  API_URL: "http://localhost:8000/api/v1/predict",
  DEPENDENTS: [
    { id: "dep-001", name: "Lucas" },
    { id: "dep-002", name: "Ana" },
  ],
};
```

Os IDs devem ser os mesmos do seed do backend (ver `../.agents/contrato-api.md`).

## Interface

Controles:
- **Dependente** monitorado (lista de `CONFIG.DEPENDENTS`).
- **Sala**: tipo `jogo` ou `conversa`, com um `conversation_id` (ex.: botão "Nova conversa" gera `conv-<timestamp>`). O buffer de contexto do backend é por conversa, então trocar de sala deve trocar o ID.
- **Quem envia**: "O menor" (`is_from_minor: true`) ou "Outro participante" (`false`), com um `sender_id` editável.
- **Tipo de mensagem**: "Direta" (`is_direct: true`) ou "No grupo" (`false`).
- Campo de texto e botão Enviar.

Cada mensagem aparece no histórico do chat com um selo do resultado: categoria, confiança em porcentagem e ação (ex.: vermelho para `ALERT_PARENT_CRITICAL`, amarelo para `LOG_INCIDENT`, cinza para `NONE`). Mostrar também se `sha256_match` foi falso.

Útil para a demonstração: alguns botões de mensagens prontas (uma ofensa forte, uma ofensa leve, uma mensagem com link, uma mensagem neutra).

## Envio

1. Pegar o texto **exatamente como digitado**. Se estiver vazio ou só com espaços, não enviar.
2. Calcular o SHA-256 desse mesmo texto:
   ```js
   async function sha256Hex(text) {
     const bytes = new TextEncoder().encode(text);
     const digest = await crypto.subtle.digest("SHA-256", bytes);
     return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, "0")).join("");
   }
   ```
3. Enviar o payload do contrato (`text`, `message_hash`, `dependent_id`, `context_metadata` com `timestamp` em ISO-8601 UTC via `new Date().toISOString()`).
4. Mostrar o resultado; em erro, mostrar o `detail` retornado.

O texto enviado no campo `text` precisa ser **idêntico** ao que gerou o hash; não aplique `trim()` só em um dos dois.

## Observações

- `crypto.subtle` só existe em contexto seguro: abra sempre por `http://localhost:3000`, nunca pelo IP da máquina.
- O backend precisa liberar CORS para `http://localhost:3000`.
- O simulador não faz login; a rota `/predict` é pública por decisão de projeto.
