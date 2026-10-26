# Integração - Etapa 3: Auditoria SHA-256 e Relatório PDF

> **Objetivo:** Validar a preservação da cadeia de custódia probatória das mensagens e a emissão do documento pericial em PDF para os pais.

---

## 1. Fluxo de Validação da Cadeia de Custódia Criptográfica

```
[ Usuário no Simulador ] 
       | (Digita mensagem original)
       v
[ Web Crypto API (Browser) ] ---> Calcula SHA-256 (Hash Original)
       |
       | (Envia texto + hash original via POST /api/v1/predict)
       v
[ Backend Artemis ] -------------> Recalcula SHA-256 (Hash Verificado)
       |                           Compara: sha256_match = (recalculado == original)
       v
[ Banco SQLite ] ----------------> Persiste flag `integrity_mismatch = !sha256_match`
       |
       v
[ Relatório PDF ] ---------------> Imprime seção de Auditoria Pericial:
                                   - Hash Declarado no Envio
                                   - Hash Verificado pelo Servidor
                                   - Timestamp UTC e Veredito de Autenticidade
```

---

## 2. Roteiro de Teste da Evidência Digital

### Teste de Integridade Positiva (Mensagem Autêntica)
1. Enviar mensagem regular pelo simulador.
2. Abrir o incidente no App Flutter e clicar em "Exportar Relatório (PDF)".
3. Abrir o PDF gerado e inspecionar a seção **"Auditoria e Cadeia de Custódia"**:
   - Status exibido: `AUTÊNTICO (SHA-256 VÁLIDO)`.
   - Hashes idênticos exibidos em hexadecimal minúsculo.

### Teste de Detecção de Adulteração (Integridade Divergente)
1. Disparar uma requisição via terminal/cURL com `message_hash` propositalmente adulterado.
2. Abrir o incidente no App.
3. Verificar a presença do aviso de divergência no app e o selo de `INTEGRIDADE DIVERGENTE` no PDF gerado.

---

## 3. Critérios de Aceitação da Etapa
- [ ] O relatório PDF é gerado e baixado em $< 1$ segundo.
- [ ] O layout do documento segue o padrão visual formal com metadados e contexto claros.
- [ ] A verificação de integridade aponta com precisão divergências ou confirmações de integridade.
