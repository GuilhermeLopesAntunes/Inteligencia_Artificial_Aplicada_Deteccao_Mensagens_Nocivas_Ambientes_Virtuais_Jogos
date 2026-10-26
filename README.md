# Project Artemis: Sistema Inteligente de Controle Parental para Detecção de Ciberbullying em Ambientes Virtuais de Jogos

> **Trabalho de Conclusão de Curso (TCC) — Universidade Estadual de Montes Claros (Unimontes)**  
> **Área:** Inteligência Artificial Aplicada, Engenharia de Software e Segurança Digital Infantil  
> **Modelo Neural:** BERTimbau Base (`GuilhermeLA/modelo-tcc-final`) executado em **CPU**  
> **Branch de Trabalho do MVP:** `feature/mvp-tcc-artemis`

---

## 🎯 Visão Geral

O **Project Artemis** é uma solução de controle parental e segurança digital concebida para identificar conteúdos tóxicos, ofensas graves e ciberbullying em mensagens trocadas em chats de jogos eletrônicos e plataformas digitais.

Diferente de abordagens invasivas de monitoramento contínuo (vigilância total de tela ou espionagem de digitação), o Artemis opera sob preceitos rígidos de **Privacidade por Design (Privacy by Design / LGPD)**:
1. **Não Retenção de Mensagens Seguras:** Mensagens rotuladas como seguras pela inteligência artificial são imediatamente descartadas da persistência em disco; retêm-se apenas contadores agregados e um buffer circular volátil em memória (últimas 3 mensagens).
2. **Triagem Híbrida e Adaptativa:** Combina inferência neural via Processamento de Linguagem Natural (Transformers/BERTimbau) com heurística determinística para detecção de links maliciosos (`DetectorDeLinks`).
3. **Modo Gamer Inteligente:** Ajusta dinamicamente a sensibilidade de classificação em salas de jogos virtuais (`room_type = "jogo"`), elevando o limiar de tolerância para gírias e provocações competitivas comuns ($L = \max(\text{limiar\_calibrado}, 0.70)$), evitando a sobrecarga de falsos alarmes para os pais.
4. **Cadeia de Custódia Probatória (SHA-256):** Garante a integridade pericial de mensagens que configuram incidentes, computando o hash criptográfico na origem (navegador) e validando no backend para emissão de relatórios em PDF com valor probatório.
5. **Comunicação em Tempo Real:** Alertas críticos ($P(\text{nocivo}) \ge 0.85$) são disparados imediatamente via WebSocket para o smartphone do responsável com latência ponta a ponta $\le 2,0$ segundos.

---

## 🏗️ Arquitetura e Pilares do Projeto

O repositório é organizado no formato **monorepo modular**:

```
.
├── backend/            # API REST + WebSocket em Python (FastAPI, PyTorch CPU, SQLAlchemy)
├── frontend/           # App Mobile Android em Flutter (Clean Architecture, Provider/Riverpod)
├── simulator/          # Simulador de Chat Web (HTML5/CSS3/JS puro com Web Crypto SHA-256)
├── scripts/            # Engenharia de dados, notebooks de treino e fine-tuning do BERTimbau
├── docs/               # Documentação técnica detalhada, referências de API e material da banca
├── docker-compose.yml  # Orquestração do Backend (:8000) e do Simulador (:3000)
└── PROJECT.md          # Especificação mestra de requisitos, contratos e marcos
```

---

## 📋 Pré-requisitos de Instalação

Para reproduzir, executar e testar todo o ecossistema em ambiente de desenvolvimento local (Windows/Linux/macOS), certifique-se de possuir instalado:

| Ferramenta | Versão Mínima | Finalidade |
| :--- | :--- | :--- |
| **Docker Desktop** | 24.0+ (com Compose v2) | Execução orquestrada do Backend e do Simulador de Chat em contêineres |
| **Python** | 3.11+ | Execução nativa do backend, suítes de teste `pytest` e scripts |
| **Flutter SDK** | 3.19+ | Compilação e execução do aplicativo Android e suíte de testes de widgets |
| **Android Studio / SDK** | API Level 33+ | Emulador Android (AVD) para execução do aplicativo móvel com notificações |
| **Git** | 2.40+ | Controle de versão do repositório |

*(Opcional: Hugging Face CLI `huggingface_hub` para download do modelo de 440MB para produção local; os testes automatizados utilizam a factory `MockStrategy` e não exigem download dos tensores).*

---

## 🚀 1. Executando Backend + Simulador em 1 Único Comando

A maneira mais rápida e consistente de inicializar o ambiente integrado é através do **Docker Compose**:

### Passo 1: Clonar o Repositório e Acessar a Branch

```bash
git clone https://github.com/GuilhermeLA/Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos.git
cd Inteligencia_Artificial_Aplicada_Deteccao_Mensagens_Nocivas_Ambientes_Virtuais_Jogos
git checkout feature/mvp-tcc-artemis
```

### Passo 2: Configurar as Variáveis de Ambiente

Copie o arquivo de exemplo `.env.example` para `.env`:

```bash
cp .env.example .env
```

*(No Windows PowerShell: `Copy-Item .env.example .env`)*

O arquivo `.env` conterá a chave de assinatura de tokens:
```ini
JWT_SECRET=artemis-super-segredo-de-desenvolvimento-tcc-2026
```

### Passo 3: Subir os Contêineres

Execute o comando Compose:

```bash
docker compose up --build
```

O Docker inicializará automaticamente:
* **Backend FastAPI:** acessível em `http://localhost:8000`
  * Documentação interativa Swagger/OpenAPI: `http://localhost:8000/docs`
  * Rota de saúde: `http://localhost:8000/`
  * Gateway WebSocket: `ws://localhost:8000/ws?token=<jwt>`
* **Simulador de Chat Web:** acessível no navegador em `http://localhost:3000`

---

## 📱 2. Executando o Aplicativo Móvel (Flutter Android)

O app dos responsáveis foi desenvolvido com suporte a **Modo Dual**: opera totalmente desacoplado (Modo Mock offline) ou conectado à API real.

### Execução no Emulador Android

1. Abra o emulador Android através do Android Studio.
2. Navegue até o diretório do frontend:
   ```bash
   cd frontend
   flutter pub get
   ```

#### Opção A: Modo API Real (Conectado ao Backend)
O Android Emulator mapeia o `localhost` da máquina hospedeira no IP especial `10.0.2.2`. Execute:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### Opção B: Modo Mock (100% Desacoplado / Offline)
Caso deseje navegar por todas as telas, experimentar os cards pedagógicos, testar o fluxo de calibração e simular o recebimento de notificações sem necessidade do backend ou Docker:

```bash
flutter run
```

### Execução em Dispositivo Físico Android (via Cabo USB)

Com a Depuração USB ativada no celular:
```bash
adb reverse tcp:8000 tcp:8000
cd frontend
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### Credenciais de Demonstração (Seed)

| Campo | Valor de Teste |
| :--- | :--- |
| **E-mail do Responsável Primário:** | `maria@exemplo.com` |
| **Senha:** | `senha123` |
| **Dependentes Cadastrados:** | `Lucas` (`dep-001`, limiar 0.50), `Ana` (`dep-002`, limiar 0.50) |

---

## 💬 3. Testando o Simulador de Chat Web de Forma Independente

O simulador de chat reproduz com fidelidade um ambiente de jogo/chat e pode ser testado diretamente no navegador em `http://localhost:3000` (quando rodando via Docker) ou de forma estática standalone:

```bash
cd simulator
python -m http.server 3000
```

