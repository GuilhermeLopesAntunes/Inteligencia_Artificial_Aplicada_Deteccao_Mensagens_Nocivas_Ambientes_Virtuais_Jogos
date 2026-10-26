# Regras de Negócio

Fonte única das regras de classificação, contexto, status e permissões. Se outro documento divergir, **este prevalece**.

## 1. Probabilidade e rótulo

- O modelo devolve `P` = probabilidade da classe `nocivo` (softmax), entre 0,0 e 1,0.
- O campo `confidence` da API é **sempre `P`**, nunca a confiança do rótulo previsto.
- O campo `label` é a saída bruta do modelo no limiar fixo 0,50: `nocivo` se `P >= 0.50`, senão `normal`. Ele **não** considera o limiar calibrado nem o Modo Gamer.
- A decisão de negócio está nos campos `category` e `action_required` (seção 3). Exemplo: `P = 0.60` em sala de jogo → `label = "nocivo"`, mas `category = "SEGURO"`.

## 2. Limiares

| Limiar | Valor | Quem altera |
| :--- | :--- | :--- |
| Crítico | **0,85 fixo** | Ninguém |
| Comum calibrado (`limiar_comum` do `Dependente`) | Padrão **0,50**; faixa permitida **0,50 a 0,84** | Só o responsável primário |
| Comum efetivo `L` em `room_type = "conversa"` | `L = limiar_comum` | Calculado |
| Comum efetivo `L` em `room_type = "jogo"` (Modo Gamer) | `L = max(limiar_comum, 0.70)` | Calculado |

O limiar é armazenado no **Dependente**, não no Responsável.

## 3. Tabela de decisão

Avaliar **nesta ordem**, parando na primeira linha verdadeira. `has_link` vem do `DetectorDeLinks` (regex `https?://\S+|www\.\S+`, sem distinção de maiúsculas).

| # | Condição | `category` | `action_required` | Tipo |
| :-: | :--- | :--- | :--- | :--- |
| 1 | `P >= 0.85` | `CIBERBULLYING` | `ALERT_PARENT_CRITICAL` | Incidente crítico |
| 2 | `L <= P < 0.85` | `CIBERBULLYING` | `LOG_INCIDENT` | Incidente comum |
| 3 | `P < L` e `has_link` | `LINK_SUSPEITO` | `LOG_INCIDENT` | Incidente comum |
| 4 | `P < L` e não `has_link` | `SEGURO` | `NONE` | Mensagem segura |

- Link **sempre** gera incidente, inclusive em sala de jogo (a heurística não tem probabilidade).
- Nas linhas 1 e 2, `has_link` continua sendo informado na resposta, mas a categoria é `CIBERBULLYING`.
- Essa lógica fica em uma função pura do domínio (`AvaliadorDecisaoRisco` em `src/domain/rules.py`), sem dependência de modelo ou banco.

## 4. Papel do menor (`detected_role`)

Derivado dos metadados enviados pelo simulador, sem uso do modelo:

| Condição | Papel |
| :--- | :--- |
| `is_from_minor = true` | `EMISSOR` |
| `is_from_minor = false` e `is_direct = true` | `VITIMA` |
| `is_from_minor = false` e `is_direct = false` | `ESPECTADOR` |

Os cards pedagógicos (UC-08) usam `VITIMA` ou `EMISSOR`; `ESPECTADOR` usa o texto de `VITIMA`.

## 5. Integridade (SHA-256)

- O simulador calcula o SHA-256 (hex minúsculo) do texto **exatamente como enviado**, em UTF-8, antes de qualquer normalização.
- O backend recalcula sobre o campo `text` recebido, também antes de normalizar, e compara: `sha256_match = (calculado == message_hash.lower())`.
- Hash divergente **não** bloqueia o processamento. Se a mensagem virar incidente, grava `integridade_divergente = true`, e o relatório PDF exibe isso.

## 6. Normalização

- Remove espaços redundantes e normaliza quebras de linha.
- **Não** remove stopwords e **não** altera emojis (o modelo foi treinado assim).
- Truncamento fica a cargo do tokenizer: `truncation=True, max_length=512`.
- Texto vazio ou só com espaços → HTTP 400.

## 7. Contexto do incidente

**Buffer (memória, por `conversation_id`):** mantém as últimas 3 mensagens recebidas, inclusive as seguras. Nunca é gravado em disco e se perde ao reiniciar (aceitável).

