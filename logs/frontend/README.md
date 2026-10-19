# Documentação Modular do Frontend e Fluxo de Registro/Vínculo — Project Artemis

> **Aplicativo Móvel de Controle Parental (Flutter) + Integração de Cadastro e Vínculo de Dependentes (Ideia 1 + Ideia 3)**

Este documento detalha os módulos implementados no **Frontend Flutter (`frontend/`)** e o fluxo completo de **Criação de Conta e Vínculo Responsável $\leftrightarrow$ Criança $\leftrightarrow$ Simulador Web**, estruturado por funcionalidades no padrão de commits semânticos `feat(nome-do-modulo)`.

---

## Sumário de Funcionalidades (`feat`)

1. [`feat(ui-theme-branding)` — Identidade Visual, Logos e Tema Claro (`#FFFFFF` / `#0E58A8`)](#1-featu-theme-branding--identidade-visual-logos-e-tema-claro-ffffff--0e58a8)
2. [`feat(auth-login-register)` — Telas de Splash, Login e Registro com Vínculo de Criança (Ideia 1)](#2-featauth-login-register--telas-de-splash-login-e-registro-com-vínculo-de-criança-ideia-1)
3. [`feat(backend-register-dependents)` — Endpoints de Registro, Vínculo N:N e Sincronização com Simulador (Ideia 3)](#3-featbackend-register-dependents--endpoints-de-registro-vínculo-nn-e-sincronização-com-simulador-ideia-3)
4. [`feat(feed-incident-management)` — Feed de Incidentes, Detalhes, Transição de Status e Exportação PDF](#4-featfeed-incident-management--feed-de-incidentes-detalhes-transição-de-status-e-exportação-pdf)
5. [`feat(settings-calibration)` — Calibração de Sensibilidade (0.50–0.84) e Adição de Novos Dependentes](#5-featsettings-calibration--calibração-de-sensibilidade-050084-e-adição-de-novos-dependentes)

---

## 1. `feat(ui-theme-branding)` — Identidade Visual, Logos e Tema Claro (`#FFFFFF` / `#0E58A8`)

### O que foi feito
Padronização visual de todo o aplicativo Flutter com fundo branco (`#FFFFFF`), botões e links na cor institucional azul (`#0E58A8`), ícones pretos (`Colors.black`), tipografia `YuGothic` nos títulos de autenticação e substituição do logotipo em todas as telas de entrada por `assets/LogoApp.svg` (e `assets/HorizontalLogoApp.svg` com `68px` de altura no cabeçalho `#242424` do Simulador Web).

### Arquivos deste módulo
- `frontend/assets/LogoApp.svg`
- `frontend/pubspec.yaml`
- `frontend/lib/main.dart`
- `frontend/lib/screens/splash_screen.dart`

### Explicação de cada arquivo e suas principais funções
- **`frontend/assets/LogoApp.svg` e `frontend/pubspec.yaml`**:
  - Contém o vetor oficial do logotipo vertical do aplicativo Artemis (`#0E58A8`), declarado na seção `flutter.assets` do `pubspec.yaml` e renderizado via `flutter_svg`.
- **`frontend/lib/main.dart`**:
  - **`main()` / `ArtemisApp.build()`**: Inicializa o `MaterialApp` definindo o `ThemeData` global com `scaffoldBackgroundColor: Colors.white`, `colorScheme` primário `Color(0xFF0E58A8)`, `iconTheme` e `appBarTheme` com ícones pretos (`Colors.black`), além do mapa de rotas nomeadas:
    - `/splash` $\rightarrow$ `SplashScreen`
    - `/login` $\rightarrow$ `LoginScreen`
    - `/register` $\rightarrow$ `RegisterScreen`
    - `/feed` $\rightarrow$ `FeedScreen`
    - `/incident-detail` $\rightarrow$ `IncidentDetailScreen`
    - `/settings` $\rightarrow$ `SettingsScreen`
- **`frontend/lib/screens/splash_screen.dart`**:
  - **`SplashScreen` / `_SplashScreenState.initState()`**: Exibe a tela de carregamento com fundo branco, o logotipo `assets/LogoApp.svg` (`120x120`) e um `CircularProgressIndicator` na cor `#0E58A8`, redirecionando automaticamente para a `LoginScreen` após 2 segundos.

---

## 2. `feat(auth-login-register)` — Telas de Splash, Login e Registro com Vínculo de Criança (Ideia 1)

### O que foi feito
Reformulação da tela de Login e criação da tela de Registro (`RegisterScreen`) aplicando a **Ideia 1 (Cadastro Único com Vínculo Imediato da Criança)**. No momento em que o responsável cria sua conta, ele já cadastra o nome do filho(a) (tornando-se **Responsável Primário**, `is_primary = True`) ou informa um código de convite/ID (tornando-se **Responsável Secundário**, `is_primary = False`).

### Arquivos deste módulo
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/screens/register_screen.dart`
- `frontend/lib/services/mock_api_service.dart`
- `frontend/lib/services/api_service.dart`

### Explicação de cada arquivo e suas principais funções
- **`frontend/lib/screens/login_screen.dart`**:
  - **`_LoginScreenState.build()`**: Renderiza o logo `assets/LogoApp.svg`, o título `"Acesse sua conta."` e o subtítulo `"proteja quem você ama!"` na fonte `YuGothic`, os campos de usuário e senha com ícones pretos (`Icons.person`, `Icons.lock`) e bordas de foco `#0E58A8`.
  - **Botão `ENTRAR` e Link `Registrar`**: Botão de ação principal com altura `56px`, cor `#0E58A8` e bordas arredondadas de `16px` (`BorderRadius.circular(16)`). Abaixo dele, exibe o texto `"Não possui uma Conta? Registrar"`, onde `"Registrar"` abre a rota `/register`.
  - **`_login()`**: Valida as credenciais via serviço de autenticação e navega para `/feed`.
- **`frontend/lib/screens/register_screen.dart`**:
  - **`_RegisterScreenState.build()`**: Formulário completo contendo:
    1. Dados do responsável (`Nome`, `E-mail`, `Senha`, `Confirmar Senha`).
    2. Seletor (`ChoiceChip`) de **Vínculo com a Criança (Dependente)**:
       - **Modo "Cadastrar Filho(a)"**: exibe o campo `"Nome do filho(a) / dependente"` (ex.: `Gabriel`), vinculando o responsável como **Primário (`is_primary = True`)**.
       - **Modo "Usar Código"**: exibe o campo de código de convite / ID do dependente (ex.: `dep-001`), vinculando o responsável como **Secundário (`is_primary = False`)**.
  - **`_register()`**: Valida os campos obrigatórios, invoca `_apiService.register(...)`, exibe confirmação e redireciona diretamente para `/feed`.
- **`frontend/lib/services/mock_api_service.dart`**:
  - **`register(...)`**: Registra o novo responsável e a criança em memória e **sincroniza via HTTP `POST /api/v1/auth/register` com o backend FastAPI** quando online, garantindo que a criança cadastrada no app também seja persistida no banco SQLite.
  - **`createDependent(...)`**: Permite adicionar um 2º ou 3º filho posteriormente (`POST /api/v1/dependents`).
  - **`login(...)` / `getDependents()`**: Autentica tanto usuários de demonstração quanto contas recém-criadas na sessão e retorna a lista atualizada de dependentes.

---

## 3. `feat(backend-register-dependents)` — Endpoints de Registro, Vínculo N:N e Sincronização com Simulador (Ideia 3)

### O que foi feito
Implementação no Backend FastAPI e no Simulador Web do fluxo completo da **Ideia 1 + Ideia 3**:
1. Quando um responsável cria a conta informando o nome da criança, o backend grava em uma única transação atômica o responsável (`guardians`), a criança (`dependents`) e a ligação N:N (`guardian_dependents`).
2. O Simulador de Chat Web consulta dinamicamente os dependentes cadastrados no banco SQLite e atualiza o `<select id="select-dependent">` automaticamente.

```
+---------------------------+    POST /api/v1/auth/register    +------------------------------+
| App Flutter               | -------------------------------> | Backend FastAPI (SQLite)     |
| RegisterScreen            |  name, email, password,          | 1. Cria GuardianORM          |
| (Cadastra "Gabriel")      |  dependent_name="Gabriel"        | 2. Cria DependentORM (dep-3) |
+---------------------------+                                  | 3. Cria GuardianDependentORM |
                                                               |    (is_primary = True)       |
+---------------------------+  GET /api/v1/dependents/simulator+--------------+---------------+
| Simulador Web (Porta 3000)| <-----------------------------------------------+
| Atualiza <select> com     |  Retorna: Lucas, Ana, Gabriel (dep-003)
| "Gabriel (dep-003)"       |
+---------------------------+
```

### Arquivos deste módulo
- `backend/src/api/v1/auth/register.py`
- `backend/src/api/v1/dependents/create.py`
- `backend/src/api/v1/auth/__init__.py`
- `backend/src/api/v1/dependents/__init__.py`
- `simulator/app.js`

### Explicação de cada arquivo e suas principais funções
- **`backend/src/api/v1/auth/register.py`**:
  - **`_generate_dependent_id(db)`**: Gera um identificador legível sequencial para a criança (`dep-003`, `dep-004`, etc.).
  - **`register_guardian(payload, db)` (`POST /api/v1/auth/register`)**:
    - Verifica unicidade do e-mail (`400 Bad Request` se já existir).
    - Cria o registro em `GuardianORM` com senha criptografada via Argon2 (`hash_password`).
    - Se `dependent_name` foi enviado: cria `DependentORM` (`common_threshold=0.50`) e vincula em `GuardianDependentORM` com `is_primary=True`.
    - Se `invite_code` foi enviado: valida o convite em `CoParentingInviteORM` (ou ID do dependente) e vincula em `GuardianDependentORM` com `is_primary=False`.
    - Retorna o JWT (`access_token`) e os dados do responsável com seus dependentes.
- **`backend/src/api/v1/dependents/create.py`**:
  - **`create_dependent(payload, guardian_id, db)` (`POST /api/v1/dependents`)**: Permite que um responsável já logado adicione outro filho(a) a qualquer momento a partir da tela de Configurações.
  - **`list_dependents_for_simulator(db)` (`GET /api/v1/dependents/simulator`)**: Endpoint consultado pelo Simulador de Chat Web para listar todas as crianças cadastradas no SQLite.
- **`simulator/app.js`**:
  - **`syncDependentsFromBackend()` e `renderDependentsList()`**: Chamados na inicialização, no *health check* periódico e ao focar no `<select id="select-dependent">`, atualizando a lista de crianças no Simulador sem perder a seleção atual.

---

## 4. `feat(feed-incident-management)` — Feed de Incidentes, Detalhes, Linha do Tempo Contextual, Transição de Status e Exportação PDF

### Arquivos deste módulo
- `frontend/lib/screens/feed_screen.dart`
- `frontend/lib/screens/incident_detail_screen.dart`
- `frontend/lib/models/incident_summary.dart`
- `frontend/lib/models/dependent.dart`

### Explicação de cada arquivo e suas principais funções
- **`frontend/lib/models/incident_summary.dart`**:
  - **`IncidentContextMessage` e `IncidentStatusTransition`**: Modelos para representar as mensagens de contexto anterior/posterior (`context_before` / `context_after`) e o histórico de auditoria das mudanças de status (`status_history`).
  - **`IncidentSummary`**: Armazena resumo e detalhe completo do incidente (`roomType`, `mainMessageText`, `mainMessageSenderId`, `mainMessageHash`, `contextBefore`, `contextAfter`, `statusHistory`, `allowedTransitions`).
- **`frontend/lib/screens/feed_screen.dart`**:
  - **`AppBar` (`Icons.refresh`, `Icons.settings`, `Icons.logout`)**: Barra superior com atualização manual, acesso às Configurações e encerramento de sessão (`logout()`).
  - **`DropdownButtonFormField` + Contador LGPD (`_getTotalSafeMessagesCount()`)**: Permite filtrar por `"Todos os dependentes"` (`ALL`) ou por uma criança específica, exibindo logo abaixo o contador de mensagens seguras descartadas (`safe_messages_count`).
  - **Cards de Incidente (`Card` + `InkWell`)**: Exibe badge de severidade (`CRÍTICO` em vermelho / `COMUM` em laranja), status atual, nome do dependente + papel traduzido (`Recebeu a mensagem`, `Enviou a mensagem`, `Estava no grupo`), prévia truncada em 60 caracteres (`_truncatePreview`), confiança em `%`, horário local formatado e badges para `Link suspeito`, `Escalonado` e `Divergência SHA-256`.
- **`frontend/lib/screens/incident_detail_screen.dart`**:
  - **`_loadIncident()`**: Ao abrir o incidente, registra automaticamente a visualização idempotente (`DETECTADO` $\rightarrow$ `VISUALIZADO`).
  - **Card de Classificação e Auditoria SHA-256**: Exibe `Chip`s com severidade, confiança (`%`), tipo de sala (`Sala: Jogo (Modo Gamer)` ou `Sala: Conversa`) e validação criptográfica (`Íntegro (SHA-256 Válido)` vs `Divergência SHA-256`).
  - **Linha do Tempo Contextual (`_buildContextBubble`)**: Renderiza em ordem cronológica os balões de `contextBefore` (até 3 mensagens anteriores), o card destacado da **Mensagem Principal Infratora** (com remetente, horário e hash `SHA-256` completo) e `contextAfter` (até 3 mensagens posteriores na janela de 10 minutos).
  - **Gestão da Máquina de Estados (`_updateStatus` / `_showStatusDialog`)**: Renderiza dinamicamente os botões de `allowedTransitions` (`Em análise`, `Conversei com meu filho`, `Encaminhado à escola`, `Alarme falso`) com modal para nota opcional.
  - **Histórico de Transições (`ExpansionTile`)**: Lista todas as transições de status (`fromStatus` $\rightarrow$ `toStatus`), nome do guardião, data/hora e nota.
  - **Ações Probatórias e LGPD (`_exportReport` / `_deleteIncident`)**: Exporta relatório PDF com hash SHA-256 e permite exclusão definitiva (LGPD) apenas para o Responsável Primário (`_isPrimary == true`).

---

## 5. `feat(settings-calibration)` — Níveis Amigáveis de Sensibilidade (Rigorosa / Equilibrada / Flexível) e Adição de Novos Dependentes

### Arquivos deste módulo
- `frontend/lib/screens/settings_screen.dart`

### Explicação de cada arquivo e suas principais funções
- **`frontend/lib/screens/settings_screen.dart`**:
  - **Cabeçalho do Dependente + `Chip` de Mensagens Seguras**: Exibe o nome do dependente com seu vínculo (`Primário` ou `Secundário`) e o contador `Seguras: X` (`safeMessagesCount`).
  - **`_levels` (`Rigorosa`, `Equilibrada`, `Flexível`)**: Apresenta 3 opções intuitivas com `RadioListTile`:
    - **Rigorosa** (`threshold = 0.50`): *"Ideal para crianças menores. Registra qualquer indício moderado de ofensa."*
    - **Equilibrada (Recomendado)** (`threshold = 0.65`): *"Filtra ironias ou provocações leves e foca em ofensas claras."*
    - **Flexível** (`threshold = 0.80`): *"Ideal para adolescentes. Notifica apenas ofensas fortes e alertas críticos."*
  - **`_updateThreshold(dependentId, threshold)`**: Envia o valor selecionado (`0.50`, `0.65` ou `0.80`) para o backend (`PATCH /api/v1/dependents/{id}/threshold`), bloqueando a edição caso o usuário logado seja responsável secundário (`!dependent.isPrimary`).
  - **Informativo de Proteções Fixas**: Informa que Alertas Críticos ($\ge 85\%$) e o piso do Modo Gamer ($\ge 70\%$ em salas de jogo) são aplicados automaticamente pelo sistema.
  - **`_showAddDependentDialog()`**: Modal acionado pelo ícone `Icons.person_add_alt_1` na `AppBar` para cadastrar novos filhos após a criação da conta.
