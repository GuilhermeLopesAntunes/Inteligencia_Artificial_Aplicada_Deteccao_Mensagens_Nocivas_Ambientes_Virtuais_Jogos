# Frontend - Etapa 3: Detalhe do Incidente e Ações do Responsável

> **Objetivo:** Implementar a tela detalhada de incidente, visualização de contexto conversacional, fluxo de transição de status, geração de PDF e exclusão LGPD.

---

## 1. Arquivos a Criar/Atualizar
- `frontend/lib/screens/incident_detail_screen.dart`
- `frontend/lib/widgets/context_chat_bubble.dart`
- `frontend/lib/widgets/status_timeline.dart`
- `frontend/lib/widgets/status_transition_dialog.dart`
- `frontend/lib/widgets/confirm_delete_dialog.dart`

---

## 2. Detalhamento dos Componentes

### 2.1. Tela de Detalhe do Incidente (`lib/screens/incident_detail_screen.dart`)
* **Ciclo de Abertura:**
  * Ao carregar a tela, dispara automaticamente a chamada `POST /incidents/{id}/view` (mudando status de `DETECTADO` para `VISUALIZADO` no backend).
* **Seções da Interface:**
  1. **Cabeçalho de Classificação:**
     * Categoria de risco (*"Possível Ciberbullying"* ou *"Link Suspeito"*).
     * Percentual de confiança formatado (ex: "93% de confiança do modelo").
     * Papel do dependente em destaque.
     * Alerta visual caso `integrity_mismatch == true` (*"Aviso: Divergência detectada na integridade da mensagem original"*).
  2. **Balão da Mensagem Principal:**
     * Texto completo recebido com fundo destacado (vermelho/laranja suave).
     * Identificador do remetente e horário UTC/Local.
  3. **Contexto Conversacional:**
     * Exibição em formato de chat das até 3 mensagens anteriores (`context_before`) e até 3 posteriores (`context_after`).
  4. **Linha do Tempo de Status:**
     * Timeline visual das alterações de status com datas, responsável responsável pela mudança e notas registradas.
  5. **Barra de Ações Fixa Inferior:**
     * Botão principal: "Atualizar Status".
     * Botão secundário: "Exportar Relatório (PDF)".
     * Botão de exclusão (ícone de lixeira): visível **apenas se `is_primary == true`**.

### 2.2. Modal de Transição de Status (`lib/widgets/status_transition_dialog.dart`)
* Lista as opções com base no array `allowed_transitions` retornado pela API.
* Mapeia os códigos para textos amigáveis em português:
  * `EM_ANALISE` $\rightarrow$ *"Em análise"*
  * `CONVERSADO_COM_FILHO` $\rightarrow$ *"Conversei com meu filho"*
  * `ENCAMINHADO_A_ESCOLA` $\rightarrow$ *"Encaminhado à escola"*
  * `FALSO_POSITIVO` $\rightarrow$ *"Alarme falso (mensagem inofensiva)"*
  * `RESOLVIDO` $\rightarrow$ *"Incidente resolvido"*
* Campo de texto opcional para nota/observação do responsável (obrigatório/destacado se for *Alarme falso* para feedback de IA).

### 2.3. Ações Críticas (PDF e Exclusão)
* **Exportação de PDF:** Faz o download via `ApiService.downloadReportPdf()` e abre o visualizador nativo do Android usando o pacote `open_filex`.
* **Exclusão Definitiva (LGPD):** Exibe diálogo de confirmação com aviso explícito: *"Esta ação é permanente e removerá todas as mensagens e histórico associados deste incidente da base de dados."*

---

## 3. Critérios de Aceitação da Etapa
- [ ] Abertura do detalhe atualiza o status de `DETECTADO` para `VISUALIZADO`.
- [ ] A lista de transições permitidas respeita estritamente o retornado pelo backend.
- [ ] Diálogo de exclusão solicita confirmação e só é habilitado para guardiões primários.
- [ ] Relatório PDF é baixado e salvo no armazenamento local do dispositivo.
