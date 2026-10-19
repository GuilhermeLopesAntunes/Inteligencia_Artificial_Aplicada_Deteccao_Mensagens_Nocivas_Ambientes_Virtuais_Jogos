from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from src.api.core.security import get_current_guardian_id
from src.infrastructure.database import get_db
from src.infrastructure.models import GuardianDependentORM, IncidentORM
from src.services.relatorio_service import gerar_relatorio_incidente

router = APIRouter()


@router.get("/{incident_id}/report")
def gerar_relatorio(
    incident_id: str,
    guardian_id: str = Depends(get_current_guardian_id),
    db: Session = Depends(get_db),
):
    """
    Gera e retorna o relatório PDF probatório de um incidente específico.
    """
    incidente = db.query(IncidentORM).filter(IncidentORM.id == incident_id).first()
    if not incidente:
        raise HTTPException(status_code=404, detail="Incidente não encontrado")

    link = (
        db.query(GuardianDependentORM)
        .filter(
            GuardianDependentORM.guardian_id == guardian_id,
            GuardianDependentORM.dependent_id == incidente.dependent_id,
        )
        .first()
    )
    if not link:
        raise HTTPException(
            status_code=403,
            detail="Responsável não possui acesso a este incidente",
        )

    pdf_buffer = gerar_relatorio_incidente(db, incident_id)
    filename = f"incidente-{incident_id}.pdf"

    return Response(
        content=pdf_buffer.read(),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )