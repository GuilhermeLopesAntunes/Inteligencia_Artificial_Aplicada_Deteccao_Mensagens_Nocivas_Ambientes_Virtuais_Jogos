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


def test_register_guardian_com_dependente_e_sincronizacao_simulador(client):
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Carlos Silva",
            "email": "carlos@exemplo.com",
            "password": "senha789",
            "dependent_name": "Gabriel",
        },
    )
    assert reg_resp.status_code == 201
    reg_data = reg_resp.json()
    assert "access_token" in reg_data
    token = reg_data["access_token"]
    assert reg_data["guardian"]["email"] == "carlos@exemplo.com"
    assert len(reg_data["guardian"]["dependents"]) == 1
    dep_created = reg_data["guardian"]["dependents"][0]
    assert dep_created["name"] == "Gabriel"
    assert dep_created["is_primary"] is True

    # Verifica adição de um 2º filho via POST /api/v1/dependents
    second_dep = client.post(
        "/api/v1/dependents",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Sofia", "common_threshold": 0.60},
    )
    assert second_dep.status_code == 201
    assert second_dep.json()["name"] == "Sofia"

    # Verifica que ambos aparecem na rota do Simulador Web (Ideia 3)
    sim_resp = client.get("/api/v1/dependents/simulator")
    assert sim_resp.status_code == 200
    sim_names = [d["name"] for d in sim_resp.json()]
    assert "Gabriel" in sim_names
    assert "Sofia" in sim_names

