def test_login_sucesso_e_perfil_me(client):
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "responsavel@exemplo.com", "password": "senha123"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["guardian"]["id"] == "resp-001"
    assert len(data["guardian"]["dependents"]) == 2

    token = data["access_token"]
    me_resp = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me_resp.status_code == 200
    assert me_resp.json()["email"] == "responsavel@exemplo.com"


def test_login_credenciais_invalidas_e_acesso_sem_token(client):
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "responsavel@exemplo.com", "password": "senha-errada"},
    )
    assert resp.status_code == 401

    me_unauth = client.get("/api/v1/auth/me")
    assert me_unauth.status_code == 401
