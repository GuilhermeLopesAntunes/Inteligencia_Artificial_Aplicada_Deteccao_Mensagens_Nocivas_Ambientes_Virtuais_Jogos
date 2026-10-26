# Simulador - Etapa 2: Criptografia Web Crypto API e Formatação de Payload

> **Objetivo:** Implementar o cálculo nativo de SHA-256 no browser do cliente e a montagem do payload padronizado para a API.

---

## 1. Arquivos a Criar/Atualizar
- `simulator/app.js`
- `simulator/config.js`

---

## 2. Detalhamento dos Componentes

### 2.1. Configuração (`simulator/config.js`)
```javascript
const CONFIG = {
  API_URL: "http://localhost:8000/api/v1/predict",
  DEPENDENTS: [
    { id: "dep-001", name: "Lucas" },
    { id: "dep-002", name: "Ana" }
  ],
  DEFAULT_ROOM: "jogo",
  MOCK_MODE: false // Permite alternar para desenvolvimento isolado
};
```

### 2.2. Cálculo de SHA-256 via Web Crypto API (`simulator/app.js`)
```javascript
async function calcularSha256(texto) {
  const encoder = new TextEncoder();
  const dados = encoder.encode(texto);
  const hashBuffer = await crypto.subtle.digest("SHA-256", dados);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}
```

### 2.3. Montagem e Envio do Payload
```javascript
async function enviarMensagem(texto) {
  if (!texto || texto.trim().length === 0) {
    alert("Digite uma mensagem válida.");
    return;
  }

  const hashCalculado = await calcularSha256(texto);
  const payload = {
    text: texto,
    message_hash: hashCalculado,
    dependent_id: document.getElementById("dependent_select").value,
    context_metadata: {
      conversation_id: document.getElementById("conversation_id").value,
      room_type: document.getElementById("room_type_select").value,
      sender_id: document.getElementById("sender_id").value,
      is_from_minor: document.getElementById("is_from_minor").checked,
      is_direct: document.getElementById("is_direct").checked,
      timestamp: new Date().toISOString()
    }
  };

  if (CONFIG.MOCK_MODE) {
    simularRespostaLocal(payload);
    return;
  }

  try {
    const response = await fetch(CONFIG.API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.detail || "Erro no processamento da API.");
    }

    const resultado = await response.json();
    renderizarMensagemComResultado(payload, resultado);
  } catch (err) {
    renderizarMensagemComErro(payload, err.message);
  }
}
```

---

## 3. Critérios de Aceitação da Etapa
- [ ] O hash gerado é consistente com o padrão SHA-256 UTF-8.
- [ ] O envio do payload respeita rigorosamente o esquema definido em `.agents/contrato-api.md`.
- [ ] Tratamento de erros exibe mensagens claras caso a API esteja indisponível.
