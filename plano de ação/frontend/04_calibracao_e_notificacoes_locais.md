# Frontend - Etapa 4: Calibração de Sensibilidade e Notificações com Áudio

> **Objetivo:** Implementar o painel de calibração do limiar de detecção da IA e o serviço de notificações locais com alertas sonoros imediatos.

---

## 1. Arquivos a Criar/Atualizar
- `frontend/lib/screens/dependent_config_screen.dart`
- `frontend/lib/services/notification_service.dart`
- `frontend/android/app/src/main/AndroidManifest.xml`
- `frontend/pubspec.yaml`

---

## 2. Detalhamento dos Componentes

### 2.1. Tela de Calibração de Sensibilidade (`lib/screens/dependent_config_screen.dart`)
* **Acesso:** Permitido apenas quando `is_primary == true`. Se o usuário for secundário, a tela exibe os dados em modo somente leitura com aviso informativo.
* **Componentes:**
  * Seletor de Dependente (Lucas, Ana).
  * **Slider de Limiar Comum:**
    * Faixa restrita: **0.50 a 0.84** (com incrementos de 0.01 ou 0.05).
    * Legendas intuitivas para os pais:
      * $0.50$: *"Máxima Proteção (Detecta qualquer termo suspeito)"*
      * $0.65$: *"Equilibrado (Recomendado)"*
      * $0.84$: *"Tolerante (Apenas ofensas muito explícitas)"*
    * Nota informativa sobre o **Modo Gamer**: *"Em salas de jogos, o limiar é automaticamente ajustado para no mínimo 0.70 para evitar alarmes falsos com gírias comuns de partidas."*
  * **Card de Estatísticas:**
    * Exibe `safe_messages_count`: *"128 mensagens analisadas e consideradas seguras."*
  * Botão "Salvar Calibração" que dispara `PATCH /dependents/{id}/threshold`.

### 2.2. Serviço de Notificações Locais (`lib/services/notification_service.dart`)
* **Configuração com `flutter_local_notifications`:**
  * Criação do canal de notificação Android de alta importância:
    * Channel ID: `artemis_critical_alerts`
    * Channel Name: `Alertas Críticos Artemis`
    * Importance: `Importance.max`
    * Priority: `Priority.high`
    * Som e Vibração ativados por padrão.
* **Permissão no Android 13+ (API 33+):**
  * Verificação e requisição da permissão `android.permission.POST_NOTIFICATIONS` ao inicializar o app.
* **Gatilho de Disparo:**
  * Escuta o stream do `WebSocketService`.
  * Ao receber `incident.critical` ou `incident.escalated`, dispara a notificação do sistema com som:
    * Título: *"⚠️ Alerta de Incidente Crítico - {dependent_name}"*
    * Corpo: *"{preview}"*
    * Ao tocar na notificação, abre o app direto na tela de detalhes do incidente.

---

## 3. Critérios de Aceitação da Etapa
- [ ] O slider de calibração impede seleção de valores $< 0.50$ ou $> 0.84$.
- [ ] Guardiões não primários não conseguem editar o slider.
- [ ] Notificação local com som e vibração é acionada no emulador/aparelho ao receber evento crítico.
