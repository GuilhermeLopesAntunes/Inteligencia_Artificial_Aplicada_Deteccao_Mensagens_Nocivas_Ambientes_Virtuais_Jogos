# Integração - Etapa 4: Checklist Final do MVP para o TCC

> **Objetivo:** Auditar todos os requisitos, casos de uso e restrições técnicas para fechamento do escopo do Trabalho de Conclusão de Curso (TCC).

---

## 1. Tabela de Verificação de Casos de Uso do MVP

| ID | Caso de Uso | Componente Principal | Status / Verificação |
| :--- | :--- | :--- | :--- |
| **UC-18** | Autenticação Parental | Backend JWT / Flutter Login | [ ] Concluído |
| **UC-01** | Triagem Neural de Texto | Backend BERTimbau (CPU) / Simulador | [ ] Concluído |
| **UC-10** | Modo Gamer (Limiar 0.70) | Backend `AvaliadorDecisaoRisco` | [ ] Concluído |
| **UC-11** | Detecção de Links Externos | Backend `DetectorDeLinks` | [ ] Concluído |
| **UC-13** | Captura de Contexto (Antes/Depois) | Backend `InMemoryBuffer` | [ ] Concluído |
| **UC-02** | Alerta Crítico em Tempo Real | Backend WebSocket / Flutter Notificações | [ ] Concluído |
| **UC-09** | Gestão do Ciclo de Status | Backend API / Flutter Feed & Detalhe | [ ] Concluído |
| **UC-03** | Calibração de Sensibilidade | Backend API / Flutter Slider (0.50-0.84) | [ ] Concluído |
| **UC-04** | Relatório de Incidente com SHA-256 | Backend ReportLab / Flutter PDF Viewer | [ ] Concluído |
| **UC-17** | Exclusão de Incidente (LGPD) | Backend Cascade Delete / Flutter Modal | [ ] Concluído |

---

## 2. Requisitos Não-Funcionais e Desempenho

| RNF | Descrição | Meta do Projeto | Método de Validação |
| :--- | :--- | :--- | :--- |
| **RNF-11** | Latência de Inferência em CPU | $\le 350\text{ ms}$ (p95) | Medido no campo `inference_time_ms` retornado pela API. |
| **RNF-02** | Tempo de Notificação WebSocket | $\le 2,0\text{ s}$ | Tempo decorrido do clique no simulador até a notificação no celular. |
| **RNF-06** | Segurança de Senhas | Hash forte Argon2id | Verificação no repositório de autenticação. |
| **RNF-07** | Cadeia de Custódia SHA-256 | Validação ponta a ponta | Teste pericial no relatório PDF. |
| **RNF-08** | Privacidade / Não Retenção | Descarte de msgs seguras | Banco armazena apenas contadores agregados para textos seguros. |

---

## 3. Roteiro Sugerido para Apresentação da Banca Examinadora

1. **Introdução Teórica (2 min):** Apresentar a arquitetura em camadas, o modelo BERTimbau fine-tuned e a motivação do controle parental sem vigilância invasiva.
2. **Demonstração Prática do Simulador (3 min):**
   - Enviar mensagem segura (mostrar contador incrementando).
   - Enviar mensagem em sala de jogo (mostrar Modo Gamer prevenindo falso positivo).
   - Enviar link malicioso (mostrar atuação do detector determinístico).
3. **Demonstração do Alerta Crítico e Mobile App (3 min):**
   - Enviar mensagem de ciberbullying explícito ($P \ge 0.85$).
   - Exibir o celular recebendo a notificação instantânea com som.
   - Abrir o app, navegar pelo histórico conversacional e timeline.
   - Realizar transição de status para *"Conversei com meu filho"*.
4. **Auditoria e Encerramento (2 min):**
   - Exportar o relatório PDF pericial com integridade SHA-256.
   - Demonstrar a calibração de sensibilidade ($0.50$ a $0.84$).
   - Demonstrar a exclusão definitiva conforme preceitos da LGPD.
