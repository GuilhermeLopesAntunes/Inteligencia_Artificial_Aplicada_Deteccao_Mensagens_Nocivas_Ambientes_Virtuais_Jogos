# Estrutura e Arquitetura do Projeto: Project Artemis

> **Sistema de Controle Parental Inteligente com Detecção de Ciberbullying via BERTimbau**  
> **Fonte de Verdade:** `.agents/regras-de-negocio.md` (regras) e `.agents/contrato-api.md` (API); demais specs em `.agents/`

Este documento detalha o mapeamento completo da estrutura do repositório, servindo como especificação base e guia arquitetural para o desenvolvimento e evolução do software.

---

## 1. Visão Geral do Sistema

O **Project Artemis** é uma solução de **Controle Parental Inteligente** baseada em **Processamento de Linguagem Natural (PLN)** para detecção automatizada de ciberbullying em mensagens de texto.

O produto principal é o **Aplicativo de Controle Parental (Flutter / Mobile Android)**, voltado aos pais e responsáveis, que recebe notificações em tempo real via WebSocket e permite gerenciar incidentes, visualizar históricos, calibrar sensibilidade e gerar relatórios probatórios com SHA-256.

As mensagens analisadas não são capturadas diretamente de dispositivos reais (trabalho futuro), mas sim originadas a partir de um **Simulador de Chat Web independente (HTML/CSS/JS puro)**. O backend em **FastAPI** executa a inferência em **CPU** utilizando o modelo **BERTimbau** (`GuilhermeLA/modelo-tcc-final`), combinado com uma **heurística de detecção de links externos (`DetectorDeLinks`)**.

```
+---------------------+       POST /api/v1/predict        +----------------------+
|  Simulador de Chat  |  -------------------------------> |   Backend FastAPI    |
|  (HTML/JS separado) |   texto + metadados + hash SHA256 |  BERTimbau (CPU)     |
+---------------------+                                   |  + DetectorDeLinks   |
                                                          |  + Observer          |
+---------------------+     WebSocket (notificações)      |  + SQLite (data/)    |
| App Artemis Flutter | <-------------------------------- |                      |
| (Mobile / Android)  |                                   +----------+-----------+
+---------------------+                                              |
                                                     Volume compartilhado /models
                                                                     |
                                                          +----------v-----------+
                                                          | scripts (Jupyter)    |
                                                          | profile: training    |
                                                          +----------------------+
```

---

## 2. Topologia de Diretórios