### Recursos Nativos do Simulador:
1. **Cálculo de SHA-256 no Cliente:** O navegador utiliza a `Web Crypto API` (`crypto.subtle.digest("SHA-256", ...)`) para gerar o hash hexadecimal idêntico ao comando `sha256sum` do sistema operacional.
2. **Metadados de Contexto:** Permite alternar o tipo de sala (`conversa` vs. `jogo`), selecionar o dependente e definir se a mensagem partiu do menor (`is_from_minor`) ou foi direta (`is_direct`).
3. **5 Presets de Demonstração Rápida:**
   - **Preset 1 (Mensagem Segura):** *"Oi, vamos jogar depois da aula?"* $\rightarrow$ Classificada como `SEGURO`, contador incrementado, nenhum incidente salvo.
   - **Preset 2 (Modo Gamer):** *"Você joga muito mal, sai logo do time"* em sala de jogo $\rightarrow$ O limiar sobe para $0.70$, evitando falso alarme.
   - **Preset 3 (Link Suspeito):** *"Baixa as skins grátis aqui: http://jogos-hack.xyz"* $\rightarrow$ Detector determinístico aciona `LINK_SUSPEITO` e `LOG_INCIDENT`.
   - **Preset 4 (Ciberbullying Crítico):** *"Você é um inútil, ninguém gosta de você, devia sumir"* $\rightarrow$ $P \ge 0.85$, dispara alerta crítico com som imediato no app.
   - **Preset 5 (Contexto Posterior):** Envio subsequente na mesma conversa $\rightarrow$ Capturado automaticamente no histórico conversacional do incidente aberto.

---

## 🧪 4. Executando as Suítes de Testes Automatizados

O projeto adota a pirâmide de testes recomendada pela Engenharia de Software Moderna (Unidade, Integração e BVA).

### 4.1. Testes do Backend (Python / Pytest)

Os testes utilizam o ambiente isolado de teste (`APP_ENV=testing`), ativando a fábrica `MockClassificadorFactory` para execução em milissegundos sem necessidade de tensores pesados.

```bash
cd backend

# 1. Criar e ativar ambiente virtual (opcional se não usar Docker)
python -m venv venv
# No Windows:
.\venv\Scripts\activate
# No Linux/macOS:
source venv/bin/activate

# 2. Instalar dependências
pip install -r requirements.txt

# 3. Rodar a suíte completa de testes
APP_ENV=testing pytest -v
```

*(No Windows PowerShell sem o comando `APP_ENV=testing` inline):*
```powershell
$env:APP_ENV="testing"; pytest -v; Remove-Item Env:\APP_ENV
```

#### O que é validado nos testes do Backend:
* **Análise de Valor Limite (BVA):** Cobertura de todas as fronteiras numéricas ($0.00$, $0.499$, $0.500$, $0.650$, Modo Gamer $0.700$, $0.849$, Crítico $0.850$, $1.000$).
* **Detector de Links:** Regex determinística para URLs e domínios.
* **Máquina de Estados de Incidentes:** Transições válidas e rejeição estrita (HTTP 409) de transições proibidas.
* **Buffer Temporal Volátil:** Janela de 3 mensagens anteriores e anexação de até 3 mensagens posteriores em até 10 minutos.
* **Relatório PDF e Validação SHA-256:** Atestação de integridade probatória.
* **Exclusão Real LGPD:** Cascade delete de histórico, contexto e incidentes.

### 4.2. Testes do Frontend (Flutter)

```bash
cd frontend

# Análise estática de código (sem erros ou lints graves)
flutter analyze

# Execução de todos os testes de unidade e widgets
flutter test

# Verificação de build do APK de debug
flutter build apk --debug
```

---

## 📂 5. Estrutura Detalhada do Repositório

