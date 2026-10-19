import hashlib
import pytest
from starlette.websockets import WebSocketDisconnect

from src.infrastructure.bertimbau_engine import MockClassificadorStrategy
from src.services.analise_service import set_classificador_override


def test_websocket_rejeita_token_invalido_com_4401(client):
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws?token=token-invalido") as ws:
            ws.receive_text()
    assert exc_info.value.code == 4401


def test_websocket_notifica_incidente_critico_em_tempo_real(client):
    login_resp = client.post(
        "/api/v1/auth/login",
        json={"email": "responsavel@exemplo.com", "password": "senha123"},
    )
    token = login_resp.json()["access_token"]

    set_classificador_override(MockClassificadorStrategy(default_prob=0.93))

    with client.websocket_connect(f"/ws?token={token}") as ws:
        texto = "Vou acabar com você na saída da escola"
        pred_resp = client.post(
            "/api/v1/predict",
            json={
                "text": texto,
                "message_hash": hashlib.sha256(texto.encode("utf-8")).hexdigest(),
                "dependent_id": "dep-001",
                "context_metadata": {
                    "conversation_id": "conv-ws-1",
                    "room_type": "conversa",
                    "sender_id": "agressor-ws",
                    "is_from_minor": False,
                    "is_direct": True,
                    "timestamp": "2026-04-12T18:30:00Z",
                },
            },
        )
        assert pred_resp.status_code == 200
        inc_id = pred_resp.json()["incident_id"]

        # Conforme contrato-api.md linha 329:
        # "Um incidente crítico gera dois eventos: incident.created e incident.critical"
        ev1 = ws.receive_json()
        ev2 = ws.receive_json()
        tipos = {ev1["type"], ev2["type"]}
        assert tipos == {"incident.created", "incident.critical"}
        assert ev1["data"]["id"] == inc_id
        assert ev2["data"]["severity"] == "CRITICO"