```
Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos/
├── docker-compose.yml              # Orquestração dos serviços (Backend, Simulator, Scripts [profile: training])
├── README.md                       # Apresentação do projeto e instruções de execução
├── .gitignore                      # Regras de exclusão de artefatos temporários e pesos de ML
│
├── simulator/                      # Simulador de Chat Web (Projeto Separado em HTML/JS)
│   ├── Dockerfile                  # Servidor Web estático Nginx para o simulador
│   ├── index.html                  # Interface do chat com seleção de dependente, sala e remetente
│   ├── style.css                   # Estilização do simulador
│   └── app.js                      # Lógica do chat, cálculo do SHA-256 via Web Crypto API e envio HTTP
│
├── backend/                        # API de Inferência e Lógica de Negócio (Python / FastAPI)
│   ├── Dockerfile                  # Imagem base Python 3.11-slim com Uvicorn (CPU)
│   ├── requirements.txt            # Dependências da API (FastAPI, PyTorch CPU, Transformers, SQLAlchemy)
│   ├── data/                       # Volume persistente do banco SQLite (/app/data/artemis.db)
│   ├── src/
│   │   ├── main.py                 # Ponto de entrada da aplicação FastAPI
│   │   ├── api/                    # Controladores REST, schemas Pydantic e WebSocket Gateway
│   │   │   ├── v1/                 # Endpoints versionados (/predict, /incidents, /auth, /config)
│   │   │   └── websocket.py        # Handler de conexões WebSocket para o App Flutter
│   │   ├── services/               # Serviços de aplicação
│   │   │   ├── analise_service.py  # Orquestração de inferência e buffer de contexto
│   │   │   ├── gestao_incidente_service.py # Transições de status e exclusão
│   │   │   ├── relatorio_service.py # Geração de relatório PDF com hash SHA-256
│   │   │   └── escalonamento_service.py # Scheduler de escalonamento (15 min)
│   │   ├── domain/                 # Entidades, enums e regras de domínio puras
│   │   │   ├── entities.py         # Incidente, Mensagem, Responsavel, Dependente
│   │   │   ├── enums.py            # StatusIncidente, CategoriaAmeaca, PapelMenor, AcaoRequerida
│   │   │   └── rules.py            # Regras de limiar efetivo (0.50 a 0.84 / Modo Gamer 0.70 / Crítico 0.85)
│   │   └── infrastructure/         # Adaptadores técnicos e infraestrutura
│   │       ├── bertimbau_engine.py # Strategy de checkpoints BERTimbau e Lazy Proxy
│   │       ├── link_detector.py    # DetectorDeLinks (sinal booleano de URLs)
│   │       ├── in_memory_buffer.py # Buffer circular de 3 mensagens em memória
│   │       └── database.py         # Conexão SQLAlchemy e repositórios
│   └── tests/
│       ├── unit/                   # Testes unitários rápidos (BVA, normalização, mocks)
│       └── integration/            # Testes de integração de rotas e banco em memória
│
├── frontend/                       # Aplicativo de Controle Parental (Flutter / Mobile Android)
│   ├── pubspec.yaml                # Dependências Dart/Flutter
│   ├── pubspec.lock                # Lockfile de dependências
│   ├── analysis_options.yaml       # Regras de linter do Flutter
│   ├── lib/
│   │   ├── main.dart               # Ponto de entrada do App Parental Android
│   │   ├── models/                 # Modelos de dados (Incident, Dependent, Guardian)
│   │   ├── services/               # Cliente HTTP REST e cliente WebSocket para notificações locais
│   │   └── screens/                # Telas: Login, Feed de Incidentes, Detalhes, Status, Calibração
│   └── test/
│       └── widget_test.dart        # Testes de widgets Flutter
│
├── models/                         # Volume compartilhado para pesos do BERTimbau
│   └── modelo_tcc_final/           # Arquivos safetensors, tokenizer e config do modelo
│
└── scripts/                        # Engenharia de Dados e Treinamento de Modelos
    ├── Dockerfile                  # Imagem JupyterLab (perfil docker-compose: training)
    ├── requirements.txt            # Dependências de ML (Transformers, Datasets, PyTorch, Pandas)
    └── datasets/                   # Datasets brutos e notebooks de fine-tuning
```

---

## 3. Detalhamento dos Componentes

### 3.1. Simulador de Chat (`/simulator`)
* **Stack**: HTML5, CSS3, JavaScript Vanilla.
* **Porta**: `3000` (acessado via `http://localhost:3000` para disponibilidade da Web Crypto API).
* **Responsabilidade**:
  * Emular salas de conversa ("jogo" ou "conversa").
  * Selecionar o dependente cadastrado (`dependent_id`).
  * Permitir alternar o remetente da mensagem (`is_from_minor: true/false`).
  * Calcular o hash SHA-256 no navegador do cliente usando a **Web Crypto API** (`crypto.subtle.digest`).
  * Enviar as mensagens via `POST /api/v1/predict` para análise imediata.

