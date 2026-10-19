import pytest
from src.domain.entities import (
    AcaoRequerida,
    CategoriaAmeaca,
    PapelMenor,
    SeveridadeIncidente,
    StatusIncidente,
)
from src.domain.rules import (
    AvaliadorDecisaoRisco,
    calcular_limiar_efetivo,
    derivar_papel_menor,
    detectar_papel_menor,
    eh_transicao_valida,
    normalizar_texto,
    obter_transicoes_permitidas,
    validar_calibracao_limiar,
)


@pytest.mark.parametrize(
    "p_nocivo,has_link,room_type,limiar_comum,expected_cat,expected_sev,expected_action,expected_persists",
    [
        # L_efetivo = 0.50 (conversa, L=0.50)
        (0.00, False, "conversa", 0.50, CategoriaAmeaca.SEGURO, SeveridadeIncidente.NENHUMA, AcaoRequerida.NONE, False),
        (0.49, False, "conversa", 0.50, CategoriaAmeaca.SEGURO, SeveridadeIncidente.NENHUMA, AcaoRequerida.NONE, False),
        (0.50, False, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.51, False, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.84, False, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.85, False, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.CRITICO, AcaoRequerida.ALERT_PARENT_CRITICAL, True),
        (0.86, False, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.CRITICO, AcaoRequerida.ALERT_PARENT_CRITICAL, True),
        (1.00, False, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.CRITICO, AcaoRequerida.ALERT_PARENT_CRITICAL, True),
        # Modo Gamer (room_type="jogo", L=0.50 -> L_efetivo = max(0.50, 0.70) = 0.70)
        (0.69, False, "jogo", 0.50, CategoriaAmeaca.SEGURO, SeveridadeIncidente.NENHUMA, AcaoRequerida.NONE, False),
        (0.70, False, "jogo", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.71, False, "jogo", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        # Modo Gamer com L=0.80 -> L_efetivo = max(0.80, 0.70) = 0.80
        (0.75, False, "jogo", 0.80, CategoriaAmeaca.SEGURO, SeveridadeIncidente.NENHUMA, AcaoRequerida.NONE, False),
        (0.80, False, "jogo", 0.80, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        # DetectorDeLinks (has_link=True)
        (0.10, True, "conversa", 0.50, CategoriaAmeaca.LINK_SUSPEITO, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.60, True, "jogo", 0.50, CategoriaAmeaca.LINK_SUSPEITO, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.75, True, "conversa", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.COMUM, AcaoRequerida.LOG_INCIDENT, True),
        (0.90, True, "jogo", 0.50, CategoriaAmeaca.CIBERBULLYING, SeveridadeIncidente.CRITICO, AcaoRequerida.ALERT_PARENT_CRITICAL, True),
    ],
)
def test_bva_avaliador_decisao_risco(
    p_nocivo,
    has_link,
    room_type,
    limiar_comum,
    expected_cat,
    expected_sev,
    expected_action,
    expected_persists,
):
    decisao = AvaliadorDecisaoRisco.avaliar(
        probabilidade_nocivo=p_nocivo,
        has_link=has_link,
        room_type=room_type,
        limiar_comum=limiar_comum,
    )
    assert decisao.category == expected_cat
    assert decisao.severity == expected_sev
    assert decisao.action_required == expected_action
    assert decisao.persists_incident is expected_persists
    assert decisao.label == ("nocivo" if p_nocivo >= 0.50 else "normal")


def test_calcular_limiar_efetivo():
    assert calcular_limiar_efetivo(0.50, "conversa") == 0.50
    assert calcular_limiar_efetivo(0.50, "jogo") == 0.70
    assert calcular_limiar_efetivo(0.78, "jogo") == 0.78


@pytest.mark.parametrize("limiar_valido", [0.50, 0.51, 0.65, 0.83, 0.84])
def test_validar_calibracao_limiar_valido(limiar_valido):
    assert validar_calibracao_limiar(limiar_valido) == round(limiar_valido, 2)


@pytest.mark.parametrize("limiar_invalido", [-0.10, 0.0, 0.49, 0.85, 0.90, 1.00])
def test_validar_calibracao_limiar_invalido(limiar_invalido):
    with pytest.raises(ValueError):
        validar_calibracao_limiar(limiar_invalido)


def test_derivar_papel_menor():
    assert derivar_papel_menor(is_from_minor=True, is_direct=True) == PapelMenor.EMISSOR
    assert derivar_papel_menor(is_from_minor=True, is_direct=False) == PapelMenor.EMISSOR
    assert derivar_papel_menor(is_from_minor=False, is_direct=True) == PapelMenor.VITIMA
    assert derivar_papel_menor(is_from_minor=False, is_direct=False) == PapelMenor.ESPECTADOR
    assert detectar_papel_menor(eh_do_menor=False, eh_direto=True) == PapelMenor.VITIMA


def test_maquina_estados_transicoes():
    assert eh_transicao_valida(StatusIncidente.DETECTADO.value, StatusIncidente.VISUALIZADO.value)
    assert not eh_transicao_valida(StatusIncidente.DETECTADO.value, StatusIncidente.VISUALIZADO.value, manual=True)
    assert not eh_transicao_valida(StatusIncidente.DETECTADO.value, StatusIncidente.RESOLVIDO.value)
    assert eh_transicao_valida(StatusIncidente.VISUALIZADO.value, StatusIncidente.EM_ANALISE.value)
    assert eh_transicao_valida(StatusIncidente.VISUALIZADO.value, StatusIncidente.FALSO_POSITIVO.value)
    assert eh_transicao_valida(StatusIncidente.EM_ANALISE.value, StatusIncidente.CONVERSADO_COM_FILHO.value)
    assert eh_transicao_valida(StatusIncidente.EM_ANALISE.value, StatusIncidente.RESOLVIDO.value)
    assert eh_transicao_valida(StatusIncidente.CONVERSADO_COM_FILHO.value, StatusIncidente.RESOLVIDO.value)
    assert not eh_transicao_valida(StatusIncidente.RESOLVIDO.value, StatusIncidente.EM_ANALISE.value)
    assert not eh_transicao_valida(StatusIncidente.FALSO_POSITIVO.value, StatusIncidente.VISUALIZADO.value)
    assert obter_transicoes_permitidas("RESOLVIDO") == []
    assert obter_transicoes_permitidas("DETECTADO") == []
    assert obter_transicoes_permitidas("VISUALIZADO") == ["EM_ANALISE", "FALSO_POSITIVO"]


def test_normalizar_texto():
    assert normalizar_texto("  Olá   mundo \u200b\u200c ") == "Olá mundo"
    with pytest.raises(ValueError):
        normalizar_texto("   \u200b  ")
