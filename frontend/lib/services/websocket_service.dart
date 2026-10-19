// TODO: serviço real, será integrado futuramente (hoje o app usa MockApiService).
// Remova o bloco de comentário abaixo para reativar.
/*
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/incident_summary.dart';

class WebsocketService {
  final FlutterSecureStorage _storage;
  WebSocketChannel? _channel;
  final void Function(IncidentSummary incident) onIncident;
  final void Function() onConnectionError;
  final void Function() onConnectionClosed;

  WebsocketService({
    required this.onIncident,
    required this.onConnectionError,
    required this.onConnectionClosed,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  Future<void> connect() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      onConnectionError();
      return;
    }

    final uri = Uri.parse('${Config.apiBaseUrl.replaceAll('http', 'ws')}/ws?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
      cancelOnError: true,
    );
  }

  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String type = data['type'];

      if (type == 'incident.critical' || type == 'incident.created' || 
          type == 'incident.updated' || type == 'incident.escalated') {
        final IncidentSummary incident = IncidentSummary.fromJson(data['data']);
        onIncident(incident);
      }
    } catch (e) {
      // Ignora mensagens malformadas
    }
  }

  void _handleError(Object error) {
    onConnectionError();
  }

  void _handleDone() {
    onConnectionClosed();
  }

   Future<void> close() async {
     await _channel?.sink.close();
   }

  Future<void> ping() async {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
    }
  }
}
*/
