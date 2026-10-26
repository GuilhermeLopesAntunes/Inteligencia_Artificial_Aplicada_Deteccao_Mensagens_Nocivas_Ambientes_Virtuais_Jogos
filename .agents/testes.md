
# Testes de Software Automatizados & TDD: Project Artemis

> **Sistema de Controle Parental Inteligente com Detecção de Ciberbullying via BERTimbau**  
> **Referência Metodológica:** Prof. Marco Tulio Valente — *Engenharia de Software Moderna* (Capítulo 8 – Testes de Software)  
> **Frameworks Alvo:** Python `pytest` + `httpx` + `unittest.mock` (Backend) / Dart `flutter_test` (App Mobile Flutter)

---

## 1. Estratégia e Pirâmide de Testes

A suíte de testes do **Project Artemis** segue as diretrizes da Engenharia de Software Moderna de Marco Tulio Valente:

```
                      / \
                     /   \
                    / E2E \       ~10% (Fluxo Completo Simulador -> API -> App Flutter)
                   /-------\
                  / Integ.  \     ~20% (Rotas FastAPI, SQLite em Memória, WebSocket)
                 /-----------\
                /   Unidade   \   ~70% (DetectorDeLinks, BVA de Thresholds, Buffer, Tokenizer)
               /---------------\
```

| Nível da Pirâmide | Proporção | Escopo e Responsabilidade no Project Artemis | Tempo de Execução Alvo |
| :--- | :--- | :--- | :--- |
| **Testes de Unidade** | **~70%** | Normalização, detecção de URLs (`DetectorDeLinks`), cálculo de thresholds ($0.50$–$0.84$ e $0.85$), buffer circular (3 anteriores + 3 posteriores), truncamento automático do tokenizer (512 tokens) e Mocks de PyTorch. | $< 10\text{ ms}$ por teste |
| **Testes de Integração** | **~20%** | Endpoint `POST /api/v1/predict` com contrato completo (Decisão 22), rotas de status de incidente (Decisão 31), autenticação JWT, exclusão real LGPD e persistência em SQLite de teste. | $< 150\text{ ms}$ por teste |
| **Testes E2E / Sistema** | **~10%** | Fluxo completo do simulador web disparando mensagem $\rightarrow$ triagem no backend $\rightarrow$ recepção de alerta no WebSocket do App Flutter. | $< 2\text{ s}$ por teste |

---

## 2. Análise de Valor Limite (BVA) e Partições de Equivalência

Mapeamento rigoroso das fronteiras e valores limites para a classificação de risco e regras de entrada:

| Cenário de Teste | Partição Inválida | Limite Inferior / Borda | Partição Válida | Limite Superior / Borda | Ação / Veredito Esperado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mensagem Segura (Padrão $L=0.50$)** | $< 0.0$ | $0.00$ | $0.00 \le P < 0.50$ | $0.499$ | `action: "NONE"`, texto descartado da memória |
| **Incidente Comum (Padrão $L=0.50$)** | — | $0.500$ | $0.500 \le P < 0.850$ | $0.849$ | `action: "LOG_INCIDENT"`, salvo no banco com contexto |
| **Incidente Crítico** | — | $0.850$ | $0.850 \le P \le 1.000$ | $1.000$ | `action: "ALERT_PARENT_CRITICAL"`, emitido no WebSocket |
| **Limiar Calibrado Customizado ($L=0.65$)** | — | $0.00 \le P < 0.650$ | $0.650 \le P < 0.850$ | $0.849$ | Incidente comum disparado somente a partir de $0.650$ |
| **Modo Gamer Ativo ($room\_type = "jogo"$)** | — | $0.00 \le P < 0.699$ | $0.700 \le P < 0.849$ | $0.850 \le P \le 1.000$ | Limiar comum ajustado para $\max(L, 0.70)$; crítico mantido em 0.85 |
| **Detecção de URL Externa** | — | Link presente | `https://...` ou `www....` | Texto seguro + link | Categoria `LINK_SUSPEITO`, `action: "LOG_INCIDENT"` |
| **Tamanho do Texto (Tokens)** | Texto vazio (`""` ou `"   "`) $\implies$ 400 Bad Request | 1 caractere válido | $1 \le \text{tokens} \le 512$ | $> 512$ tokens | Truncado automaticamente pelo tokenizer (`truncation=True`), 200 OK |

---

## 3. Implementação dos Testes de Unidade (Python / Pytest)

