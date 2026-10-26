import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/incident_summary.dart';
import 'mock_api_service.dart';

class WebsocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _manuallyClosed = false;
  bool _isConnecting = false;

  final void Function(String eventType, IncidentSummary? incident, Map<String, dynamic> rawData) onEvent;
  final void Function()? onConnectionError;
  final void Function()? onConnectionClosed;

  WebsocketService({
    required this.onEvent,
    this.onConnectionError,
    this.onConnectionClosed,
  });

  Future<void> connect() async {
    _manuallyClosed = false;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_manuallyClosed || _isConnecting) return;
    _isConnecting = true;

    await _cleanupChannel();
    final wsUrl = MockApiService().websocketUrl;
    if (wsUrl == null) {
      _isConnecting = false;
      _scheduleReconnect();
      return;
    }

    try {
      final uri = Uri.parse(wsUrl);
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 3));
      if (_manuallyClosed) {
        await channel.sink.close();
        _isConnecting = false;
        return;
      }
      _channel = channel;
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) {
          onConnectionError?.call();
          _scheduleReconnect();
        },
        onDone: () {
          onConnectionClosed?.call();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) => ping());
    } catch (_) {
      _channel = null;
      onConnectionError?.call();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_manuallyClosed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_manuallyClosed) {
        _connectInternal();
      }
    });
  }

  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> payload =
          jsonDecode(message.toString()) as Map<String, dynamic>;
      final String type = (payload['type'] ?? payload['event'] ?? '').toString();
      final dynamic rawData = payload['data'];

      if (type == 'incident.critical' ||
          type == 'incident.created' ||
          type == 'incident.updated' ||
          type == 'incident.escalated') {
        if (rawData is Map<String, dynamic>) {
          final incident = IncidentSummary.fromJson(rawData);
          onEvent(type, incident, rawData);
        }
      } else if (type == 'incident.deleted') {
        onEvent(
          type,
          null,
          rawData is Map<String, dynamic> ? rawData : <String, dynamic>{},
        );
      }
    } catch (_) {
      // Ignora pacotes de keep-alive / pong
    }
  }

  Future<void> _cleanupChannel() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> close() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _cleanupChannel();
  }

  void ping() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {}
  }
}
