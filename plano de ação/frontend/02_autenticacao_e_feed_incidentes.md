# Frontend - Etapa 2: Autenticação e Feed de Incidentes

> **Objetivo:** Desenvolver as telas de Login e de Feed de Incidentes do aplicativo móvel, garantindo usabilidade, alta legibilidade e atualização em tempo real.

---

## 1. Arquivos a Criar/Atualizar
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/screens/incidents_feed_screen.dart`
- `frontend/lib/widgets/incident_card.dart`
- `frontend/lib/widgets/dependent_selector.dart`
- `frontend/lib/widgets/severity_badge.dart`

---

## 2. Detalhamento dos Componentes

### 2.1. Tela de Login (`lib/screens/login_screen.dart`)
* **Layout e Elementos:**
  * Logotipo institucional "Project Artemis - Controle Parental Inteligente".
  * Campos de texto com validação visual: E-mail e Senha.
  * Botão "Entrar" com indicador de progresso (*CircularProgressIndicator*).
  * Mensagem amigável de erro em caso de credenciais inválidas: *"E-mail ou senha incorretos"*.
* **Persistência de Sessão:**
  * Ao autenticar com sucesso, armazena o token JWT de forma segura no `flutter_secure_storage` e redireciona para a `IncidentsFeedScreen`.

### 2.2. Tela de Feed de Incidentes (`lib/screens/incidents_feed_screen.dart`)
* **Barra Superior (AppBar):**
  * Seletor suspenso (Dropdown / Chips) para filtrar por dependente ("Todos", "Lucas", "Ana").
  * Ícone de Configurações (redireciona para calibração de sensibilidade).
* **Corpo da Tela:**
  * Indicador de atualização por gesto (*RefreshIndicator / Pull-to-Refresh*).
  * Lista de cards de incidentes ordenados por data decrescente.
  * Estado vazio amigável: *"Nenhum incidente detectado no momento. As mensagens dos seus dependentes estão seguras."*
* **Card de Incidente (`lib/widgets/incident_card.dart`):**
  * `Badge` de severidade: **Crítico** (vermelho com ícone de alerta) vs **Comum** (amarelo/laranja).
  * Nome do dependente e data/hora formatada em horário local amigável.
  * Texto de prévia truncado em até 60 caracteres.
  * Papel do menor traduzido: *"Recebeu a mensagem"*, *"Enviou a mensagem"* ou *"Estava no grupo"*.
  * Ao tocar no card, navega para a tela de Detalhes do Incidente.

---

## 3. Critérios de Aceitação da Etapa
- [ ] Login funcional com validação de campos vazios e erro 401 tratado.
- [ ] O feed renderiza a lista de cards corretamente com base nos dados fornecidos pelo `MockApiService`.
- [ ] O filtro por dependente atualiza a lista instantaneamente.
- [ ] Gesto de pull-to-refresh recarrega a listagem.
