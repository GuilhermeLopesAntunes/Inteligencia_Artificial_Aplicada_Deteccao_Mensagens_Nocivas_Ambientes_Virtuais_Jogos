import hashlib
from src.infrastructure.bertimbau_engine import MockClassificadorStrategy
from src.services.analise_service import set_classificador_override


def _login(client, email: str, password: str) -> str:
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert resp.status_code == 200
    return resp.json()["access_token"]


def _criar_incidente(client, texto: str = "Você é um idiota", prob: float = 0.88) -> str:
    set_classificador_override(MockClassificadorStrategy(default_prob=prob))
    resp = client.post(
        "/api/v1/predict",
        json={
            "text": texto,
            "message_hash": hashlib.sha256(texto.encode("utf-8")).hexdigest(),
            "dependent_id": "dep-001",
            "context_metadata": {
                "conversation_id": "conv-inc-test",
                "room_type": "conversa",
                "sender_id": "agressor-99",
                "is_from_minor": False,
                "is_direct": True,
                "timestamp": "2026-04-12T18:30:00Z",
            },
        },
    )
    assert resp.status_code == 200
    return resp.json()["incident_id"]


def test_ciclo_vida_incidente_view_idempotente_status_pdf_e_exclusao_lgpd(client):
    token_primario = _login(client, "responsavel@exemplo.com", "senha123")
    token_secundario = _login(client, "joao@exemplo.com", "senha456")
    headers_prim = {"Authorization": f"Bearer {token_primario}"}
    headers_sec = {"Authorization": f"Bearer {token_secundario}"}

    inc_id = _criar_incidente(client)

    # 1. Listagem de incidentes retorna items e total exato
    list_resp = client.get("/api/v1/incidents", headers=headers_prim)
    assert list_resp.status_code == 200
    assert list_resp.json()["total"] == 1
    assert list_resp.json()["items"][0]["id"] == inc_id

    # 2. Tentativa de pular de DETECTADO direto para RESOLVIDO deve retornar 409 Conflict
    invalid_status = client.patch(
        f"/api/v1/incidents/{inc_id}/status",
        headers=headers_prim,
        json={"status": "RESOLVIDO", "note": "Tentando pular"},
    )
    assert invalid_status.status_code == 409

    # 3. POST /view muda de DETECTADO -> VISUALIZADO
    view_1 = client.post(f"/api/v1/incidents/{inc_id}/view", headers=headers_prim)
    assert view_1.status_code == 200
    assert view_1.json()["status"] == "VISUALIZADO"

    # 4. Transição válida VISUALIZADO -> EM_ANALISE -> CONVERSADO_COM_FILHO (pelo co-responsável secundário)
    step_2 = client.patch(
        f"/api/v1/incidents/{inc_id}/status",
        headers=headers_sec,
        json={"status": "EM_ANALISE", "note": "Analisando o caso"},
    )
    assert step_2.status_code == 200
    assert step_2.json()["status"] == "EM_ANALISE"

    step_3 = client.patch(
        f"/api/v1/incidents/{inc_id}/status",
        headers=headers_sec,
        json={"status": "CONVERSADO_COM_FILHO", "note": "Conversei com o Lucas hoje"},
    )
    assert step_3.status_code == 200
    assert step_3.json()["status"] == "CONVERSADO_COM_FILHO"

    # 5. POST /view novamente quando já está em CONVERSADO_COM_FILHO é idempotente (200 OK e mantém status)
    view_idemp = client.post(f"/api/v1/incidents/{inc_id}/view", headers=headers_prim)
    assert view_idemp.status_code == 200
    assert view_idemp.json()["status"] == "CONVERSADO_COM_FILHO"

    # 6. Exportação de Relatório PDF Probatório
    pdf_resp = client.get(f"/api/v1/incidents/{inc_id}/report", headers=headers_prim)
    assert pdf_resp.status_code == 200
    assert pdf_resp.headers["content-type"] == "application/pdf"
    assert f'filename="incidente-{inc_id}.pdf"' in pdf_resp.headers["content-disposition"]
    assert pdf_resp.content.startswith(b"%PDF")

    # 7. Exclusão LGPD: Responsável secundário recebe 403 Forbidden
    del_sec = client.delete(f"/api/v1/incidents/{inc_id}", headers=headers_sec)
    assert del_sec.status_code == 403

    # 8. Exclusão LGPD: Responsável primário recebe 204 No Content
    del_prim = client.delete(f"/api/v1/incidents/{inc_id}", headers=headers_prim)
    assert del_prim.status_code == 204

    # Verifica que não existe mais
    get_deleted = client.get(f"/api/v1/incidents/{inc_id}", headers=headers_prim)
    assert get_deleted.status_code == 404


def test_calibracao_limiar_primario_vs_secundario_e_bva(client):
    token_primario = _login(client, "responsavel@exemplo.com", "senha123")
    token_secundario = _login(client, "joao@exemplo.com", "senha456")
    headers_prim = {"Authorization": f"Bearer {token_primario}"}
    headers_sec = {"Authorization": f"Bearer {token_secundario}"}

    # Co-responsável secundário não pode calibrar limiar -> 403
    r_sec = client.patch(
        "/api/v1/dependents/dep-001/threshold",
        headers=headers_sec,
        json={"common_threshold": 0.65},
    )
    assert r_sec.status_code == 403

    # Limiar fora da faixa [0.50, 0.84] -> 422
    r_low = client.patch(
        "/api/v1/dependents/dep-001/threshold",
        headers=headers_prim,
        json={"common_threshold": 0.49},
    )
    assert r_low.status_code == 422

    r_high = client.patch(
        "/api/v1/dependents/dep-001/threshold",
        headers=headers_prim,
        json={"common_threshold": 0.85},
    )
    assert r_high.status_code == 422

    # Calibração válida pelo primário -> 200 OK
    r_ok = client.patch(
        "/api/v1/dependents/dep-001/threshold",
        headers=headers_prim,
        json={"common_threshold": 0.65},
    )
    assert r_ok.status_code == 200
    assert r_ok.json()["common_threshold"] == 0.65
