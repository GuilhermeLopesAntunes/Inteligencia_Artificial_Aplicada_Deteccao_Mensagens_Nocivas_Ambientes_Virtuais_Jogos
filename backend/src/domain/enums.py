from enum import Enum


class CategoriaAmeaca(str, Enum):
    SEGURO = "SEGURO"
    CIBERBULLYING = "CIBERBULLYING"
    LINK_SUSPEITO = "LINK_SUSPEITO"


class SeveridadeIncidente(str, Enum):
    NENHUMA = "NENHUMA"
    COMUM = "COMUM"
    CRITICO = "CRITICO"


class AcaoRequerida(str, Enum):
    NONE = "NONE"
    LOG_INCIDENT = "LOG_INCIDENT"
    ALERT_PARENT_CRITICAL = "ALERT_PARENT_CRITICAL"


class PapelMenor(str, Enum):
    VITIMA = "VITIMA"
    EMISSOR = "EMISSOR"
    ESPECTADOR = "ESPECTADOR"


class StatusIncidente(str, Enum):
    DETECTADO = "DETECTADO"
    VISUALIZADO = "VISUALIZADO"
    EM_ANALISE = "EM_ANALISE"
    CONVERSADO_COM_FILHO = "CONVERSADO_COM_FILHO"
    ENCAMINHADO_A_ESCOLA = "ENCAMINHADO_A_ESCOLA"
    FALSO_POSITIVO = "FALSO_POSITIVO"
    RESOLVIDO = "RESOLVIDO"


class TipoEventoWS(str, Enum):
    INCIDENT_CREATED = "incident.created"
    INCIDENT_CRITICAL = "incident.critical"
    INCIDENT_ESCALATED = "incident.escalated"
    INCIDENT_UPDATED = "incident.updated"
    INCIDENT_DELETED = "incident.deleted"
