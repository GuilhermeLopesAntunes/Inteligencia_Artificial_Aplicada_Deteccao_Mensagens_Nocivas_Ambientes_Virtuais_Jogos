import hashlib
from src.infrastructure.bertimbau_engine import (
    MockClassificadorStrategy,
    RealBERTimbauEngine,
)
from src.services.analise_service import set_classificador_override


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def test_predict_mensagem_segura_nao_persiste_incidente(client):
    set_classificador_override(MockClassificadorStrategy(default_prob=0.12))
    texto = "Oi pessoal, vamos fazer o trabalho de história?"
    payload = {
        "text": texto,
        "message_hash": _sha256(texto),
        "dependent_id": "dep-001",
        "context_metadata": {
            "conversation_id": "conv-001",
            "room_type": "conversa",
            "sender_id": "colega-01",
            "is_from_minor": False,
            "is_direct": True,
            "timestamp": "2026-04-12T18:30:00Z",
        },
    }

    resp = client.post("/api/v1/predict", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["label"] == "normal"
    assert data["category"] == "SEGURO"
    assert data["action_required"] == "NONE"
    assert data["incident_id"] is None
    assert data["sha256_match"] is True


def test_predict_incidente_critico_com_contexto_anterior_e_posterior(client):
    mock = MockClassificadorStrategy(
        default_prob=0.10,
        overrides={"inútil": 0.92},
    )
    set_classificador_override(mock)

    # 1. Envia 2 mensagens seguras antes (context_before)
    for i, msg in enumerate(["Oi Lucas", "Tudo bem?"], start=1):
        r = client.post(
            "/api/v1/predict",
            json={
                "text": msg,
                "message_hash": _sha256(msg),
                "dependent_id": "dep-001",
                "context_metadata": {
                    "conversation_id": "conv-ctx",
                    "room_type": "jogo",
                    "sender_id": "player-2",
                    "is_from_minor": False,
                    "is_direct": True,
                    "timestamp": f"2026-04-12T18:30:0{i}Z",
                },
            },
        )
        assert r.status_code == 200
        assert r.json()["incident_id"] is None

    # 2. Envia mensagem crítica (P = 0.92 >= 0.85)
    msg_critica = "Você é um inútil, sai desse jogo"
    r_crit = client.post(
        "/api/v1/predict",
        json={
            "text": msg_critica,
            "message_hash": _sha256(msg_critica),
            "dependent_id": "dep-001",
            "context_metadata": {
                "conversation_id": "conv-ctx",
                "room_type": "jogo",
                "sender_id": "player-2",
                "is_from_minor": False,
                "is_direct": True,
                "timestamp": "2026-04-12T18:30:10Z",
            },
        },
    )
    assert r_crit.status_code == 200
    crit_data = r_crit.json()
    assert crit_data["label"] == "nocivo"
    assert crit_data["category"] == "CIBERBULLYING"
    assert crit_data["action_required"] == "ALERT_PARENT_CRITICAL"
    assert crit_data["detected_role"] == "VITIMA"
    assert crit_data["sha256_match"] is True
    inc_id = crit_data["incident_id"]
    assert inc_id is not None

    # 3. Envia mensagem posterior segura na mesma conversa dentro de 10 min (context_after)
    msg_depois = "Não fala assim comigo"
    client.post(
        "/api/v1/predict",
        json={
            "text": msg_depois,
            "message_hash": _sha256(msg_depois),
            "dependent_id": "dep-001",
            "context_metadata": {
                "conversation_id": "conv-ctx",
                "room_type": "jogo",
                "sender_id": "dep-001",
                "is_from_minor": True,
                "is_direct": True,
                "timestamp": "2026-04-12T18:31:00Z",
            },
        },
    )

    # 4. Faz login e consulta o detalhe do incidente para verificar context_before e context_after
    login_resp = client.post(
        "/api/v1/auth/login",
        json={"email": "responsavel@exemplo.com", "password": "senha123"},
    )
    token = login_resp.json()["access_token"]

    detail_resp = client.get(
        f"/api/v1/incidents/{inc_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert len(detail["context_before"]) == 2
    assert [m["text"] for m in detail["context_before"]] == ["Oi Lucas", "Tudo bem?"]
    assert len(detail["context_after"]) == 1
    assert detail["context_after"][0]["text"] == "Não fala assim comigo"


def test_predict_com_modelo_bertimbau_real_end_to_end(client):
    """
    Valida a Seção 4.2 e 4.3 de INTEGRACAO_BACKEND_BERT.md:
    - Inferência real do modelo BERTimbau via POST /api/v1/predict.
    - Medição de inference_time_ms em CPU.
    - Health check GET / reportando model_loaded: True.
    """
    set_classificador_override(RealBERTimbauEngine())

    # 1. Mensagem inócua real
    msg_inocua = "bom dia amigo, vamos jogar"
    resp_ok = client.post(
        "/api/v1/predict",
        json={
            "text": msg_inocua,
            "message_hash": _sha256(msg_inocua),
            "dependent_id": "dep-001",
            "context_metadata": {
                "conversation_id": "conv-real-1",
                "room_type": "conversa",
                "sender_id": "amigo-1",
                "is_from_minor": False,
                "is_direct": True,
                "timestamp": "2026-04-12T19:00:00Z",
            },
        },
    )
    assert resp_ok.status_code == 200
    body_ok = resp_ok.json()
    assert body_ok["label"] == "normal"
    assert body_ok["confidence"] < 0.50
    assert body_ok["category"] == "SEGURO"
    assert body_ok["action_required"] == "NONE"
    assert body_ok["incident_id"] is None
    assert body_ok["inference_time_ms"] > 0

    # 2. Mensagem tóxica real
    msg_toxica = "Você é um inútil, ninguém gosta de você"
    resp_tox = client.post(
        "/api/v1/predict",
        json={
            "text": msg_toxica,
            "message_hash": _sha256(msg_toxica),
            "dependent_id": "dep-001",
            "context_metadata": {
                "conversation_id": "conv-real-1",
                "room_type": "conversa",
                "sender_id": "agressor-1",
                "is_from_minor": False,
                "is_direct": True,
                "timestamp": "2026-04-12T19:01:00Z",
            },
        },
    )
    assert resp_tox.status_code == 200
    body_tox = resp_tox.json()
    assert body_tox["label"] == "nocivo"
    assert body_tox["confidence"] >= 0.85
    assert body_tox["category"] == "CIBERBULLYING"
    assert body_tox["action_required"] == "ALERT_PARENT_CRITICAL"
    assert body_tox["incident_id"] is not None
    assert body_tox["inference_time_ms"] > 0

    # 3. Health check confirma model_loaded == True
    health = client.get("/")
    assert health.status_code == 200
    assert health.json()["model_loaded"] is True


def test_predict_erros_validacao_e_dependente_inexistente(client):
    set_classificador_override(MockClassificadorStrategy(default_prob=0.10))

    # Texto vazio -> 400
    r_empty = client.post(
        "/api/v1/predict",
        json={
            "text": "   ",
            "message_hash": _sha256("   "),
            "dependent_id": "dep-001",
            "context_metadata": {
                "conversation_id": "c1",
                "room_type": "conversa",
                "sender_id": "u1",
                "is_from_minor": False,
                "is_direct": True,
                "timestamp": "2026-04-12T18:30:00Z",
            },
        },
    )
    assert r_empty.status_code == 400

    # Dependente inexistente -> 404
    r_404 = client.post(
        "/api/v1/predict",
        json={
            "text": "Olá",
            "message_hash": _sha256("Olá"),
            "dependent_id": "dep-inexistente",
            "context_metadata": {
                "conversation_id": "c1",
                "room_type": "conversa",
                "sender_id": "u1",
                "is_from_minor": False,
                "is_direct": True,
                "timestamp": "2026-04-12T18:30:00Z",
            },
        },
    )
    assert r_404.status_code == 404
