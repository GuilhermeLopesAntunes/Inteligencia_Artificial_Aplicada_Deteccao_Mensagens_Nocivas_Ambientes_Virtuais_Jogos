"""
Buffer circular em memória para contexto anterior (últimas 3 mensagens)
e rastreamento de incidentes abertos para contexto posterior (até 3 mensagens em 10 minutos).
"""

from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Deque, Dict, List, Tuple, Union

from src.domain.entities import Mensagem


def _ensure_naive_utc(dt: datetime) -> datetime:
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


@dataclass
class MensagemBuffer:
    text: str
    sender_id: str
    is_from_minor: bool
    timestamp: Union[datetime, str]

    def to_dict(self) -> dict:
        if isinstance(self.timestamp, datetime):
            ts_str = self.timestamp.isoformat().replace("+00:00", "Z")
            if not ts_str.endswith("Z") and "+" not in ts_str:
                ts_str += "Z"
        else:
            ts_str = str(self.timestamp)
        return {
            "text": self.text,
            "sender_id": self.sender_id,
            "is_from_minor": self.is_from_minor,
            "timestamp": ts_str,
        }


MensagemBufferItem = MensagemBuffer


@dataclass
class IncidenteAbertoBuffer:
    incident_id: str
    conversation_id: str
    created_at: datetime
    posterior_messages: List[dict] = field(default_factory=list)


class InMemoryBuffer:
    """
    Mantém:
    1. Buffer circular de até 3 mensagens por `conversation_id` (em memória volátil).
    2. Lista de incidentes abertos para receber até 3 mensagens posteriores dentro de 10 minutos (600s).
    """

    MAX_CONTEXT_BEFORE = 3
    MAX_CONTEXT_AFTER = 3
    WINDOW_SECONDS = 600  # 10 minutos

    def __init__(self, maxlen: int = 3):
        self._maxlen = maxlen
        self._buffers: Dict[str, Deque[MensagemBuffer]] = {}
        self._open_incidents: Dict[str, List[IncidenteAbertoBuffer]] = {}

    def clear(self) -> None:
        self._buffers.clear()
        self._open_incidents.clear()

    def _to_mensagem_buffer(self, msg: Union[MensagemBuffer, Mensagem, dict]) -> MensagemBuffer:
        if isinstance(msg, MensagemBuffer):
            return msg
        if isinstance(msg, Mensagem):
            return MensagemBuffer(
                text=msg.texto,
                sender_id=msg.remetente_id,
                is_from_minor=msg.eh_do_menor,
                timestamp=msg.timestamp,
            )
        if isinstance(msg, dict):
            return MensagemBuffer(
                text=msg.get("text") or msg.get("texto", ""),
                sender_id=msg.get("sender_id") or msg.get("remetente_id", ""),
                is_from_minor=bool(
                    msg.get("is_from_minor")
                    if "is_from_minor" in msg
                    else msg.get("eh_do_minor", msg.get("eh_do_menor", False))
                ),
                timestamp=msg.get("timestamp", datetime.utcnow()),
            )
        raise TypeError(f"Tipo de mensagem não suportado no buffer: {type(msg)}")

    def adicionar_mensagem(
        self, conversation_id: str, msg: Union[MensagemBuffer, Mensagem, dict]
    ) -> None:
        if conversation_id not in self._buffers:
            self._buffers[conversation_id] = deque(maxlen=self._maxlen)
        self._buffers[conversation_id].append(self._to_mensagem_buffer(msg))

    def obter_contexto_anterior(self, conversation_id: str) -> List[dict]:
        if conversation_id not in self._buffers:
            return []
        return [m.to_dict() for m in self._buffers[conversation_id]]

    def obter_contexto_anterior_dicts(self, conversation_id: str) -> List[dict]:
        return self.obter_contexto_anterior(conversation_id)

    def abrir_incidente_para_posteriores(
        self,
        conversation_id: str,
        incident_id: str,
        created_at: datetime = None,
    ) -> None:
        if created_at is None:
            created_at = datetime.utcnow()
        created_at_utc = _ensure_naive_utc(created_at)
        if conversation_id not in self._open_incidents:
            self._open_incidents[conversation_id] = []
        self._open_incidents[conversation_id].append(
            IncidenteAbertoBuffer(
                incident_id=incident_id,
                conversation_id=conversation_id,
                created_at=created_at_utc,
            )
        )

    def registrar_incidente_pendente(
        self,
        conversation_id: str,
        incident_id: str,
        created_at: datetime = None,
    ) -> None:
        self.abrir_incidente_para_posteriores(conversation_id, incident_id, created_at)

    def anexar_mensagem_posterior(
        self,
        conversation_id: str,
        msg: Union[MensagemBuffer, Mensagem, dict],
        now: datetime = None,
    ) -> List[IncidenteAbertoBuffer]:
        """
        Anexa a mensagem como contexto posterior aos incidentes abertos da conversa
        que tenham menos de 3 mensagens posteriores e tenham sido criados há no máximo 10 minutos.
        Retorna a lista de incidentes abertos que foram atualizados nesta chamada.
        """
        if conversation_id not in self._open_incidents:
            return []

        msg_buf = self._to_mensagem_buffer(msg)
        if now is None:
            if isinstance(msg_buf.timestamp, datetime):
                now = msg_buf.timestamp
            else:
                now = datetime.utcnow()
        now_utc = _ensure_naive_utc(now)

        updated: List[IncidenteAbertoBuffer] = []
        still_open: List[IncidenteAbertoBuffer] = []

        for inc in self._open_incidents[conversation_id]:
            elapsed = (now_utc - inc.created_at).total_seconds()
            if elapsed <= self.WINDOW_SECONDS and len(inc.posterior_messages) < self.MAX_CONTEXT_AFTER:
                inc.posterior_messages.append(msg_buf.to_dict())
                updated.append(inc)
                if len(inc.posterior_messages) < self.MAX_CONTEXT_AFTER:
                    still_open.append(inc)

        self._open_incidents[conversation_id] = still_open
        return updated

    def processar_contexto_posterior(
        self,
        conversation_id: str,
        msg: Union[MensagemBuffer, Mensagem, dict],
        now: datetime = None,
    ) -> List[Tuple[str, List[dict]]]:
        updated = self.anexar_mensagem_posterior(conversation_id, msg, now=now)
        return [(inc.incident_id, list(inc.posterior_messages)) for inc in updated]


in_memory_buffer = InMemoryBuffer()
buffer_contexto = in_memory_buffer

__all__ = [
    "MensagemBuffer",
    "MensagemBufferItem",
    "IncidenteAbertoBuffer",
    "InMemoryBuffer",
    "in_memory_buffer",
    "buffer_contexto",
]
