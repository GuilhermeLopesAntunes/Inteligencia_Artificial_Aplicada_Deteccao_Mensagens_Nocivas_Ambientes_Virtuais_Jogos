// TODO: serviço real, será integrado futuramente (hoje o app usa MockApiService).
// Remova o bloco de comentário abaixo para reativar.
/*
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/dependent.dart';
import '../models/incident_summary.dart';

class ApiService {
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _token;

  ApiService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<String?> get token async {
    if (_token == null) {
      _token = await _storage.read(key: 'jwt_token');
    }
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'jwt_token');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await setToken(data['access_token']);
      return data;
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.get(
      Uri.parse('${Config.apiBaseUrl}/api/v1/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user info');
    }
  }

  Future<List<Dependent>> getDependents() async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.get(
      Uri.parse('${Config.apiBaseUrl}/api/v1/dependents'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Dependent.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get dependents');
    }
  }

  Future<Dependent> updateThreshold(String dependentId, double threshold) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.patch(
      Uri.parse('${Config.apiBaseUrl}/api/v1/dependents/$dependentId/threshold'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'common_threshold': threshold,
      }),
    );

    if (response.statusCode == 200) {
      return Dependent.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update threshold');
    }
  }

  Future<List<IncidentSummary>> getIncidents({
    String? dependentId,
    String? status,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${Config.apiBaseUrl}/api/v1/incidents').replace(
      queryParameters: {
        if (dependentId != null) 'dependent_id': dependentId,
        if (status != null) 'status': status,
        if (category != null) 'category': category,
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> items = data['items'];
      return items.map((json) => IncidentSummary.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get incidents');
    }
  }

  Future<IncidentSummary> getIncident(String incidentId) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.get(
      Uri.parse('${Config.apiBaseUrl}/api/v1/incidents/$incidentId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      // Note: This returns the full incident detail, but we're mapping to IncidentSummary for now
      // In a real implementation, we might want a separate model for the full detail
      return IncidentSummary.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get incident');
    }
  }

  Future<void> viewIncident(String incidentId) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/api/v1/incidents/$incidentId/view'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark incident as viewed');
    }
  }

  Future<void> updateIncidentStatus(String incidentId, String status, {String? note}) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.patch(
      Uri.parse('${Config.apiBaseUrl}/api/v1/incidents/$incidentId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'status': status,
        if (note != null) 'note': note,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update incident status');
    }
  }

  Future<http.Response> getIncidentReport(String incidentId) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.get(
      Uri.parse('${Config.apiBaseUrl}/api/v1/incidents/$incidentId/report'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response;
  }

  Future<void> deleteIncident(String incidentId) async {
    final token = await this.token;
    if (token == null) throw Exception('Not authenticated');

    final response = await _client.delete(
      Uri.parse('${Config.apiBaseUrl}/api/v1/incidents/$incidentId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete incident');
    }
  }
}
*/
