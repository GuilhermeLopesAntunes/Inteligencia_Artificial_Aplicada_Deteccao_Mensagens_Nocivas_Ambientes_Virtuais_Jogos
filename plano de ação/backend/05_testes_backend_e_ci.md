# Backend - Etapa 5: Testes de Backend e CI/CD

> **Objetivo:** Garantir a qualidade e a conformidade arquitetural do backend por meio de testes unitários e de integração automatizados.

---

## 1. Arquivos a Criar/Atualizar
- `backend/tests/conftest.py`
- `backend/tests/unit/test_domain_rules.py`
- `backend/tests/unit/test_link_detector.py`
- `backend/tests/unit/test_in_memory_buffer.py`
- `backend/tests/unit/test_bertimbau_engine.py`
- `backend/tests/integration/test_predict_api.py`
- `backend/tests/integration/test_auth_api.py`
- `backend/tests/integration/test_incidents_api.py`
- `backend/tests/integration/test_websocket.py`

---

## 2. Detalhamento da Suíte de Testes

### 2.1. Configuração Global (`tests/conftest.py`)
* Define `os.environ["APP_ENV"] = "testing"`.
* Configura engine SQLAlchemy com banco em memória (`sqlite:///:memory:` com `StaticPool`).
* Sobrescreve as dependências de banco do FastAPI (`get_db`).
* Popula o banco de teste com a fixture de seed (`resp-001`, `resp-002`, `dep-001`, `dep-002`).

### 2.2. Testes de Unidade (`tests/unit/`)
* **`test_domain_rules.py`**:
  * Executa a matriz BVA completa para $P \in \{0.00, 0.499, 0.500, 0.849, 0.850, 1.00\}$.
  * Valida elevação do Modo Gamer para 0.70 em `room_type = "jogo"`.
  * Valida derivação do papel do menor para todas as combinações booleanas.
  * Valida todas as transições de status válidas e exceções para transições proibidas.
* **`test_link_detector.py`**:
  * Casos positivos (`http://`, `https://`, `www.`) e negativos (textos sem links).
* **`test_in_memory_buffer.py`**:
  * Enfileiramento de até 3 mensagens anteriores.
  * Anexação de até 3 mensagens posteriores dentro da janela de 10 min.
  * Expiração de janela temporal.

### 2.3. Testes de Integração (`tests/integration/`)
* **`test_predict_api.py`**:
  * Payload completo gerando incidente crítico, comum e mensagem segura.
  * Rejeição de texto vazio com 400 Bad Request.
  * Rejeição de `dependent_id` inválido com 404 Not Found.
  * Comportamento diante de `message_hash` divergente (200 OK com flag `sha256_match = False`).
* **`test_auth_api.py`**:
  * Login com credenciais válidas gerando JWT.
  * Login com credenciais inválidas gerando 401.
  * Acesso a rotas protegidas com token válido vs token ausente.
* **`test_incidents_api.py`**:
  * Listagem paginada e filtro por dependente.
  * Fluxo de visualização (`POST /view`) e atualização de status (`PATCH /status`).
  * Emissão de relatório em PDF (`GET /report`) retornando `application/pdf`.
  * Exclusão LGPD (`DELETE /incidents/{id}`) por responsável primário (204) e secundário (403).

---

## 3. Comandos de Execução dos Testes
```bash
# Executar todos os testes
APP_ENV=testing pytest

# Executar apenas testes de unidade rápidos
APP_ENV=testing pytest tests/unit

# Executar com relatório de cobertura
APP_ENV=testing pytest --cov=src --cov-report=term-missing
```

---

## 4. Critérios de Aceitação da Etapa
- [ ] 100% dos testes executam em $< 5$ segundos no ambiente local.
- [ ] Cobertura de código superior a 85% no domínio e nos serviços.
- [ ] Zero dependências de download externo ou arquivos pesados durante os testes.
