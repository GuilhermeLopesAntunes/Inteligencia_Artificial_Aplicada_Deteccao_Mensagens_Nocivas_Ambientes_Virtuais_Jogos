import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dependent.dart';
import '../models/incident_summary.dart';

/// Serviço híbrido de API: conecta ao Backend FastAPI real quando acessível
/// e mantém fallback reativo em memória para demonstração offline e testes de Widget.
class MockApiService {
  static final MockApiService _instance = MockApiService._internal();
  factory MockApiService() => _instance;
  MockApiService._internal();

  final List<Dependent> _mockDependents = [
    Dependent(
      id: 'dep-001',
      name: 'Lucas',
      commonThreshold: 0.50,
      isPrimary: true,
      safeMessagesCount: 15,
    ),
    Dependent(
      id: 'dep-002',
      name: 'Ana',
      commonThreshold: 0.65,
      isPrimary: true,
      safeMessagesCount: 8,
    ),
  ];

  final List<IncidentSummary> _mockIncidents = [
    IncidentSummary(
      id: 'inc1',
      dependentId: 'dep-001',
      dependentName: 'Lucas',
      category: 'CIBERBULLYING',
      severity: 'CRITICO',
      confidence: 0.94,
      hasLink: false,
      detectedRole: 'VITIMA',
      status: 'DETECTADO',
      integrityMismatch: false,
      escalated: false,
      preview: 'Você é um lixo inútil, ninguém gosta de você, some daqui!',
      createdAt: '2026-10-19T14:30:00Z',
      roomType: 'jogo',
      mainMessageText: 'Você é um lixo inútil, ninguém gosta de você, some daqui!',
      mainMessageSenderId: 'player-toxic-99',
      mainMessageHash: '8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4',
      contextBefore: const [
        IncidentContextMessage(
          text: 'Vamos tentar ganhar essa partida galera',
          senderId: 'dep-001',
          isFromMinor: true,
          timestamp: '2026-10-19T14:28:10Z',
        ),
        IncidentContextMessage(
          text: 'Você errou a jogada de novo',
          senderId: 'player-toxic-99',
          isFromMinor: false,
          timestamp: '2026-10-19T14:29:05Z',
        ),
      ],
      contextAfter: const [
        IncidentContextMessage(
          text: 'Para com isso cara, só estou jogando',
          senderId: 'dep-001',
          isFromMinor: true,
          timestamp: '2026-10-19T14:30:40Z',
        ),
      ],
      statusHistory: const [],
      allowedTransitions: const ['VISUALIZADO', 'EM_ANALISE'],
    ),
    IncidentSummary(
      id: 'inc2',
      dependentId: 'dep-001',
      dependentName: 'Lucas',
      category: 'LINK_SUSPEITO',
      severity: 'COMUM',
      confidence: 0.78,
      hasLink: true,
      detectedRole: 'VITIMA',
      status: 'EM_ANALISE',
      integrityMismatch: false,
      escalated: false,
      preview: 'Clica nesse link pra ganhar moedas grátis http://golpe-skins.com',
      createdAt: '2026-10-19T11:15:00Z',
      roomType: 'jogo',
      mainMessageText: 'Clica nesse link pra ganhar moedas grátis http://golpe-skins.com',
      mainMessageSenderId: 'scammer-07',
      mainMessageHash: '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      contextBefore: const [
        IncidentContextMessage(
          text: 'Oi, quer ganhar passe de batalha?',
          senderId: 'scammer-07',
          isFromMinor: false,
          timestamp: '2026-10-19T11:14:20Z',
        ),
      ],
      contextAfter: const [],
      statusHistory: const [
        IncidentStatusTransition(
          fromStatus: 'DETECTADO',
          toStatus: 'VISUALIZADO',
          guardianName: 'Maria',
          changedAt: '2026-10-19T11:20:00Z',
        ),
        IncidentStatusTransition(
          fromStatus: 'VISUALIZADO',
          toStatus: 'EM_ANALISE',
          guardianName: 'Maria',
          changedAt: '2026-10-19T11:22:00Z',
        ),
      ],
      allowedTransitions: const [
        'CONVERSADO_COM_FILHO',
        'ENCAMINHADO_A_ESCOLA',
        'FALSO_POSITIVO',
      ],
    ),
    IncidentSummary(
      id: 'inc3',
      dependentId: 'dep-002',
      dependentName: 'Ana',
      category: 'CIBERBULLYING',
      severity: 'COMUM',
      confidence: 0.68,
      hasLink: false,
      detectedRole: 'ESPECTADOR',
      status: 'VISUALIZADO',
      integrityMismatch: false,
      escalated: false,
      preview: 'Ninguém quer falar com ela no grupo da sala...',
      createdAt: '2026-10-18T16:45:00Z',
      roomType: 'conversa',
      mainMessageText: 'Ninguém quer falar com ela no grupo da sala...',
      mainMessageSenderId: 'colega-12',
      mainMessageHash: '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
      contextBefore: const [],
      contextAfter: const [],
      statusHistory: const [
        IncidentStatusTransition(
          fromStatus: 'DETECTADO',
          toStatus: 'VISUALIZADO',
          guardianName: 'Maria',
          changedAt: '2026-10-18T17:00:00Z',
        ),
      ],
      allowedTransitions: const ['EM_ANALISE'],
    ),
  ];

  final Map<String, Map<String, String>> _registeredUsers = {
    'test@exemplo.com': {'password': 'senha123', 'name': 'Maria (Demo)'},
    'responsavel@exemplo.com': {'password': 'senha123', 'name': 'Maria'},
    'joao@exemplo.com': {'password': 'senha456', 'name': 'João'},
  };

  String? _activeToken;
  String _currentGuardianId = 'resp-001';
  String _currentUserEmail = 'responsavel@exemplo.com';
  String _currentUserName = 'Maria';

  String? get activeToken => _activeToken;
  String get currentGuardianId => _currentGuardianId;
  String get currentUserName => _currentUserName;
  bool get isAuthenticated => _activeToken != null;

  void logout() {
    _activeToken = null;
  }

  List<String> get _candidateBaseUrls => const [
        'http://localhost:8000',
        'http://10.0.2.2:8000',
      ];

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? dependentName,
    String? inviteCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanDepName = dependentName?.trim() ?? '';
    final cleanInvite = inviteCode?.trim() ?? '';

    if (cleanDepName.isEmpty && cleanInvite.isEmpty) {
      throw Exception('Informe o nome do filho(a) ou um código de convite.');
    }

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/v1/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': cleanName,
                'email': cleanEmail,
                'password': password,
                'dependent_name': cleanDepName.isNotEmpty ? cleanDepName : null,
                'invite_code': cleanInvite.isNotEmpty ? cleanInvite : null,
              }),
            )
            .timeout(const Duration(milliseconds: 900));
        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _activeToken = data['access_token']?.toString();
          final guardian = data['guardian'] as Map<String, dynamic>?;
          if (guardian != null) {
            _currentGuardianId = (guardian['id'] ?? 'resp-001').toString();
            _currentUserName = (guardian['name'] ?? cleanName).toString();
            _currentUserEmail = cleanEmail;
          }
          break;
        } else if (response.statusCode == 400 || response.statusCode == 404) {
          final err = jsonDecode(response.body);
          throw Exception(err['detail'] ?? 'Falha no cadastro');
        }
      } catch (e) {
        if (e.toString().contains('Este e-mail') ||
            e.toString().contains('Código de convite')) {
          rethrow;
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 250));

    _registeredUsers[cleanEmail] = {
      'password': password,
      'name': cleanName,
    };
    _currentUserEmail = cleanEmail;
    _currentUserName = cleanName;
    _activeToken ??= 'mock-jwt-token-$cleanEmail';

    if (cleanDepName.isNotEmpty) {
      final newDepId =
          'dep-${(_mockDependents.length + 1).toString().padLeft(3, '0')}';
      final newDep = Dependent(
        id: newDepId,
        name: cleanDepName,
        commonThreshold: 0.65,
        isPrimary: true,
        safeMessagesCount: 0,
      );
      _mockDependents.insert(0, newDep);
    } else if (cleanInvite.isNotEmpty) {
      final existingIndex =
          _mockDependents.indexWhere((d) => d.id == cleanInvite);
      if (existingIndex == -1) {
        _mockDependents.add(
          Dependent(
            id: cleanInvite,
            name: 'Dependente ($cleanInvite)',
            commonThreshold: 0.65,
            isPrimary: false,
            safeMessagesCount: 0,
          ),
        );
      }
    }

    return {
      'access_token': _activeToken,
      'token_type': 'bearer',
      'expires_in': 3600,
    };
  }

  Future<Dependent> createDependent({
    required String name,
    double commonThreshold = 0.65,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Informe o nome do dependente.');
    }

    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .post(
                Uri.parse('$baseUrl/api/v1/dependents'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
                body: jsonEncode({
                  'name': cleanName,
                  'common_threshold': commonThreshold,
                }),
              )
              .timeout(const Duration(milliseconds: 900));
          if (res.statusCode == 201 || res.statusCode == 200) {
            final dep = Dependent.fromJson(jsonDecode(res.body));
            _mockDependents.add(dep);
            return dep;
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 250));
    final newDep = Dependent(
      id: 'dep-${(_mockDependents.length + 1).toString().padLeft(3, '0')}',
      name: cleanName,
      commonThreshold: commonThreshold,
      isPrimary: true,
      safeMessagesCount: 0,
    );
    _mockDependents.add(newDep);
    return newDep;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/v1/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': cleanEmail, 'password': password}),
            )
            .timeout(const Duration(milliseconds: 800));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _activeToken = data['access_token']?.toString();
          final guardian = data['guardian'] as Map<String, dynamic>?;
          if (guardian != null) {
            _currentGuardianId = (guardian['id'] ?? 'resp-001').toString();
            _currentUserName = (guardian['name'] ?? 'Responsável').toString();
            _currentUserEmail = cleanEmail;
          }
          return data;
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final localUser = _registeredUsers[cleanEmail];
    if (localUser != null && localUser['password'] == password) {
      _currentUserEmail = cleanEmail;
      _currentUserName = localUser['name'] ?? 'Responsável';
      _activeToken = 'mock-jwt-token-$cleanEmail';
      return {
        'access_token': _activeToken,
        'token_type': 'Bearer',
        'expires_in': 3600,
      };
    }

    throw Exception('Failed to login');
  }

  Future<Map<String, dynamic>> getMe() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'id': _currentGuardianId,
      'email': _currentUserEmail,
      'name': _currentUserName,
      'role': 'RESPONSAVEL',
    };
  }

  Future<List<Dependent>> getDependents() async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .get(
                Uri.parse('$baseUrl/api/v1/dependents'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 800));
          if (res.statusCode == 200) {
            final list = (jsonDecode(res.body) as List<dynamic>)
                .map((e) => Dependent.fromJson(e as Map<String, dynamic>))
                .toList();
            if (list.isNotEmpty) {
              _mockDependents
                ..clear()
                ..addAll(list);
              return List.unmodifiable(_mockDependents);
            }
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_mockDependents);
  }

  Future<Dependent> updateThreshold(String dependentId, double threshold) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          await http
              .patch(
                Uri.parse('$baseUrl/api/v1/dependents/$dependentId/threshold'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
                body: jsonEncode({'common_threshold': threshold}),
              )
              .timeout(const Duration(milliseconds: 800));
          break;
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 200));

    final dependentIndex =
        _mockDependents.indexWhere((d) => d.id == dependentId);
    if (dependentIndex != -1) {
      final updated = _mockDependents[dependentIndex].copyWith(
        commonThreshold: threshold,
      );
      _mockDependents[dependentIndex] = updated;
      return updated;
    } else {
      throw Exception('Dependent not found');
    }
  }

  Future<List<IncidentSummary>> getIncidents({
    String? dependentId,
    String? status,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final queryParams = <String, String>{};
          if (dependentId != null && dependentId.isNotEmpty) {
            queryParams['dependent_id'] = dependentId;
          }
          if (status != null) queryParams['status'] = status;
          if (category != null) queryParams['category'] = category;

          final uri = Uri.parse('$baseUrl/api/v1/incidents')
              .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
          final res = await http
              .get(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 800));
          if (res.statusCode == 200) {
            final body = jsonDecode(res.body);
            final rawItems = body is Map<String, dynamic>
                ? (body['items'] as List<dynamic>? ?? [])
                : (body as List<dynamic>);
            return rawItems
                .map((e) => IncidentSummary.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 250));

    var filtered = List<IncidentSummary>.from(_mockIncidents);

    if (dependentId != null && dependentId.isNotEmpty) {
      filtered =
          filtered.where((inc) => inc.dependentId == dependentId).toList();
    }

    if (status != null) {
      filtered = filtered.where((inc) => inc.status == status).toList();
    }

    if (category != null) {
      filtered = filtered.where((inc) => inc.category == category).toList();
    }

    return filtered.skip(offset).take(limit).toList();
  }

  Future<IncidentSummary> getIncident(String incidentId) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .get(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 800));
          if (res.statusCode == 200) {
            return IncidentSummary.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>,
            );
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 200));

    return _mockIncidents.firstWhere(
      (inc) => inc.id == incidentId,
      orElse: () => throw Exception('Incident not found'),
    );
  }

  Future<void> viewIncident(String incidentId) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          await http
              .post(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId/view'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 800));
          break;
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 150));
    final index = _mockIncidents.indexWhere((inc) => inc.id == incidentId);
    if (index != -1 && _mockIncidents[index].status == 'DETECTADO') {
      final current = _mockIncidents[index];
      final updatedHistory = List<IncidentStatusTransition>.from(current.statusHistory)
        ..add(
          IncidentStatusTransition(
            fromStatus: 'DETECTADO',
            toStatus: 'VISUALIZADO',
            guardianName: _currentUserName,
            changedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      _mockIncidents[index] = current.copyWith(
        status: 'VISUALIZADO',
        statusHistory: updatedHistory,
        allowedTransitions: const ['EM_ANALISE'],
      );
    }
  }

  Future<void> updateIncidentStatus(
    String incidentId,
    String status, {
    String? note,
  }) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          await http
              .patch(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId/status'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
                body: jsonEncode({
                  'status': status,
                  if (note != null) 'note': note,
                }),
              )
              .timeout(const Duration(milliseconds: 800));
          break;
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 200));

    final incidentIndex =
        _mockIncidents.indexWhere((inc) => inc.id == incidentId);
    if (incidentIndex != -1) {
      final current = _mockIncidents[incidentIndex];
      final updatedHistory =
          List<IncidentStatusTransition>.from(current.statusHistory)
            ..add(
              IncidentStatusTransition(
                fromStatus: current.status,
                toStatus: status,
                note: note,
                guardianName: _currentUserName,
                changedAt: DateTime.now().toUtc().toIso8601String(),
              ),
            );
      List<String> nextAllowed = const [];
      if (status == 'EM_ANALISE') {
        nextAllowed = const [
          'CONVERSADO_COM_FILHO',
          'ENCAMINHADO_A_ESCOLA',
          'FALSO_POSITIVO',
        ];
      }
      _mockIncidents[incidentIndex] = current.copyWith(
        status: status,
        statusHistory: updatedHistory,
        allowedTransitions: nextAllowed,
      );
    }
  }

  Future<http.Response> getIncidentReport(String incidentId) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .get(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId/report'),
                headers: {
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 1200));
          if (res.statusCode == 200) {
            return res;
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 250));
    final mockPdfBytes = List<int>.filled(1000, 0x20);
    return http.Response.bytes(
      mockPdfBytes,
      200,
      headers: {'content-type': 'application/pdf'},
    );
  }

  Future<void> deleteIncident(String incidentId) async {
    for (final baseUrl in _candidateBaseUrls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          await http
              .delete(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId'),
                headers: {
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 800));
          break;
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 200));
    _mockIncidents.removeWhere((inc) => inc.id == incidentId);
  }
}