**Contexto anterior:** ao criar um incidente, copiar as até 3 mensagens que estavam no buffer **antes** da mensagem atual.

**Contexto posterior:** cada incidente criado fica "aberto para contexto" em memória. Toda nova mensagem da mesma conversa é anexada como contexto posterior a cada incidente aberto que tenha **menos de 3 posteriores** e tenha sido criado **há no máximo 10 minutos**. Ao atingir 3 posteriores ou 10 minutos, o incidente sai da lista.

**Ordem de processamento de uma mensagem:**
1. Anexar a mensagem como posterior aos incidentes abertos da conversa.
2. Classificar a mensagem.
3. Se for incidente, criar com o contexto anterior e abrir para posteriores.
4. Adicionar a mensagem ao buffer.

Uma mensagem pode ser posterior de um incidente anterior **e** gerar seu próprio incidente.

## 8. Persistência

- Persistir: incidentes, mensagem principal, contexto anterior e posterior, histórico de status, feedback.
- **Não persistir** mensagens seguras. Para elas, incrementar apenas um contador agregado por dependente.

## 9. Ciclo de vida do incidente

Todo incidente nasce `DETECTADO`.

| De | Para | Quem |
| :--- | :--- | :--- |
| `DETECTADO` | `VISUALIZADO` | Sistema, quando um responsável abre o incidente |
| `VISUALIZADO` | `EM_ANALISE`, `FALSO_POSITIVO` | Responsável |
| `EM_ANALISE` | `CONVERSADO_COM_FILHO`, `ENCAMINHADO_A_ESCOLA`, `FALSO_POSITIVO`, `RESOLVIDO` | Responsável |
| `CONVERSADO_COM_FILHO` | `RESOLVIDO` | Responsável |
| `ENCAMINHADO_A_ESCOLA` | `RESOLVIDO` | Responsável |

- Qualquer outra transição é rejeitada (HTTP 409).
- `DETECTADO` e `VISUALIZADO` nunca são aceitos como destino manual.
- `FALSO_POSITIVO` e `RESOLVIDO` são estados finais.
- Toda transição grava uma entrada no histórico: estado anterior, novo, nota opcional, responsável e data/hora UTC.
- Ao marcar `FALSO_POSITIVO`, a nota é guardada como feedback para retreino (UC-07).

## 10. Notificações

| Evento | Destinatários | Som |
| :--- | :--- | :--- |
| Qualquer incidente criado (`incident.created`) | Todos os responsáveis do dependente | Não |
| Incidente crítico (`incident.critical`) | **Só o responsável primário** | Sim |
| Escalonamento (`incident.escalated`) | Responsáveis **não primários** do dependente | Sim |
| Mudança de status ou exclusão (`incident.updated`, `incident.deleted`) | Todos os responsáveis do dependente | Não |

Entrega via WebSocket, apenas para quem estiver conectado (app aberto). Não há fila de reenvio: ao abrir, o app recarrega o feed pela API REST.

## 11. Escalonamento (UC-12, só se sobrar tempo)

- Tarefa periódica a cada 60 s.
- Seleciona incidentes **críticos** com status `DETECTADO`, `escalonado = false` e criados há mais de 15 minutos.
- Envia `incident.escalated` aos responsáveis não primários e marca `escalonado = true`. **Não** altera o status.
- Se o dependente não tiver responsáveis secundários, apenas marca `escalonado = true`.
- Como o estado fica no banco, o escalonamento sobrevive a reinícios.

## 12. Permissões

| Ação | Quem pode |
| :--- | :--- |
| Ver incidentes, abrir, mudar status, exportar PDF, marcar falso positivo | Qualquer responsável vinculado ao dependente |
| Calibrar limiar, gerar código de convite, excluir incidente | **Só o responsável primário** |

Acesso a um dependente ou incidente não vinculado ao usuário → HTTP 404 (não revelar que existe). Ação permitida só ao primário feita por secundário → HTTP 403.

## 13. Co-parentalidade (UC-06, só se sobrar tempo)

- O primário gera um código de convite alfanumérico de 8 caracteres, válido por 48 h e de uso único.
- O novo responsável se cadastra informando o código e é vinculado ao dependente como **não primário**.
- Cada dependente tem exatamente um responsável primário.

## 14. Exclusão (LGPD, UC-17)

Exclusão **real** (sem soft delete): remove o incidente, suas mensagens de contexto, o histórico de status e o feedback associados.
