"""
Regras puras de negócio para avaliação de risco, detecção de papel do menor,
normalização textual, calibração de limiar e transições de status.
Nenhuma dependência externa (modelo, banco, etc.) - apenas Python puro.
"""

from dataclasses import dataclass
import re
from typing import List, Tuple, Union

from .enums import (
    AcaoRequerida,
    CategoriaAmeaca,
    PapelMenor,
    SeveridadeIncidente,
    StatusIncidente,
)

LIMIAR_CRITICO = 0.85
LIMIAR_MINIMO_GAMER = 0.70
LIMIAR_PADRAO_COMUM = 0.50
LIMIAR_MIN_CALIBRACAO = 0.50
LIMIAR_MAX_CALIBRACAO = 0.84

_ZERO_WIDTH_RE = re.compile(r"[\u200b\u200c\u200d\ufeff]")


def normalizar_texto(texto: str) -> str:
    """
    Remove caracteres invisíveis (zero-width) e espaços redundantes,
    preservando integralmente emojis, pontuações e stopwords.
    Levanta ValueError se o texto resultar vazio.
    """
    if texto is None:
        raise ValueError("Texto não pode ser nulo.")
    limpo = _ZERO_WIDTH_RE.sub("", texto)
    normalizado = " ".join(limpo.split())
    if not normalizado:
        raise ValueError("Texto não pode estar vazio após normalização.")
    return normalizado


def calcular_limiar_efetivo(limiar_comum: float, room_type: str) -> float:
    """
    Em sala 'jogo' (Modo Gamer), L = max(limiar_comum, 0.70).
    Em sala 'conversa', L = limiar_comum.
    """
    if room_type == "jogo":
        return max(limiar_comum, LIMIAR_MINIMO_GAMER)
    return limiar_comum


def validar_calibracao_limiar(novo_limiar: float) -> float:
    """Valida que o limiar comum calibrado pertence ao intervalo fechado [0.50, 0.84]."""
    if novo_limiar is None or not (LIMIAR_MIN_CALIBRACAO <= novo_limiar <= LIMIAR_MAX_CALIBRACAO):
        raise ValueError(
            f"O limiar comum deve estar entre {LIMIAR_MIN_CALIBRACAO:.2f} e {LIMIAR_MAX_CALIBRACAO:.2f}."
        )
    return round(float(novo_limiar), 2)


@dataclass(frozen=True)
class ResultadoDecisaoRisco:
    category: CategoriaAmeaca
    severity: SeveridadeIncidente
    action_required: AcaoRequerida
    label: str
    persists_incident: bool

    @property
    def action(self) -> AcaoRequerida:
        return self.action_required

    @property
    def categoria(self) -> CategoriaAmeaca:
        return self.category

    @property
    def acao_requerida(self) -> AcaoRequerida:
        return self.action_required

    def __iter__(self):
        yield self.category
        yield self.action_required


def avaliar_risco(
    probabilidade_nocivo: float,
    limiar_comum: float,
    sala_tipo: str,
    tem_link: bool,
) -> Tuple[CategoriaAmeaca, AcaoRequerida]:
    """
    Avalia o risco baseado na probabilidade do modelo, limiar e detecção de link.
    Ordem estrita de avaliação (regras-de-negocio.md seção 3):
    1. P >= 0.85 -> (CIBERBULLYING, ALERT_PARENT_CRITICAL)
    2. L <= P < 0.85 -> (CIBERBULLYING, LOG_INCIDENT)
    3. P < L e has_link -> (LINK_SUSPEITO, LOG_INCIDENT)
    4. P < L e não has_link -> (SEGURO, NONE)
    """
    limiar_efetivo = calcular_limiar_efetivo(limiar_comum, sala_tipo)

    if probabilidade_nocivo >= LIMIAR_CRITICO:
        return CategoriaAmeaca.CIBERBULLYING, AcaoRequerida.ALERT_PARENT_CRITICAL

    if limiar_efetivo <= probabilidade_nocivo < LIMIAR_CRITICO:
        return CategoriaAmeaca.CIBERBULLYING, AcaoRequerida.LOG_INCIDENT

    if probabilidade_nocivo < limiar_efetivo and tem_link:
        return CategoriaAmeaca.LINK_SUSPEITO, AcaoRequerida.LOG_INCIDENT

    return CategoriaAmeaca.SEGURO, AcaoRequerida.NONE


