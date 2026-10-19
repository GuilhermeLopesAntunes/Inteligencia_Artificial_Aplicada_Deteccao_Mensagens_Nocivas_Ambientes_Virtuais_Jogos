"""
Serviço de geração de relatórios PDF probatórios para incidentes (com verificação SHA-256).
"""

from datetime import datetime
import hashlib
from io import BytesIO
import json
import logging
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from sqlalchemy.orm import Session

from src.infrastructure.models import (
    DependentORM,
    IncidentORM,
    IncidentStatusHistoryORM,
)

logger = logging.getLogger(__name__)


def gerar_relatorio_incidente(
    db: Session,
    incident_id: str,
) -> BytesIO:
    """
    Gera um relatório PDF probatório do incidente com verificação de integridade SHA-256.
    """
    incidente = db.query(IncidentORM).filter(IncidentORM.id == incident_id).first()
    if not incidente:
        raise ValueError(f"Incidente {incident_id} não encontrado")

    dependent = (
        db.query(DependentORM)
        .filter(DependentORM.id == incidente.dependent_id)
        .first()
    )

    recalculated_hash = hashlib.sha256(
        incidente.main_message_text.encode("utf-8")
    ).hexdigest()
    is_authentic = (
        bool(incidente.integrity_valid)
        and recalculated_hash.lower() == (incidente.main_message_hash or "").lower()
    )
    status_integridade = (
        "AUTÊNTICO (Integridade Verificada)"
        if is_authentic
        else "INTEGRIDADE DIVERGENTE"
    )

    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=54,
        leftMargin=54,
        topMargin=54,
        bottomMargin=36,
    )

    story = []
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "CustomTitle",
        parent=styles["Heading1"],
        fontSize=16,
        spaceAfter=20,
        alignment=TA_CENTER,
    )
    heading_style = ParagraphStyle(
        "CustomHeading",
        parent=styles["Heading2"],
        fontSize=12,
        spaceAfter=10,
        textColor=colors.darkblue,
    )
    normal_style = styles["Normal"]
    normal_style.fontSize = 9
    normal_style.spaceAfter = 4

    story.append(Paragraph("RELATÓRIO PROBATÓRIO DE INCIDENTE - PROJECT ARTEMIS", title_style))
    story.append(Spacer(1, 8))

    story.append(Paragraph("1. DADOS GERAIS DO INCIDENTE", heading_style))
    incident_data = [
        ["ID do Incidente:", incidente.id],
        ["Dependente:", f"{dependent.name} ({dependent.id})" if dependent else incidente.dependent_id],
        ["Data/Hora da Detecção:", incidente.created_at.strftime("%d/%m/%Y %H:%M:%S UTC")],
        ["Status Atual:", incidente.status],
        ["Categoria / Severidade:", f"{incidente.category} / {incidente.severity}"],
        ["Probabilidade P(nocivo):", f"{incidente.confidence:.4f} ({incidente.confidence:.2%})"],
        ["Link Suspeito Detectado:", "Sim" if incidente.has_link else "Não"],
        ["Papel do Menor:", incidente.detected_role],
        ["Ação Recomendada:", incidente.action_required],
    ]
    incident_table = Table(incident_data, colWidths=[2.2 * inch, 4.0 * inch])
    incident_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.lightgrey),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.black),
                ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
            ]
        )
    )
    story.append(incident_table)
    story.append(Spacer(1, 14))

    story.append(Paragraph("2. MENSAGEM PRINCIPAL E VERIFICAÇÃO SHA-256", heading_style))
    story.append(Paragraph(f'Conteúdo: "{incidente.main_message_text}"', normal_style))
    story.append(Spacer(1, 6))

    meta_data = [
        ["Remetente:", incidente.main_message_sender_id],
        ["Enviada pelo Menor:", "Sim" if incidente.main_message_is_from_minor else "Não"],
        ["Timestamp da Mensagem:", incidente.main_message_timestamp.strftime("%d/%m/%Y %H:%M:%S UTC")],
        ["Hash SHA-256 de Origem:", incidente.main_message_hash],
        ["Hash SHA-256 Recalculado:", recalculated_hash],
        ["Status de Autenticidade:", status_integridade],
    ]
    meta_table = Table(meta_data, colWidths=[2.2 * inch, 4.0 * inch])
    meta_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.lightgrey),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.black),
                ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
            ]
        )
    )
    story.append(meta_table)
    story.append(Spacer(1, 14))

    story.append(Paragraph("3. CONTEXTO DA CONVERSA", heading_style))
    try:
        before_list = json.loads(incidente.context_before) if incidente.context_before else []
    except (json.JSONDecodeError, TypeError):
        before_list = []

    story.append(Paragraph("Contexto Anterior (até 3 mensagens):", normal_style))
    if before_list:
        for i, m in enumerate(before_list, 1):
            story.append(
                Paragraph(
                    f"  [{i}] ({m.get('timestamp', 'N/A')}) {m.get('sender_id', 'N/A')}: \"{m.get('text', '')}\"",
                    normal_style,
                )
            )
    else:
        story.append(Paragraph("  Nenhuma mensagem anterior registrada.", normal_style))

    story.append(Spacer(1, 6))
    try:
        after_list = json.loads(incidente.context_after) if incidente.context_after else []
    except (json.JSONDecodeError, TypeError):
        after_list = []

    story.append(Paragraph("Contexto Posterior (até 3 mensagens / 10 min):", normal_style))
    if after_list:
        for i, m in enumerate(after_list, 1):
            story.append(
                Paragraph(
                    f"  [{i}] ({m.get('timestamp', 'N/A')}) {m.get('sender_id', 'N/A')}: \"{m.get('text', '')}\"",
                    normal_style,
                )
            )
    else:
        story.append(Paragraph("  Nenhuma mensagem posterior registrada.", normal_style))

    story.append(Spacer(1, 14))
    story.append(Paragraph("4. HISTÓRICO DE TRATAMENTO E STATUS", heading_style))
    historico = (
        db.query(IncidentStatusHistoryORM)
        .filter(IncidentStatusHistoryORM.incident_id == incident_id)
        .order_by(IncidentStatusHistoryORM.changed_at.asc())
        .all()
    )
    if historico:
        hist_data = [["Data/Hora", "De", "Para", "Responsável", "Observação"]]
        for h in historico:
            hist_data.append(
                [
                    h.changed_at.strftime("%d/%m/%Y %H:%M:%S"),
                    h.from_status or "-",
                    h.to_status,
                    h.guardian_name,
                    h.note or "-",
                ]
            )
        hist_table = Table(
            hist_data, colWidths=[1.3 * inch, 1.0 * inch, 1.1 * inch, 1.3 * inch, 1.5 * inch]
        )
        hist_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
                    ("FONTSIZE", (0, 0), (-1, -1), 8),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
                ]
            )
        )
        story.append(hist_table)
    else:
        story.append(Paragraph("Nenhum histórico de status registrado.", normal_style))

    story.append(Spacer(1, 16))
    story.append(
        Paragraph(
            f"Relatório emitido em {datetime.utcnow().strftime('%d/%m/%Y %H:%M:%S UTC')} - Project Artemis (BERTimbau).",
            normal_style,
        )
    )

    doc.build(story)
    buffer.seek(0)
    logger.info(f"Relatório PDF gerado para o incidente {incident_id}")
    return buffer