extension DependentCopyWith on Dependent {
  Dependent copyWith({
    String? id,
    String? name,
    double? commonThreshold,
    bool? isPrimary,
    int? safeMessagesCount,
  }) {
    return Dependent(
      id: id ?? this.id,
      name: name ?? this.name,
      commonThreshold: commonThreshold ?? this.commonThreshold,
      isPrimary: isPrimary ?? this.isPrimary,
      safeMessagesCount: safeMessagesCount ?? this.safeMessagesCount,
    );
  }
}

extension IncidentSummaryCopyWith on IncidentSummary {
  IncidentSummary copyWith({
    String? id,
    String? dependentId,
    String? dependentName,
    String? category,
    String? severity,
    double? confidence,
    bool? hasLink,
    String? detectedRole,
    String? status,
    bool? integrityMismatch,
    bool? escalated,
    String? preview,
    String? createdAt,
    String? roomType,
    String? mainMessageText,
    String? mainMessageSenderId,
    String? mainMessageHash,
    List<IncidentContextMessage>? contextBefore,
    List<IncidentContextMessage>? contextAfter,
    List<IncidentStatusTransition>? statusHistory,
    List<String>? allowedTransitions,
  }) {
    return IncidentSummary(
      id: id ?? this.id,
      dependentId: dependentId ?? this.dependentId,
      dependentName: dependentName ?? this.dependentName,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      confidence: confidence ?? this.confidence,
      hasLink: hasLink ?? this.hasLink,
      detectedRole: detectedRole ?? this.detectedRole,
      status: status ?? this.status,
      integrityMismatch: integrityMismatch ?? this.integrityMismatch,
      escalated: escalated ?? this.escalated,
      preview: preview ?? this.preview,
      createdAt: createdAt ?? this.createdAt,
      roomType: roomType ?? this.roomType,
      mainMessageText: mainMessageText ?? this.mainMessageText,
      mainMessageSenderId: mainMessageSenderId ?? this.mainMessageSenderId,
      mainMessageHash: mainMessageHash ?? this.mainMessageHash,
      contextBefore: contextBefore ?? this.contextBefore,
      contextAfter: contextAfter ?? this.contextAfter,
      statusHistory: statusHistory ?? this.statusHistory,
      allowedTransitions: allowedTransitions ?? this.allowedTransitions,
    );
  }
}