class AvaliadorDecisaoRisco:
    """Avaliador puro de decisão de risco conforme especificação de domínio."""

    calcular_limiar_efetivo = staticmethod(calcular_limiar_efetivo)

    @staticmethod
    def avaliar(
        probabilidade_nocivo: float = 0.0,
        has_link: bool = False,
        room_type: str = "conversa",
        limiar_comum: float = LIMIAR_PADRAO_COMUM,
        *,
        probabilidade: float = None,
    ) -> ResultadoDecisaoRisco:
        p = probabilidade if probabilidade is not None else probabilidade_nocivo
        categoria, acao = avaliar_risco(
            probabilidade_nocivo=p,
            limiar_comum=limiar_comum,
            sala_tipo=room_type,
            tem_link=has_link,
        )
        label = "nocivo" if p >= LIMIAR_PADRAO_COMUM else "normal"
        if acao == AcaoRequerida.ALERT_PARENT_CRITICAL:
            sev = SeveridadeIncidente.CRITICO
            persists = True
        elif acao == AcaoRequerida.LOG_INCIDENT:
            sev = SeveridadeIncidente.COMUM
            persists = True
        else:
            sev = SeveridadeIncidente.NENHUMA
            persists = False

        return ResultadoDecisaoRisco(
            category=categoria,
            severity=sev,
            action_required=acao,
            label=label,
            persists_incident=persists,
        )


def derivar_papel_menor(is_from_minor: bool, is_direct: bool) -> PapelMenor:
    """
    Deriva o papel do menor baseado nos metadados da mensagem (regras-de-negocio.md seção 4):
    - is_from_minor = true -> EMISSOR
    - is_from_minor = false e is_direct = true -> VITIMA
    - is_from_minor = false e is_direct = false -> ESPECTADOR
    """
    if is_from_minor:
        return PapelMenor.EMISSOR
    if is_direct:
        return PapelMenor.VITIMA
    return PapelMenor.ESPECTADOR


def detectar_papel_menor(eh_do_menor: bool, eh_direto: bool) -> PapelMenor:
    """Alias em português para derivar_papel_menor."""
    return derivar_papel_menor(is_from_minor=eh_do_menor, is_direct=eh_direto)


TRANSIÇÕES_VALIDAS = {
    StatusIncidente.DETECTADO: [StatusIncidente.VISUALIZADO],
    StatusIncidente.VISUALIZADO: [
        StatusIncidente.EM_ANALISE,
        StatusIncidente.FALSO_POSITIVO,
    ],
    StatusIncidente.EM_ANALISE: [
        StatusIncidente.CONVERSADO_COM_FILHO,
        StatusIncidente.ENCAMINHADO_A_ESCOLA,
        StatusIncidente.FALSO_POSITIVO,
        StatusIncidente.RESOLVIDO,
    ],
    StatusIncidente.CONVERSADO_COM_FILHO: [StatusIncidente.RESOLVIDO],
    StatusIncidente.ENCAMINHADO_A_ESCOLA: [StatusIncidente.RESOLVIDO],
    StatusIncidente.FALSO_POSITIVO: [],
    StatusIncidente.RESOLVIDO: [],
}

TRANSICOES_VALIDAS = TRANSIÇÕES_VALIDAS


def obter_transicoes_permitidas(
    status_atual: Union[StatusIncidente, str]
) -> List[str]:
    """
    Retorna a lista de destinos manuais válidos (como strings) a partir do status atual
    (regras-de-negocio.md seção 9).
    DETECTADO e VISUALIZADO nunca são aceitos como destino manual.
    """
    try:
        st = (
            status_atual
            if isinstance(status_atual, StatusIncidente)
            else StatusIncidente(status_atual)
        )
    except ValueError:
        return []
    destinos = TRANSIÇÕES_VALIDAS.get(st, [])
    return [
        s.value
        for s in destinos
        if s not in (StatusIncidente.DETECTADO, StatusIncidente.VISUALIZADO)
    ]


def eh_transicao_valida(
    status_atual: Union[StatusIncidente, str],
    status_novo: Union[StatusIncidente, str],
    manual: bool = False,
) -> bool:
    """
    Verifica se uma transição de status é válida conforme as regras de negócio.
    Se manual=True, bloqueia transições para DETECTADO ou VISUALIZADO.
    """
    try:
        st_atual = (
            status_atual
            if isinstance(status_atual, StatusIncidente)
            else StatusIncidente(status_atual)
        )
        st_novo = (
            status_novo
            if isinstance(status_novo, StatusIncidente)
            else StatusIncidente(status_novo)
        )
    except ValueError:
        return False

    if manual and st_novo in (StatusIncidente.DETECTADO, StatusIncidente.VISUALIZADO):
        return False

    return st_novo in TRANSIÇÕES_VALIDAS.get(st_atual, [])