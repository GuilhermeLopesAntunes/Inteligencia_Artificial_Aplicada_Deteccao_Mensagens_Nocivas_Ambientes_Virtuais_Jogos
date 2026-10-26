# Backend - Etapa 3: Serviços de Aplicação

> **Objetivo:** Implementar os casos de uso do sistema em `backend/src/services/`, orquestrando domínio e infraestrutura sem vazar regras para as rotas da API.

---

## 1. Arquivos a Criar/Atualizar
- `backend/src/services/__init__.py`
- `backend/src/services/analise_service.py`
- `backend/src/services/gestao_incidente_service.py`
- `backend/src/services/relatorio_service.py`
- `backend/src/services/escalonamento_service.py`
- `backend/src/services/auth_service.py`

---

## 2. Detalhamento dos Componentes

### 2.1. `AnaliseMensagemService` (`src/services/analise_service.py`)
* **Fluxo de Execução:**
  1. Anexar mensagem como posterior nos incidentes abertos da mesma `conversation_id`.
  2. Validar integridade SHA-256 (`recalculado == message_hash.lower()`).
  3. Obter limiar do dependente no repositório.
  4. Executar inferência neural ($P(\text{nocivo})$) e detecção de links (`has_link`).
  5. Avaliar risco via `AvaliadorDecisaoRisco` (considerando Modo Gamer se `room_type == "jogo"`).
  6. Derivar papel do menor (`VITIMA`, `EMISSOR`, `ESPECTADOR`).
  7. Se for seguro (`NONE`):
     - Incrementar `safe_messages_count` do dependente.
     - Adicionar ao buffer circular em memória.
     - Retornar resposta com `incident_id = None`.
  8. Se for incidente (`LOG_INCIDENT` ou `ALERT_PARENT_CRITICAL`):
     - Coletar contexto anterior do buffer.
     - Persistir incidente, mensagem principal e contexto anterior no banco.
     - Abrir incidente para recebimento de até 3 mensagens posteriores.
     - Adicionar mensagem atual ao buffer.
     - Disparar observadores de notificação: `incident.created` (e `incident.critical` se $P \ge 0.85$).
     - Retornar payload completo com `incident_id`.

### 2.2. `GestaoIncidenteService` (`src/services/gestao_incidente_service.py`)
* **Métodos:**
  * `listar_incidentes(guardian_id, dependente_id, status, category, limit, offset)`: Retorna lista paginada respeitando apenas os dependentes associados ao guardião.
  * `obter_detalhe(incident_id, guardian_id)`: Retorna detalhe completo com mensagens de contexto, histórico e `allowed_transitions`.
  * `marcar_visualizado(incident_id, guardian_id)`: Se `status == DETECTADO`, atualiza para `VISUALIZADO` e grava histórico; idempotente.
  * `atualizar_status(incident_id, novo_status, note, guardian_id)`: Valida transição via `TRANSIÇÕES_VALIDAS` (rejeita com 409 se inválida), grava histórico e registra feedback se `FALSO_POSITIVO`. Dispara evento `incident.updated`.
  * `excluir_incidente(incident_id, guardian_id)`: Valida se o usuário é primário (403 se secundário); remove fisicamente incidente, mensagens de contexto, histórico e feedback. Dispara evento `incident.deleted`.

### 2.3. `RelatorioService` (`src/services/relatorio_service.py`)
* Implementa o padrão Template Method (`RelatorioIncidenteTemplate`).
* Renderização em PDF usando `reportlab`:
  * Cabeçalho institucional do Project Artemis.
  * Identificação do incidente, data/hora UTC e dependente.
  * Tabela de integridade da evidência: Hash SHA-256 de origem, hash verificado e status de integridade.
  * Mensagem principal em destaque com confiança e papel do menor.
  * Blocos de mensagens de contexto anterior e posterior com remetentes e horários.
  * Histórico de ações e notas dos responsáveis.

### 2.4. `EscalonamentoService` (`src/services/escalonamento_service.py`)
* Tarefa assíncrona executada a cada 60 s no loop de eventos do FastAPI.
* Busca incidentes com criticidade $\ge 0.85$, status `DETECTADO`, `escalonado = False` e `created_at < (agora - 15 minutos)`.
* Emite evento `incident.escalated` para responsáveis secundários e marca `escalonado = True`.

---

## 3. Critérios de Aceitação da Etapa
- [ ] O fluxo de predição atende 100% dos requisitos de negócio (gravação seletiva, contexto e eventos).
- [ ] Exclusão LGPD remove dados em cascata sem deixar registros órfãos.
- [ ] O PDF gerado é válido, não corrompe caracteres e exibe a cadeia de integridade SHA-256.