```
.
├── backend/
│   ├── src/
│   │   ├── api/             # Camada de Apresentação (Rotas FastAPI e WebSocket Gateway)
│   │   ├── domain/          # Regras Puras de Negócio (AvaliadorDecisaoRisco, Máquina de Estados)
│   │   ├── infrastructure/  # Model Loader, PyTorch Lazy Proxy, ReportLab PDF, SQLAlchemy SQLite
│   │   ├── services/        # Orquestração de Mensagens, Auth JWT, Gestão de Incidentes
│   │   ├── main.py          # Ponto de entrada FastAPI (Uvicorn boot < 2.0s)
│   │   └── seed.py          # Carga de dados iniciais para testes e demonstrações
│   ├── tests/               # Testes automatizados BVA, unidade e integração com Pytest
│   ├── Dockerfile           # Imagem conteinerizada do backend
│   └── requirements.txt     # Dependências Python (FastAPI, PyTorch CPU, Transformers, ReportLab)
│
├── frontend/
│   ├── lib/
│   │   ├── data/            # Repositórios HTTP, WebSocket e implementações Mock
│   │   ├── domain/          # Entidades e Value Objects em Dart espelhados da API
│   │   ├── presentation/    # Telas (Login, Feed de Incidentes, Detalhes, Slider de Limiar)
│   │   └── main.dart        # Inicialização do aplicativo Flutter Android
│   ├── test/                # Testes de unidade e testes de widgets do Flutter
│   └── pubspec.yaml         # Dependências do app (riverpod, http, web_socket_channel, etc.)
│
├── simulator/
│   ├── index.html           # Interface visual responsiva do chat de jogos
│   ├── style.css            # Estilização moderna temática gamer (Discord/Steam inspired)
│   ├── app.js               # Lógica de chat, presets e cálculo Web Crypto SHA-256
│   └── Dockerfile           # Nginx servindo os artefatos estáticos na porta 3000
│
├── docs/
│   ├── api_reference.md     # Contrato formal de todos os 14 endpoints REST e WebSocket
│   ├── architecture.md      # Clean Architecture, Ports & Adapters, Padrões GoF detalhados
│   └── defesa_tcc/
│       ├── roteiro_apresentacao_10min.md  # Script passo a passo para a banca de 10 minutos
│       └── metricas_avaliacao.md          # Tabela e template de métricas de latência e precisão
│
├── docker-compose.yml       # Orquestração de contêineres para backend e simulador
└── PROJECT.md               # Especificação e inventário de requisitos do projeto
```

---

## 📚 6. Documentação Técnica Complementar

Consulte os documentos especializados na pasta [`docs/`](docs/):

1. **[Referência da API (`docs/api_reference.md`)](docs/api_reference.md):**  
   Documentação técnica exaustiva de todas as 14 rotas REST (Autenticação, Predição, Gestão de Dependentes, Ciclo de Incidentes, Geração de Relatórios e Exclusão LGPD) e do canal bidirecional WebSocket com payloads JSON de exemplo.
2. **[Arquitetura e Padrões GoF (`docs/architecture.md`)](docs/architecture.md):**  
   Detalhamento da Clean Architecture (Ports & Adapters) e dos 5 padrões de projeto de software implementados:
   * **Virtual Proxy:** Lazy Loading do modelo BERTimbau garantindo boot do Uvicorn em $< 2,0$s.
   * **Strategy:** Isolamento dos checkpoints e algoritmos de inferência.
   * **Factory Method:** Alternância transparente entre ambiente de produção e testes rápidos.
   * **Observer:** Disseminação desacoplada de eventos em tempo real via WebSocket.
   * **Template Method:** Pipeline invariante de compilação, validação pericial e renderização de relatórios PDF.
3. **[Roteiro de Apresentação da Banca de 10 Minutos (`docs/defesa_tcc/roteiro_apresentacao_10min.md`)](docs/defesa_tcc/roteiro_apresentacao_10min.md):**  
   Guia prático e roteiro de demonstração ao vivo para a banca avaliadora com distribuição de tempo minuto a minuto.
4. **[Métricas de Avaliação e Desempenho (`docs/defesa_tcc/metricas_avaliacao.md`)](docs/defesa_tcc/metricas_avaliacao.md):**  
   Planilha e formulário metodológico para registro das latências de inferência em CPU ($\le 350$ms) e tempo de notificação ponta a ponta ($< 2,0$s).

---

## ⚖️ Licença e Responsabilidade Acadêmica

Este projeto foi desenvolvido para fins acadêmicos e científicos no âmbito do Curso de Ciência da Computação / Engenharia de Sistemas da Universidade Estadual de Montes Claros (Unimontes).  
Todo o tratamento de dados respeita as diretrizes da **Lei Geral de Proteção de Dados (Lei nº 13.709/2018 - LGPD)** e do **Estatuto da Criança e do Adolescente (ECA)**.
