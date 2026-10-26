# Frontend - Etapa 1: Modelos e Contratos de Mock

> **Objetivo:** Definir as estruturas de dados Dart e a arquitetura de injeção de dependência com Mocks para permitir o desenvolvimento da interface gráfica de forma 100% autônoma.

---

## 1. Arquivos a Criar/Atualizar
- `frontend/lib/models/incident.dart`
- `frontend/lib/models/dependent.dart`
- `frontend/lib/models/guardian.dart`
- `frontend/lib/models/context_message.dart`
- `frontend/lib/models/status_history.dart`
- `frontend/lib/services/api_service.dart`
- `frontend/lib/services/mock_api_service.dart`
- `frontend/lib/services/websocket_service.dart`
- `frontend/lib/services/mock_websocket_service.dart`
- `frontend/lib/config.dart`

---

## 2. Detalhamento dos Componentes

### 2.1. Modelos Dart (`lib/models/`)
* **`IncidentSummary`**:
  * Campos: `id`, `dependentId`, `dependentName`, `category`, `severity`, `confidence`, `hasLink`, `detectedRole`, `status`, `integrityMismatch`, `escalated`, `preview`, `createdAt`.
  * Factory `fromJson(Map<String, dynamic> json)` e método `toJson()`.
* **`IncidentDetail`**:
  * Extende/contém todos os campos de `IncidentSummary` + `roomType`, `conversationId`, `message` (texto, remetente, hash, timestamp), `contextBefore` (lista de `ContextMessage`), `contextAfter`, `allowedTransitions` (lista de strings), `statusHistory` (lista de `StatusHistoryItem`).
* **`Dependent`**:
  * Campos: `id`, `name`, `commonThreshold`, `isPrimary`, `safeMessagesCount`.
* **`Guardian`**:
  * Campos: `id`, `name`, `email`, `dependents`.

### 2.2. Interface e Implementação Mock de API (`lib/services/`)
```dart
abstract class ApiService {
  Future<Guardian> login(String email, String password);
  Future<Guardian> getMe();
  Future<List<Dependent>> getDependents();
  Future<void> updateThreshold(String dependentId, double threshold);
  Future<List<IncidentSummary>> getIncidents({String? dependentId, String? status});
  Future<IncidentDetail> getIncidentDetail(String incidentId);
  Future<IncidentDetail> markIncidentViewed(String incidentId);
  Future<IncidentDetail> updateIncidentStatus(String incidentId, String status, {String? note});
  Future<void> deleteIncident(String incidentId);
  Future<String> downloadReportPdf(String incidentId);
}
```

* **`MockApiService`**:
  * Mantém lista em memória de incidentes de teste (`inc-001` crítico, `inc-002` comum, `inc-003` com link).
  * Simula delay de rede de 300ms via `Future.delayed`.
  * Aplica regras de transição de status em memória para permitir que a UI responda dinamicamente.

### 2.3. Interface e Mock de WebSocket (`lib/services/`)
```dart
abstract class WebSocketService {
  Stream<Map<String, dynamic>> get eventStream;
  void connect(String token);
  void disconnect();
}
```

* **`MockWebSocketService`**:
  * Utiliza um `StreamController<Map<String, dynamic>>.broadcast()`.
  * Oferece um método `simularAlertaCritico()` e um timer opcional que dispara um alerta crítico 5 segundos após a inicialização para validar notificações com som sem o backend.

---

## 3. Critérios de Aceitação da Etapa
- [ ] Todos os modelos serializam e deserializam JSONs idênticos aos exemplos de `.agents/contrato-api.md`.
- [ ] O `MockApiService` responde a todas as chamadas CRUD em memória.
- [ ] O `MockWebSocketService` emite streams de eventos compatíveis com o formato do backend.
