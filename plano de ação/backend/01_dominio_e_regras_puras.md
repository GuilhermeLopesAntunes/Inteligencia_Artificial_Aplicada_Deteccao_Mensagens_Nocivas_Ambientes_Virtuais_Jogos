# Backend - Etapa 1: Domínio e Regras Puras

> **Objetivo:** Criar o núcleo de regras de negócio em Python puro (`backend/src/domain/`), sem acoplamento com PyTorch, FastAPI ou SQLAlchemy.

---

## 1. Arquivos a Criar/Atualizar
- `backend/src/domain/__init__.py`
- `backend/src/domain/enums.py`
- `backend/src/domain/entities.py`
- `backend/src/domain/rules.py`

---

## 2. Detalhamento dos Componentes

### 2.1. Enums de Negócio (`src/domain/enums.py`)
```python
from enum import Enum

class CategoriaAmeaca(str, Enum):
    SEGURO = "SEGURO"
    CIBERBULLYING = "CIBERBULLYING"
    LINK_SUSPEITO = "LINK_SUSPEITO"

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
```

### 2.2. Avaliador de Decisão de Risco (`src/domain/rules.py`)
* **Constantes:**
  * `LIMIAR_CRITICO = 0.85`
  * `LIMIAR_MINIMO_GAMER = 0.70`
  * `LIMIAR_PADRAO_COMUM = 0.50`
* **Lógica da Tabela de Decisão:**
  1. Se `probabilidade >= 0.85` $\implies$ Categoria `CIBERBULLYING`, Ação `ALERT_PARENT_CRITICAL`.
  2. Calcular `L = limiar_comum` (se `room_type == "jogo"`, `L = max(limiar_comum, 0.70)`).
  3. Se `probabilidade >= L` $\implies$ Categoria `CIBERBULLYING`, Ação `LOG_INCIDENT`.
  4. Se `has_link == True` $\implies$ Categoria `LINK_SUSPEITO`, Ação `LOG_INCIDENT`.
  5. Senão $\implies$ Categoria `SEGURO`, Ação `NONE`.

### 2.3. Derivação do Papel do Menor (`src/domain/rules.py`)
```python
def derivar_papel_menor(is_from_minor: bool, is_direct: bool) -> PapelMenor:
    if is_from_minor:
        return PapelMenor.EMISSOR
    if is_direct:
        return PapelMenor.VITIMA
    return PapelMenor.ESPECTADOR
```

### 2.4. Transições de Status Válidas (`src/domain/rules.py`)
```python
TRANSIÇÕES_VALIDAS = {
    StatusIncidente.DETECTADO: [StatusIncidente.VISUALIZADO],
    StatusIncidente.VISUALIZADO: [StatusIncidente.EM_ANALISE, StatusIncidente.FALSO_POSITIVO],
    StatusIncidente.EM_ANALISE: [
        StatusIncidente.CONVERSADO_COM_FILHO,
        StatusIncidente.ENCAMINHADO_A_ESCOLA,
        StatusIncidente.FALSO_POSITIVO,
        StatusIncidente.RESOLVIDO
    ],
    StatusIncidente.CONVERSADO_COM_FILHO: [StatusIncidente.RESOLVIDO],
    StatusIncidente.ENCAMINHADO_A_ESCOLA: [StatusIncidente.RESOLVIDO],
    StatusIncidente.FALSO_POSITIVO: [],
    StatusIncidente.RESOLVIDO: []
}

def obter_transicoes_permitidas(status_atual: StatusIncidente) -> list[StatusIncidente]:
    # Exclui transições automáticas (DETECTADO e VISUALIZADO nunca são destinos manuais)
    destinos = TRANSIÇÕES_VALIDAS.get(status_atual, [])
    return [s for s in destinos if s not in (StatusIncidente.DETECTADO, StatusIncidente.VISUALIZADO)]
```

---

## 3. Critérios de Aceitação da Etapa
- [ ] Testes unitários para `AvaliadorDecisaoRisco` validando todos os cenários da tabela de BVA sem falhas.
- [ ] Testes de transição de status cobrindo transições permitidas e rejeições de transições ilegais.
- [ ] Nenhuma dependência externa importada em `src/domain/`.