### 3.2. Backend (`/backend`)
* **Stack**: Python 3.11, FastAPI, Uvicorn, PyTorch (CPU), Transformers, SQLAlchemy (SQLite).
* **Porta**: `8000` (escutando em `0.0.0.0`).
* **Banco de Dados**: `DATABASE_URL=sqlite:////app/data/artemis.db` (armazenado no volume montado `./backend/data:/app/data`).
* **Responsabilidade**:
  * Autenticação via JWT e gerenciamento de responsáveis e dependentes.
  * Receber requisições HTTP do simulador contendo texto, hash SHA-256, `dependent_id` e metadados.
  * Manter buffer circular em memória das últimas 3 mensagens da conversa.
  * Executar a inferência neural via BERTimbau em CPU e detecção de links (`DetectorDeLinks`).
  * Determinar o papel do menor (`VITIMA`, `EMISSOR`, `ESPECTADOR`) com base nos metadados.
  * Classificar e persistir somente mensagens que constituam incidentes ($P(\text{nocivo}) \ge L$ ou link suspeito).
  * Anexar até 3 mensagens posteriores da mesma conversa (janela de até 10 minutos).
  * Notificar o aplicativo Flutter via WebSocket em incidentes críticos ($P(\text{nocivo}) \ge 0.85$).
  * Gerar relatórios PDF de incidentes e permitir exclusão definitiva de registros pelo responsável primário.

### 3.3. Frontend App Parental (`/frontend`)
* **Stack**: Flutter 3.x / Dart (Mobile Android).
* **Execução**: Emulador Android (`http://10.0.2.2:8000`) ou aparelho físico via APK (IP da rede local).
* **Responsabilidade**:
  * Autenticação de guardiões com e-mail e senha.
  * Painel de Controle Parental para visualização de incidentes e histórico.
  * Recepção de alertas via WebSocket com som de notificação local quando o app estiver aberto.
  * Fluxo de resolução de incidentes com transições de status válidas.
  * Calibração do limiar comum ($0.50$ a $0.84$) pelo responsável primário.
  * Exportação de Relatório de Incidente com integridade SHA-256 e exclusão de incidentes (LGPD).

### 3.4. Scripts e Treinamento (`/scripts`)
* **Stack**: JupyterLab, PyTorch.
* **Execução**: Opcional, via perfil `docker compose --profile training up`.
* **Porta**: `8888`.
* **Responsabilidade**:
  * Treinamento e fine-tuning do modelo já concluídos, exportando artefatos para `./models`.

---

## 4. Orquestração de Ambientes (`docker-compose.yml`)

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: artemis_backend
    ports:
      - "8000:8000"
    environment:
      - APP_ENV=production
      - MODEL_DIR=/models/modelo_tcc_final
      - DATABASE_URL=sqlite:////app/data/artemis.db
    volumes:
      - ./models:/models:ro
      - ./backend/data:/app/data
    restart: unless-stopped

  simulator:
    build: ./simulator
    container_name: artemis_simulator
    ports:
      - "3000:80"
    restart: unless-stopped

  scripts:
    build: ./scripts
    container_name: artemis_scripts
    profiles: ["training"]
    ports:
      - "8888:8888"
    volumes:
      - ./models:/models
      - ./scripts/datasets:/app/datasets
```

---

## 5. Priorização de Escopo e Cronograma do MVP

Com base no prazo de TCC individual (até 20/10/2026), o escopo foi estritamente priorizado:

| Prioridade | Funcionalidades / Casos de Uso |
| :--- | :--- |
| **Essencial (MVP)** | UC-18 (Login JWT), UC-01/10/11/13 (Análise de Texto e Limiares), UC-02 (Alerta Crítico WebSocket), UC-09 (Gestão de Status), UC-03 (Calibração 0.50-0.84), UC-04 (Relatório PDF), UC-17 (Exclusão LGPD). |
| **Se sobrar tempo** | UC-06 + UC-12 (Co-parentalidade via código e Escalonamento 15 min), UC-07 (Feedback Falso Positivo), UC-08 (Cards de Diálogo CNV). |
| **Trabalho Futuro** | UC-14 (Painel Analítico), UC-15 (Acessibilidade), UC-16 (Sumário Mensal), Push Notifications reais (FCM com app fechado), Captura real no Android, Multiclasse, SHAP. |
| **Removido** | UC-05 (Modo Plantão). |
