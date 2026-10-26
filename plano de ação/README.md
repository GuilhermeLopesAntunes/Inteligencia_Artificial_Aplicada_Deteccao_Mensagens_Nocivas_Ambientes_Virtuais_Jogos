# Plano de Ação Mestre: Project Artemis

> **Sistema de Controle Parental Inteligente com Detecção de Ciberbullying via BERTimbau**  
> **Prazo Final de Entrega do MVP (TCC):** 20/10/2026  
> **Fontes de Verdade:** `.agents/regras-de-negocio.md`, `.agents/contrato-api.md`, `.agents/arquitetura.md`, `.agents/testes.md`

---

## 1. Diagnóstico do Estado Atual e Análise dos Componentes de IA

### 1.1. Artefatos de Inteligência Artificial e Engenharia de Dados (`scripts/datasets/`)
* **Datasets Analisados:**
  * `dataset_treino_enriquecido.csv`, `dataset_teste_puro.csv`: bases consolidadas e limpas para fine-tuning.
  * `manualjudgement.csv`, `LR_sexslang.csv`, `LR_listofinsults.csv`: datasets de ofensas, gírias e validação manual.
  * `dataset_parental_link.csv`, `dataset_parental_limpoStopWord.csv`: conjuntos de testes direcionados para heurísticas parentais e preservação de contexto.
  * Notebooks `DatasetAnalasys.ipynb` e `databaseTransformation.ipynb`: fluxos de análise exploratória, balanceamento de classes e pipelines de tokenização.
* **Modelo Neural:**
  * Checkpoint: `GuilhermeLA/modelo-tcc-final` (base BERTimbau / `neuralmind/bert-base-portuguese-cased` fine-tuned para classificação binária: `0 = normal`, `1 = nocivo`).
  * Tokenização: WordPiece com truncamento explícito em 512 tokens (`truncation=True, max_length=512`).
  * Inferência: **Exclusiva em CPU** com PyTorch (`torch.no_grad()`), calculando $P(\text{nocivo})$ via Softmax na saída dos logits.
* **Heurística Complementar:**
  * `DetectorDeLinks`: Expressão regular de alta performance (`https?://\S+|www\.\S+`, case-insensitive) que opera em tempo linear de forma determinística.
* **Mecanismo de Decisão e Risco:**
  * O `AvaliadorDecisaoRisco` (função de domínio pura) combina $P(\text{nocivo})$ e o sinal do link, aplicando o limiar calibrado pelo responsável primário ($0.50 \le L \le 0.84$), a elevação automática do **Modo Gamer** ($L = \max(L, 0.70)$ em `room_type = "jogo"`) e o limiar crítico fixo em $0.85$.

---

## 2. Estratégia de Desenvolvimento Desacoplado em 4 Eixos

Para permitir máxima agilidade, previsibilidade e isolamento de falhas, o projeto foi subdividido em 4 pilares autônomos que podem ser desenvolvidos e testados independentemente antes da conexão final:

```
plano de ação/
├── backend/       # Eixo 1: API REST, regras puras, IA em CPU, WS Gateway e SQLite
├── frontend/      # Eixo 2: App Flutter Android desacoplado com Mock Service e UI completa
├── simulador/     # Eixo 3: Simulador Web puro (HTML/JS) com Web Crypto SHA-256 e mock local
└── integracao/    # Eixo 4: Orquestração Docker, pontes reais, testes E2E e checklist MVP
```

---

## 3. Estrutura dos Módulos do Plano de Ação

| Módulo | Objetivo Principal | Dependência de Outros Módulos |
| :--- | :--- | :--- |
| [**1. Backend**](backend/README.md) | Implementar toda a arquitetura em camadas (Domain, Infrastructure, Services, API) com testes unitários BVA e SQLite em memória. | Nenhuma (utiliza mock de modelo em testes e executa via terminal). |
| [**2. Frontend**](frontend/README.md) | Desenvolver todas as 4 telas do MVP no Flutter usando `MockApiService` e `MockWebSocketService` para simular alertas e fluxos. | Nenhuma (opera 100% desacoplado via contratos Dart espelhados). |
| [**3. Simulador**](simulador/README.md) | Construir o simulador web em Vanilla JS/CSS com cálculo nativo de SHA-256 e modos de teste rápido. | Nenhuma (testável com mock em memória ou console log). |
| [**4. Integração**](integracao/README.md) | Conectar os serviços reais via Docker Compose, validar latência de CPU, WebSocket em tempo real e gerar relatórios PDF com SHA-256. | Requer conclusão dos eixos 1, 2 e 3. |

---

## 4. Cronograma Sugerido de Execução

```
+-----------------------------------------------------------------------------------+
| Semana 1: Desenvolvimento Independente dos 3 Módulos                              |
| - Backend: Domain + Infra + Services + Rotas REST + Mocks de Testes               |
| - Frontend: Modelos + Mocks + Telas (Login, Feed, Detalhes, Calibração)           |
| - Simulador: HTML/CSS + Web Crypto SHA-256 + Seletor de Dependente e Sala         |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Semana 2: Integração, WebSocket Real e Validação End-to-End                      |
| - Conexão do Simulador com Backend (/api/v1/predict)                              |
| - Troca de MockApiService por ApiServiceImpl no Flutter                           |
| - Testes de Notificação WebSocket e Geração de Relatório PDF                      |
| - Validação de Critérios de Aceitação e Entrega do TCC                            |
+-----------------------------------------------------------------------------------+
```

---

## 5. Próximos Passos Imediatos
1. Iniciar pelo **Eixo 1 (Backend)** implementando as regras de domínio puras e a infraestrutura de inferência.
2. Paralelamente ou em sequência, executar o **Eixo 2 (Frontend)** e o **Eixo 3 (Simulador)**.
3. Finalizar com o **Eixo 4 (Integração)**.
