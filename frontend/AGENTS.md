# Frontend (App Flutter dos Responsáveis)

App **Android** usado pelos pais. Consome a API REST e recebe alertas por WebSocket. Leia `../.agents/contrato-api.md` antes de criar qualquer chamada: os modelos Dart devem espelhar exatamente os JSON de lá.

## Plataforma e conexão

- Alvo: **Android** (emulador ou APK). Não é preciso suportar web, iOS ou desktop.
- URL do backend via `--dart-define=API_BASE_URL=...`, com padrão `http://10.0.2.2:8000` (o `localhost` da máquina visto de dentro do emulador). Em aparelho físico, usar o IP da máquina na rede local.
- O backend usa HTTP sem TLS. `android/app/src/main/AndroidManifest.xml` precisa de `android:usesCleartextTraffic="true"` na tag `<application>` e da permissão `INTERNET`.
- WebSocket: `ws://<host>:8000/ws?token=<jwt>`, derivado da mesma URL base.

## Pacotes

| Necessidade | Pacote |
| :--- | :--- |
| HTTP | `http` |
| WebSocket | `web_socket_channel` |
| Guardar o JWT | `flutter_secure_storage` |
| Notificação local com som | `flutter_local_notifications` (Android 13+ exige pedir a permissão `POST_NOTIFICATIONS`) |
| Salvar e abrir o PDF | `path_provider` + `open_filex` |

Gerenciamento de estado: `setState` e `ChangeNotifier` bastam. Não introduza Bloc, Riverpod, GetX ou geração de código.

## Estrutura

```
lib/
├── main.dart
├── config.dart          # API_BASE_URL
├── models/              # Classes Dart espelhando o contrato (fromJson)
├── services/            # api_service.dart, websocket_service.dart, notification_service.dart
└── screens/             # Uma tela por arquivo
```

## Telas do MVP

| Tela | UC | Conteúdo |
| :--- | :--- | :--- |
| Login | UC-18 | E-mail e senha; erro 401 mostra "E-mail ou senha incorretos" |
| Feed de incidentes | UC-09 | Lista de `IncidentSummary`, crítico destacado, filtro por dependente |
| Detalhe do incidente | UC-09, UC-04, UC-17 | Mensagem, contexto antes e depois, histórico, troca de status, exportar PDF, excluir (só primário) |
| Configurações do dependente | UC-03 | Slider do limiar comum de 0,50 a 0,84 (só primário) |

Não crie telas fora dessa lista (painel analítico, acessibilidade, sumário mensal são trabalho futuro), salvo pedido explícito.

## Regras de comportamento

- Ao abrir o detalhe, chamar `POST /incidents/{id}/view` (é ele que muda para `VISUALIZADO`).
- As opções de status vêm do campo `allowed_transitions` da API. **Não** replique a tabela de transições no app.
- Botões exclusivos do primário (calibrar, excluir, convidar) só aparecem quando `is_primary` for `true` para aquele dependente (vem de `/auth/me` e `/dependents`).
- Eventos `incident.critical` e `incident.escalated`: notificação local com som. Os demais eventos só atualizam a tela.
- Ao reconectar o WebSocket ou voltar o app para o primeiro plano, recarregar o feed via REST.
- Limitação conhecida: com o app fechado não há alerta (push real é trabalho futuro).

## Textos da interface

- Português do Brasil, linguagem simples, sem jargão técnico.
- Sempre "**possível** ciberbullying", nunca afirmar que houve ciberbullying.
- Mostrar a confiança como porcentagem arredondada (ex.: "93%").
- Rótulos de status legíveis: `EM_ANALISE` → "Em análise", `CONVERSADO_COM_FILHO` → "Conversei com meu filho", `ENCAMINHADO_A_ESCOLA` → "Encaminhado à escola", `FALSO_POSITIVO` → "Alarme falso".
- Papel do menor: `VITIMA` → "Recebeu a mensagem", `EMISSOR` → "Enviou a mensagem", `ESPECTADOR` → "Estava no grupo".
- Excluir exige diálogo de confirmação avisando que a ação é irreversível.

## Testes

```bash
flutter test
```

Testes de widget para as telas principais, com o `ApiService` substituído por uma implementação falsa. Nada de chamadas reais ao backend nos testes.
