from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional

from .enums import (
    AcaoRequerida,
    CategoriaAmeaca,
    PapelMenor,
    SeveridadeIncidente,
    StatusIncidente,
    TipoEventoWS,
)


@dataclass
class Mensagem:
    texto: str
    remetente_id: str
    eh_do_menor: bool
    timestamp: datetime
    hash_sha256: str
    sala_tipo: str = "conversa"  # "jogo" ou "conversa"
    id_conversa: str = ""

    def to_context_dict(self) -> dict:
        ts_str = (
            self.timestamp.isoformat().replace("+00:00", "Z")
            if isinstance(self.timestamp, datetime)
            else str(self.timestamp)
        )
        if not ts_str.endswith("Z") and "+" not in ts_str:
            ts_str += "Z"
        return {
            "text": self.texto,
            "sender_id": self.remetente_id,
            "is_from_minor": self.eh_do_menor,
            "timestamp": ts_str,
        }


@dataclass
class Incidente:
    id: str
    dependente_id: str
    mensagem_principal: Mensagem
    categoria: CategoriaAmeaca
    severidade: str  # "CRITICO" ou "COMUM"
    confianca: float
    tem_link: bool
    papel_detectado: PapelMenor
    acao_requerida: AcaoRequerida
    integridade_valida: bool
    contexto_antes: List[Mensagem]
    contexto_depois: List[Mensagem]
    status: StatusIncidente
    criado_em: datetime
    atualizado_em: datetime
    escalonado: bool = False
    historico_status: List[dict] = field(default_factory=list)


@dataclass
class Responsavel:
    id: str
    nome: str
    email: str
    eh_primario: bool  # por dependente


@dataclass
class Dependente:
    id: str
    nome: str
    limite_comum: float = 0.50  # 0.50 a 0.84


__all__ = [
    "StatusIncidente",
    "CategoriaAmeaca",
    "SeveridadeIncidente",
    "PapelMenor",
    "AcaoRequerida",
    "TipoEventoWS",
    "Mensagem",
    "Incidente",
    "Responsavel",
    "Dependente",
]