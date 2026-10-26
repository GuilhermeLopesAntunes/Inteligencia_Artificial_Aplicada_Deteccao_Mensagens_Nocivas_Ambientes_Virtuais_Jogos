# Backend - Etapa 2: Infraestrutura e IA BERTimbau

> **Objetivo:** Implementar os adaptadores de infraestrutura (`src/infrastructure/`): inferência BERTimbau em CPU via Lazy Proxy, DetectorDeLinks, Buffer circular de memória e persistência SQLite via SQLAlchemy.

---

## 1. Arquivos a Criar/Atualizar
- `backend/src/infrastructure/__init__.py`
- `backend/src/infrastructure/bertimbau_engine.py`
- `backend/src/infrastructure/link_detector.py`
- `backend/src/infrastructure/in_memory_buffer.py`
- `backend/src/infrastructure/database.py`
- `backend/src/infrastructure/repositories.py`
- `backend/src/config.py`

---

## 2. Detalhamento dos Componentes

### 2.1. Lazy Proxy e Strategy do BERTimbau (`src/infrastructure/bertimbau_engine.py`)
* **Interface `ClassificadorStrategy`**:
  ```python
  from abc import ABC, abstractmethod

  class ClassificadorStrategy(ABC):
      @abstractmethod
      def predict_probability(self, texto: str) -> float:
          """Retorna a probabilidade P(nocivo) entre 0.0 e 1.0"""
          pass
  ```
* **Virtual Proxy `BERTimbauEngineProxy`**:
  * Mantém referência `_real_engine = None`.
  * Na primeira chamada a `predict_probability`, instancia `RealBERTimbauEngine` carregando pesos de `settings.model_dir`.
  * `RealBERTimbauEngine`: Executa `AutoTokenizer.from_pretrained` e `AutoModelForSequenceClassification.from_pretrained`, colocando o modelo em `eval()` e inferindo com `torch.no_grad()`.
* **Factory Method `get_classificador()`**:
  * Se `APP_ENV == "testing"`, retorna `MockClassificadorFactory` (evita carregar 440MB nos testes).
  * Senão, retorna a instância singleton do `BERTimbauEngineProxy`.

### 2.2. Detector de Links (`src/infrastructure/link_detector.py`)
* Compilação estática do Regex: `re.compile(r"https?://\S+|www\.\S+", re.IGNORECASE)`.
* Método `has_link(texto: str) -> bool`.

### 2.3. Buffer Circular de Mensagens (`src/infrastructure/in_memory_buffer.py`)
* Estrutura em memória usando `collections.deque(maxlen=3)` indexada por `conversation_id`.
* Métodos:
  * `adicionar_mensagem(conversation_id: str, msg: MensagemBuffer)`
  * `obter_contexto_anterior(conversation_id: str) -> list[MensagemBuffer]`
  * Gerenciamento de incidentes abertos para contexto posterior (janela de 10 min e limite de 3 mensagens posteriores).

### 2.4. Banco de Dados e Repositórios (`src/infrastructure/database.py` e `repositories.py`)
* Configuração SQLAlchemy 2.0 com SQLite: `DATABASE_URL = sqlite:////app/data/artemis.db`.
* Tabelas:
  * `responsaveis`: `id`, `name`, `email`, `password_hash`, `created_at`.
  * `dependentes`: `id`, `name`, `common_threshold`, `safe_messages_count`, `created_at`.
  * `responsaveis_dependentes`: `guardian_id`, `dependent_id`, `is_primary`.
  * `incidentes`: `id`, `dependent_id`, `category`, `confidence`, `has_link`, `detected_role`, `status`, `integrity_mismatch`, `escalated`, `room_type`, `conversation_id`, `text`, `sender_id`, `is_from_minor`, `message_hash`, `timestamp`, `created_at`.
  * `mensagens_contexto`: `id`, `incident_id`, `tipo` (`BEFORE`/`AFTER`), `text`, `sender_id`, `is_from_minor`, `timestamp`.
  * `historico_status`: `id`, `incident_id`, `from_status`, `to_status`, `note`, `guardian_id`, `changed_at`.
  * `feedbacks_falso_positivo`: `id`, `incident_id`, `note`, `created_at`.
  * `convites_coparentalidade`: `code`, `dependent_id`, `created_by`, `expires_at`, `used`.

---

## 3. Critérios de Aceitação da Etapa
- [ ] Testes do Lazy Proxy confirmam que a aplicação inicia sem instanciar PyTorch imediatamente.
- [ ] Regex de link valida URLs com `http://`, `https://`, `www.` e descarta textos comuns.
- [ ] Buffer circular retém exatamente as últimas 3 mensagens e anexa posteriores conforme janela temporal.
- [ ] Migrações/criação automática de tabelas do SQLite funcionam no startup.
