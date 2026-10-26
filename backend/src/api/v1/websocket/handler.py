import asyncio
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional

import jwt
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from src.api.core.config import settings
from src.infrastructure.database import SessionLocal
from src.infrastructure.models import (
    GuardianDependentORM,
    GuardianORM,
    IncidentORM,
)

router = APIRouter()
logger = logging.getLogger(__name__)

ALGORITHM = "HS256"


def format_incident_summary_dict(inc: IncidentORM) -> dict:
    created_str = inc.created_at.isoformat().replace("+00:00", "Z")
    if not created_str.endswith("Z") and "+" not in created_str:
        created_str += "Z"
    return {
        "id": inc.id,
        "dependent_id": inc.dependent_id,
        "dependent_name": inc.dependent.name if inc.dependent else "Desconhecido",
        "category": inc.category,
        "severity": inc.severity,
        "confidence": inc.confidence,
        "has_link": inc.has_link,
        "detected_role": inc.detected_role,
        "status": inc.status,
        "integrity_mismatch": not inc.integrity_valid,
        "escalated": inc.escalated,
        "preview": inc.main_message_text[:60],
        "created_at": created_str,
    }


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self._main_loop: Optional[asyncio.AbstractEventLoop] = None

    async def connect(self, websocket: WebSocket, guardian_id: str):
        try:
            self._main_loop = asyncio.get_running_loop()
        except RuntimeError:
            pass
        await websocket.accept()
        if guardian_id not in self.active_connections:
            self.active_connections[guardian_id] = []
        self.active_connections[guardian_id].append(websocket)
        logger.info(f"WebSocket conectado para guardian {guardian_id}")

    def disconnect(self, websocket: WebSocket, guardian_id: str):
        if guardian_id in self.active_connections:
            if websocket in self.active_connections[guardian_id]:
                self.active_connections[guardian_id].remove(websocket)
            if not self.active_connections[guardian_id]:
                del self.active_connections[guardian_id]
        logger.info(f"WebSocket desconectado para guardian {guardian_id}")

    async def _send_with_timeout(
        self, connection: WebSocket, message: str, guardian_id: str
    ):
        try:
            await asyncio.wait_for(connection.send_text(message), timeout=1.5)
        except Exception as e:
            logger.error(f"Erro ao enviar mensagem WebSocket: {e}")
            if connection in self.active_connections.get(guardian_id, []):
                self.active_connections[guardian_id].remove(connection)

    async def send_personal_message(self, message: str, guardian_id: str):
        if guardian_id in self.active_connections:
            connections = list(reversed(self.active_connections[guardian_id]))
            if connections:
                await asyncio.gather(
                    *(
                        self._send_with_timeout(conn, message, guardian_id)
                        for conn in connections
                    ),
                    return_exceptions=True,
                )

    async def broadcast(self, message: str):
        for guardian_id in list(self.active_connections.keys()):
            await self.send_personal_message(message, guardian_id)

    async def send_event_to_guardians(
        self, event_type: str, data: dict, guardian_ids: Optional[List[str]] = None
    ):
        now_str = datetime.utcnow().isoformat() + "Z"
        payload = json.dumps(
            {
                "type": event_type,
                "event": event_type,
                "sent_at": now_str,
                "data": data,
            }
        )
        if guardian_ids is None:
            await self.broadcast(payload)
            return
        for gid in guardian_ids:
            await self.send_personal_message(payload, gid)

    def notify_event_sync(
        self, event_type: str, data: dict, guardian_ids: Optional[List[str]] = None
    ):
        """Envia evento WebSocket a partir de código síncrono ou assíncrono sem bloquear."""
        if guardian_ids is not None and not guardian_ids:
            return
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(
                self.send_event_to_guardians(event_type, data, guardian_ids)
            )
            return
        except RuntimeError:
            pass

        if self._main_loop is not None and self._main_loop.is_running():
            try:
                asyncio.run_coroutine_threadsafe(
                    self.send_event_to_guardians(event_type, data, guardian_ids),
                    self._main_loop,
                )
                return
            except Exception:
                pass

        try:
            import anyio.from_thread

            anyio.from_thread.run(
                self.send_event_to_guardians, event_type, data, guardian_ids
            )
        except Exception:
            try:
                asyncio.run(
                    self.send_event_to_guardians(
                        event_type, data, guardian_ids
                    )
                )
            except Exception as e:
                logger.debug(f"Ignorando dispatch WS sem loop ativo: {e}")


manager = ConnectionManager()


async def send_incident_created_notification(incident_data: dict):
    await manager.send_event_to_guardians("incident.created", incident_data)


async def send_incident_critical_notification(incident_data: dict):
    await manager.send_event_to_guardians("incident.critical", incident_data)


async def send_incident_updated_notification(incident_data: dict):
    await manager.send_event_to_guardians("incident.updated", incident_data)


async def send_incident_deleted_notification(incident_id: str, dependent_id: str):
    await manager.send_event_to_guardians(
        "incident.deleted", {"id": incident_id, "dependent_id": dependent_id}
    )


def get_guardian_ids_for_dependent(
    db: Session, dependent_id: str, primary_only: Optional[bool] = None
) -> List[str]:
    query = db.query(GuardianDependentORM).filter(
        GuardianDependentORM.dependent_id == dependent_id
    )
    if primary_only is True:
        query = query.filter(GuardianDependentORM.is_primary.is_(True))
    elif primary_only is False:
        query = query.filter(GuardianDependentORM.is_primary.is_(False))
    return [link.guardian_id for link in query.all()]


def validate_ws_token(token: Optional[str]) -> Optional[str]:
    if not token:
        return None
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[ALGORITHM]
        )
        user_id: str = payload.get("sub")
        return user_id
    except jwt.PyJWTError:
        return None


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: Optional[str] = None,
):
    """
    Endpoint WebSocket para notificações em tempo real (/ws?token=<jwt>).
    Se o token estiver ausente ou inválido, fecha com código 4401.
    """
    user_id = validate_ws_token(token)
    if not user_id:
        await websocket.accept()
        await websocket.close(code=4401)
        return

    await manager.connect(websocket, user_id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
                if message.get("type") == "ping":
                    await websocket.send_text(json.dumps({"type": "pong"}))
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
    except Exception as e:
        logger.error(f"Erro na conexão WebSocket: {e}")
        manager.disconnect(websocket, user_id)