### 3.1. Teste de BVA para Limiares de Decisão (Padrão AAA)
```python
import pytest
from src.domain.rules import AvaliadorDecisaoRisco

class TestAvaliadorDecisaoRisco:
    @pytest.fixture
    def avaliador(self):
        return AvaliadorDecisaoRisco()

    @pytest.mark.parametrize("probabilidade, limiar_comum, room_type, has_link, acao_esperada, categoria_esperada", [
        # Fronteiras de Mensagem Segura (Padrão L=0.50)
        (0.00, 0.50, "conversa", False, "NONE", "SEGURO"),
        (0.499, 0.50, "conversa", False, "NONE", "SEGURO"),
        
        # Fronteiras de Incidente Comum (Padrão L=0.50)
        (0.500, 0.50, "conversa", False, "LOG_INCIDENT", "CIBERBULLYING"),
        (0.849, 0.50, "conversa", False, "LOG_INCIDENT", "CIBERBULLYING"),
        
        # Fronteiras de Incidente Crítico (Fixo em 0.85)
        (0.850, 0.50, "conversa", False, "ALERT_PARENT_CRITICAL", "CIBERBULLYING"),
        (1.000, 0.50, "conversa", False, "ALERT_PARENT_CRITICAL", "CIBERBULLYING"),
        
        # Limiar Calibrado Customizado (L=0.65)
        (0.600, 0.65, "conversa", False, "NONE", "SEGURO"),
        (0.650, 0.65, "conversa", False, "LOG_INCIDENT", "CIBERBULLYING"),
        
        # Modo Gamer (room_type="jogo" com L=0.50 -> eleva para 0.70)
        (0.650, 0.50, "jogo", False, "NONE", "SEGURO"),
        (0.700, 0.50, "jogo", False, "LOG_INCIDENT", "CIBERBULLYING"),
        (0.850, 0.50, "jogo", False, "ALERT_PARENT_CRITICAL", "CIBERBULLYING"),
        
        # Modo Gamer com Limiar Customizado Superior (L=0.75 -> usa max(0.75, 0.70) = 0.75)
        (0.720, 0.75, "jogo", False, "NONE", "SEGURO"),
        (0.750, 0.75, "jogo", False, "LOG_INCIDENT", "CIBERBULLYING"),
        
        # Heurística de URL
        (0.100, 0.50, "conversa", True, "LOG_INCIDENT", "LINK_SUSPEITO"),
    ])
    def test_deve_avaliar_acao_correta_conforme_limiares_e_contexto(
        self, avaliador, probabilidade, limiar_comum, room_type, has_link, acao_esperada, categoria_esperada
    ):
        # Arrange & Act
        resultado = avaliador.avaliar(
            probabilidade=probabilidade,
            limiar_comum=limiar_comum,
            room_type=room_type,
            has_link=has_link
        )
        
        # Assert
        assert resultado.action == acao_esperada
        assert resultado.category == categoria_esperada
```

### 3.2. Teste do Detector de Links
```python
import pytest
from src.infrastructure.link_detector import DetectorDeLinks

class TestDetectorDeLinks:
    @pytest.fixture
    def detector(self):
        return DetectorDeLinks()

    @pytest.mark.parametrize("texto, esperado", [
        ("Oi, como vai você?", False),
        ("Acesse https://discord.gg/malicioso agora", True),
        ("Veja em http://site.com/foto.jpg", True),
        ("Entra no www.jogosproibidos.com", True),
        ("Sem link nenhum aqui", False),
    ])
    def test_deve_detectar_presenca_de_links_corretamente(self, detector, texto, esperado):
        assert detector.has_link(texto) == esperado
```

### 3.3. Teste de Truncamento do Tokenizer (Sem Erro 400)
```python
import pytest
from unittest.mock import MagicMock
from src.infrastructure.bertimbau_engine import RealBERTimbauEngine

def test_deve_truncar_textos_longos_sem_lancar_excecao():
    # Arrange
    texto_longo = " ".join(["palavra"] * 600)  # > 512 tokens, sem espaço nas pontas
    mock_tokenizer = MagicMock()
    mock_model = MagicMock()
    mock_tokenizer.return_value = {"input_ids": "tensores_mock", "attention_mask": "mask_mock"}
    
    engine = RealBERTimbauEngine(tokenizer=mock_tokenizer, model=mock_model)
    
    # Act
    engine.tokenizar(texto_longo)
    
    # Assert
    mock_tokenizer.assert_called_once_with(
        texto_longo,
        truncation=True,
        max_length=512,
        return_tensors="pt"
    )
```

---

## 4. Testes de Integração da API (FastAPI + TestClient)

```python
import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_predict_endpoint_sucesso_com_contrato_completo():
    # Arrange
    payload = {
        "text": "Você é horrível e ninguém gosta de você",
        "message_hash": "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e",
        "dependent_id": "dep-001",
        "context_metadata": {
            "conversation_id": "conv-game-88",
            "room_type": "jogo",
            "sender_id": "user-adversario-09",
            "is_from_minor": False,
            "is_direct": True,
            "timestamp": "2026-10-07T14:30:00Z"
        }
    }
    
    # Act
    response = client.post("/api/v1/predict", json=payload)
    
    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "label" in data
    assert "category" in data
    assert "confidence" in data
    assert "has_link" in data
    assert "action_required" in data
    assert "detected_role" in data
    assert "sha256_match" in data
    assert "model_version" in data
    assert "inference_time_ms" in data

def test_predict_endpoint_rejeita_texto_vazio_com_400():
    payload = {
        "text": "   ",
        "message_hash": "abc",
        "dependent_id": "dep-001",
        "context_metadata": {
            "conversation_id": "conv-1",
            "room_type": "conversa",
            "sender_id": "user-1",
            "is_from_minor": False,
            "is_direct": True,
            "timestamp": "2026-10-07T14:30:00Z"
        }
    }
    response = client.post("/api/v1/predict", json=payload)
    assert response.status_code == 400
```
