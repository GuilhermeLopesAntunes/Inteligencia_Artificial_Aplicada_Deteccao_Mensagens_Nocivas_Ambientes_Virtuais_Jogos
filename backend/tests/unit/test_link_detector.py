import pytest
from src.infrastructure.link_detector import DetectorDeLinks


@pytest.mark.parametrize(
    "texto_com_link",
    [
        "Acesse https://phishing-premiacao.com/login agora!",
        "Clique em http://site-suspeito.net/ganhe-gemas",
        "Entre em www.roubodeconta.com.br para ganhar skins",
        "Baixe no link bit.ly/3xYzAbC",
        "Conecte no servidor 192.168.1.100/admin",
        "Olha esse site: discord-gift.xyz/claim",
    ],
)
def test_detector_de_links_positivos(texto_com_link):
    assert DetectorDeLinks.detectar_link(texto_com_link) is True
    assert DetectorDeLinks().has_link(texto_com_link) is True


@pytest.mark.parametrize(
    "texto_sem_link",
    [
        "Bom dia amigo, vamos jogar mais tarde?",
        "Tirei nota 9.5 na prova de matemática e 3.14 em física",
        "Meu e-mail é aluno@escola.com.br, me manda o resumo lá",
        "Você é muito ruim nesse jogo...",
        "",
    ],
)
def test_detector_de_links_negativos(texto_sem_link):
    assert DetectorDeLinks.detectar_link(texto_sem_link) is False
    assert DetectorDeLinks().has_link(texto_sem_link) is False
