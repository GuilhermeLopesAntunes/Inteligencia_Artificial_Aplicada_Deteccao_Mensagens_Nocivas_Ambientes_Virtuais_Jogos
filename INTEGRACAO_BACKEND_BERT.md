# Plano de Integração: Backend FastAPI e Modelo BERTimbau

> **Documento de Especificação e Integração Técnica**  
> **Sistema:** Project Artemis — Controle Parental Inteligente  
> **Componentes:** `backend/src/` $\leftrightarrow$ `models/modelo_tcc_final/` (`GuilhermeLA/modelo-tcc-final`)  
> **Data:** 19/10/2026

---

## 1. Status de Verificação dos Artefatos do Modelo

Os arquivos do modelo foram verificados no diretório local `models/modelo_tcc_final/`:

| Arquivo | Tamanho | Status | Função |
| :--- | :--- | :---: | :--- |
| `model.safetensors` | ~435.7 MB | Preservado e íntegro | Pesos da rede neural (`bert-base-multilingual-cased` / BERTimbau fine-tuned) |
| `config.json` | 905 B | Preservado | Configuração da arquitetura e mapeamento de labels (`id2label`, `num_labels: 2`) |
| `tokenizer.json` | 678 KB | Preservado | Vocabulário completo e tokenizador serializado |
| `tokenizer_config.json`| 380 B | Preservado | Parâmetros de tokenização (`do_lower_case`, tokens especiais `[CLS]`, `[SEP]`, etc.) |
| `training_args.bin` | 5.2 KB | Preservado | Hiperparâmetros de treinamento utilizados no TCC |

**Diagnóstico:** O modelo local está baixado e pronto para consumo pelo Hugging Face `transformers`.

---

## 2. Arquitetura da Integração

O fluxo de dados da inferência obedece ao padrão de **Lazy Loading** (carregamento sob demanda) para manter inicializações rápidas do servidor FastAPI e otimizar o consumo de memória RAM em CPU:

```mermaid
flowchart TD
    Req[POST /api/v1/predict] --> API[predict.py Controller]
    API --> LinkDet[link_detector.py - Heurística]
    API --> Svc[analise_service.py]
    
    subgraph Engine de Inferência
        Svc --> Engine[bertimbau_engine.py]
        Engine --> Loader[model_loader.py]
        Loader -->|@lru_cache| Memory[PyTorch Model / CPU]
    end
    
    subgraph Regras de Domínio
        Svc --> Rules[domain/rules.py]
        Rules --> Threshold[Limiar Efetivo: Geral 0.50-0.84 / Gamer 0.70 / Crítico 0.85]
    end
    
    Svc --> Output[PredictionResponse & Persistência de Incidente]
```

---

## 3. Componentes e Responsabilidades Técnicas

### 3.1. `src/api/core/config.py`
- Carrega as variáveis de ambiente com Pydantic `BaseSettings`.
- `model_dir`: Configurado por padrão para `models/modelo_tcc_final` (ou `/models/modelo_tcc_final` no Docker).

### 3.2. `src/api/core/model_loader.py`
- **Carregamento Preguiçoso (`get_model` com `@lru_cache(maxsize=1)`):**
  - Instancia `AutoTokenizer.from_pretrained(model_dir)` e `AutoModelForSequenceClassification.from_pretrained(model_dir)`.
  - Configura `model.eval()`.
- **Inferência (`classify_text(text: str)`):**
  - Aplica tokenização com `max_length=512`, `truncation=True` e `return_tensors="pt"`.
  - Executa inferência sob `torch.no_grad()`.
  - Calcula $P(\text{nocivo})$ via `torch.softmax(logits, dim=-1)[0][1].item()`.
  - Retorna `(label, p_nocivo)` com garantia de que a probabilidade é **estritamente a classe 1 (nocivo)**.

### 3.3. `src/infrastructure/bertimbau_engine.py`
- Fachada / camada de abstração limpa para o serviço de domínio, desacoplando o framework Web do Hugging Face.

### 3.4. `src/services/analise_service.py`
- Orquestra:
  1. Verificação de integridade de hash SHA-256 (`crypto.subtle` do simulador vs backend).
  2. Execução da inferência textual (`classify_text`).
  3. Detecção de hyperlinks maliciosos ou externos (`DetectorDeLinks`).
  4. Resolução de contexto com buffer circular das últimas 3 mensagens.
  5. Avaliação de risco com `domain/rules.py` (aplicando regra de sala de jogo / limiar parental).
  6. Criação e persistência do `Incidente` se $P(\text{nocivo}) \ge L$ ou link detectado.
  7. Gatilho de notificação WebSocket se $\ge 0.85$ (Crítico).

---

## 4. Plano de Verificação e Validação Passo a Passo

1. **Validação de Carregamento Unitário:**
   - Teste de sanidade do loader garantindo que `is_model_loaded()` inicia `False` e passa a `True` após a primeira inferência.
2. **Validação de Invariantes Numéricas:**
   - Garantir que a probabilidade retornada pertence ao intervalo $[0.0, 1.0]$.
   - Teste de mensagens inócuas (ex: `"bom dia amigo, vamos jogar"`) com $P < 0.50$.
   - Teste de mensagens tóxicas com $P \ge 0.50$.
3. **Validação de Latência e Performance (CPU):**
   - Mensuração de `inference_time_ms` no payload de resposta para assegurar tempo de resposta aceitável em CPU.
4. **Resiliência a Entradas Excepcionais:**
   - Truncamento correto em textos longos ($> 512$ tokens) sem estouro de memória.
   - Tratamento de caracteres especiais e emojis.
