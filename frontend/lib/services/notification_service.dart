import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/incident_summary.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _notificationCounter = 100;
  void Function(String incidentId)? onNotificationTap;

  NotificationService._internal();

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_stat_artemis');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            onNotificationTap?.call(payload);
          }
        },
      );

      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();

      const AndroidNotificationChannel criticalChannel =
          AndroidNotificationChannel(
        'artemis_alerts_v2',
        'Alertas de Proteção Artemis',
        description:
            'Notificações em tempo real de ciberbullying e links suspeitos',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidImplementation
          ?.createNotificationChannel(criticalChannel);

      _initialized = true;
    } catch (_) {
      // Fallback silencioso caso a plataforma/teste não suporte plugin nativo
    }
  }

  Future<void> showIncidentNotification(IncidentSummary incident) async {
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }

    final isCritical = incident.severity == 'CRITICO';
    final isLink = incident.category == 'LINK_SUSPEITO';

    final String title = isCritical
        ? '🚨 ALERTA CRÍTICO: ${incident.dependentName}'
        : isLink
            ? '⚠️ Link Suspeito: ${incident.dependentName}'
            : '⚠️ Incidente Detectado: ${incident.dependentName}';

    final int confidencePct = (incident.confidence * 100).round();
    final String body = '${incident.preview} (Risco: $confidencePct%)';

    _notificationCounter++;
    await showNotification(
      id: _notificationCounter,
      title: title,
      body: body,
      payload: incident.id,
      isCritical: isCritical,
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isCritical = true,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_initialized) {
        await init();
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'artemis_alerts_v2',
        'Alertas de Proteção Artemis',
        channelDescription:
            'Notificações em tempo real de ciberbullying e links suspeitos',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_stat_artemis',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: const Color(0xFF0E58A8),
        ticker: isCritical ? 'Alerta Crítico Artemis' : 'Novo Incidente Artemis',
        playSound: true,
        enableVibration: true,
        onlyAlertOnce: false,
        visibility: NotificationVisibility.public,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
  }
}