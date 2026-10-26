import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/dependent.dart';
import '../models/incident_summary.dart';

/// Serviço híbrido de API: conecta ao Backend FastAPI real quando acessível
/// e mantém fallback reativo em memória para demonstração offline e testes de Widget.
class MockApiService {
  static final MockApiService _instance = MockApiService._internal();
  factory MockApiService() => _instance;
  MockApiService._internal();

  final Map<String, List<Dependent>> _dependentsByEmail = {
    'responsavel@exemplo.com': [
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
    ],
    'test@exemplo.com': [
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
    ],
    'joao@exemplo.com': [
      Dependent(
        id: 'dep-001',
        name: 'Lucas',
        commonThreshold: 0.50,
        isPrimary: false,
        safeMessagesCount: 15,
      ),
    ],
  };

  List<Dependent> get _currentDependents =>
      _dependentsByEmail.putIfAbsent(_currentUserEmail, () => <Dependent>[]);

  Dependent? _findDependentAnywhere(String id) {
    for (final list in _dependentsByEmail.values) {
      for (final dep in list) {
        if (dep.id == id) return dep;
      }
    }
    return null;
  }

  int get _totalUniqueDependentsCount {
    final ids = <String>{};
    for (final list in _dependentsByEmail.values) {
      for (final dep in list) {
        ids.add(dep.id);
      }
    }
    return ids.length;
  }

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

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _activeToken;
  String? _resolvedBaseUrl;
  String _currentGuardianId = 'resp-001';
  String _currentUserEmail = 'responsavel@exemplo.com';
  String _currentUserName = 'Maria';
  final Set<String> _knownIncidentIds = <String>{};

  String? get activeToken => _activeToken;
  String? get resolvedBaseUrl => _resolvedBaseUrl;
  String get currentGuardianId => _currentGuardianId;
  String get currentUserName => _currentUserName;
  bool get isAuthenticated => _activeToken != null;
  bool get isUsingRealBackend =>
      _activeToken != null && !_activeToken!.startsWith('mock-');

  String? get websocketUrl {
    if (!isUsingRealBackend || _activeToken == null) return null;
    final base = _resolvedBaseUrl ?? 'http://127.0.0.1:8000';
    final wsBase = base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$wsBase/ws?token=$_activeToken';
  }

  Future<List<File>> _getSessionFiles() async {
    if (kIsWeb) return const <File>[];
    final files = <File>[];
    try {
      final supportDir = await getApplicationSupportDirectory();
      files.add(File('${supportDir.path}/artemis_session.json'));
    } catch (_) {}
    try {
      final docDir = await getApplicationDocumentsDirectory();
      files.add(File('${docDir.path}/artemis_session.json'));
    } catch (_) {}
    return files;
  }

  Future<void> saveKnownIncidentIds(Iterable<String> ids) async {
    _knownIncidentIds.addAll(ids);
    await _persistSession();
  }

  Future<void> _persistSession() async {
    if (_activeToken == null) return;
    final sessionPayload = jsonEncode({
      'token': _activeToken,
      'guardian_id': _currentGuardianId,
      'email': _currentUserEmail,
      'name': _currentUserName,
      'base_url': _resolvedBaseUrl ?? 'http://127.0.0.1:8000',
      'known_incident_ids': _knownIncidentIds.toList(),
    });

    try {
      final files = await _getSessionFiles();
      for (final file in files) {
        await file.writeAsString(sessionPayload, flush: true);
      }
    } catch (_) {}

    try {
      await _storage.write(key: 'artemis_jwt_token', value: _activeToken);
      await _storage.write(key: 'artemis_guardian_id', value: _currentGuardianId);
      await _storage.write(key: 'artemis_user_email', value: _currentUserEmail);
      await _storage.write(key: 'artemis_user_name', value: _currentUserName);
      if (_resolvedBaseUrl != null) {
        await _storage.write(key: 'artemis_base_url', value: _resolvedBaseUrl);
      }
    } catch (_) {}
  }

  Future<bool> restoreSession() async {
    if (_activeToken != null && _activeToken!.isNotEmpty) return true;

    try {
      final files = await _getSessionFiles();
      for (final file in files) {
        if (await file.exists()) {
          final raw = await file.readAsString();
          if (raw.trim().isNotEmpty) {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final token = map['token']?.toString();
            if (token != null && token.isNotEmpty && !token.startsWith('mock-')) {
              _activeToken = token;
              _currentGuardianId =
                  (map['guardian_id'] ?? _currentGuardianId).toString();
              _currentUserEmail =
                  (map['email'] ?? _currentUserEmail).toString().toLowerCase();
              _currentUserName = (map['name'] ?? _currentUserName).toString();
              final url = map['base_url']?.toString();
              if (url != null && url.isNotEmpty) {
                _resolvedBaseUrl = url;
              }
              final rawIds = map['known_incident_ids'];
              if (rawIds is List) {
                _knownIncidentIds.addAll(rawIds.map((e) => e.toString()));
              }
              break;
            }
          }
        }
      }
    } catch (_) {}

    if (_activeToken == null || _activeToken!.isEmpty) {
      try {
        final savedToken = await _storage.read(key: 'artemis_jwt_token');
        if (savedToken != null && savedToken.isNotEmpty && !savedToken.startsWith('mock-')) {
          _activeToken = savedToken;
          _currentGuardianId =
              (await _storage.read(key: 'artemis_guardian_id')) ??
                  _currentGuardianId;
          _currentUserEmail =
              (await _storage.read(key: 'artemis_user_email')) ??
                  _currentUserEmail;
          _currentUserName =
              (await _storage.read(key: 'artemis_user_name')) ??
                  _currentUserName;
          final savedUrl = await _storage.read(key: 'artemis_base_url');
          if (savedUrl != null && savedUrl.isNotEmpty) {
            _resolvedBaseUrl = savedUrl;
          }
          await _persistSession();
        }
      } catch (_) {}
    }

    if (_activeToken == null || _activeToken!.isEmpty) {
      return false;
    }

    // Mantém a sessão logada permanentemente até o usuário clicar em Logout.
    // Sincroniza em background caso o servidor esteja acessível.
    if (!_activeToken!.startsWith('mock-')) {
      _getOrderedBaseUrls().then((urls) async {
        for (final baseUrl in urls) {
          try {
            final res = await http
                .get(
                  Uri.parse('$baseUrl/api/v1/auth/me'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $_activeToken',
                  },
                )
                .timeout(const Duration(milliseconds: 2500));
            if (res.statusCode == 200) {
              _resolvedBaseUrl = baseUrl;
              final data = jsonDecode(res.body) as Map<String, dynamic>;
              _currentGuardianId = (data['id'] ?? _currentGuardianId).toString();
              _currentUserName = (data['name'] ?? _currentUserName).toString();
              _currentUserEmail =
                  (data['email'] ?? _currentUserEmail).toString().toLowerCase();
              await _persistSession();
              break;
            }
          } catch (_) {}
        }
      });
    }

    return true;
  }

  void logout() {
    _activeToken = null;
    _resolvedBaseUrl = null;
    _knownIncidentIds.clear();
    _getSessionFiles().then((files) async {
      for (final file in files) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    });
    try {
      _storage.delete(key: 'artemis_jwt_token');
      _storage.delete(key: 'artemis_guardian_id');
      _storage.delete(key: 'artemis_user_email');
      _storage.delete(key: 'artemis_user_name');
      _storage.delete(key: 'artemis_base_url');
    } catch (_) {}
  }

  List<String> get _candidateBaseUrls {
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final urls = <String>[
      if (envUrl.isNotEmpty) envUrl,
      if (_resolvedBaseUrl != null) _resolvedBaseUrl!,
      'http://127.0.0.1:8000',
      'http://192.168.1.10:8000',
      'http://192.168.1.8:8000',
      'http://10.69.210.131:8000',
      'http://10.0.2.2:8000',
      'http://localhost:8000',
    ];
    return urls.toSet().toList();
  }

  /// Descobre sem lançar exceções não tratadas qual URL do Backend FastAPI está acessível
  /// (USB adb reverse 127.0.0.1, Wi-Fi atual 10.69.210.131, Wi-Fi 192.168.1.8 ou Emulador 10.0.2.2).
  /// Se a URL em cache (_resolvedBaseUrl) mudou de rede e não responde mais, redescobre automaticamente.
  Future<List<String>> _getOrderedBaseUrls({bool forceReprobe = false}) async {
    if (!forceReprobe && _resolvedBaseUrl != null) {
      try {
        final check = await http
            .get(Uri.parse('$_resolvedBaseUrl/'))
            .timeout(const Duration(milliseconds: 900));
        if (check.statusCode == 200) {
          return <String>[_resolvedBaseUrl!, ..._candidateBaseUrls.where((u) => u != _resolvedBaseUrl)];
        }
      } catch (_) {
        _resolvedBaseUrl = null;
      }
    }
    final candidates = _candidateBaseUrls;
    final completer = Completer<String?>();
    int remaining = candidates.length;

    for (final baseUrl in candidates) {
      http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(milliseconds: 1500))
          .then((res) {
        if (res.statusCode == 200 && !completer.isCompleted) {
          completer.complete(baseUrl);
        } else {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((_) {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    final winner = await completer.future;
    if (winner != null) {
      _resolvedBaseUrl = winner;
      return <String>[winner, ...candidates.where((u) => u != winner)];
    }
    return candidates;
  }

  String _extractErrorDetail(String responseBody, String fallback) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {}
    return fallback;
  }

  void _syncGuardianPayload(Map<String, dynamic> data, String fallbackEmail, String fallbackName) {
    _currentUserEmail = fallbackEmail;
    _currentUserName = fallbackName;
    final guardian = data['guardian'] as Map<String, dynamic>?;
    if (guardian != null) {
      _currentGuardianId = (guardian['id'] ?? 'resp-001').toString();
      _currentUserName = (guardian['name'] ?? fallbackName).toString();
      _currentUserEmail = (guardian['email'] ?? fallbackEmail).toString().toLowerCase();

      final rawDeps = guardian['dependents'];
      if (rawDeps is List) {
        _dependentsByEmail[_currentUserEmail] = rawDeps
            .whereType<Map<String, dynamic>>()
            .map(Dependent.fromJson)
            .toList();
        return;
      }
    }
    final singleDep = data['dependent'];
    if (singleDep is Map<String, dynamic>) {
      _dependentsByEmail[_currentUserEmail] = [Dependent.fromJson(singleDep)];
    }
  }

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

    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
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
            .timeout(const Duration(milliseconds: 3000));
        if (response.statusCode == 201 || response.statusCode == 200) {
          _resolvedBaseUrl = baseUrl;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _activeToken = data['access_token']?.toString();
          _syncGuardianPayload(data, cleanEmail, cleanName);
          _registeredUsers[_currentUserEmail] = {
            'password': password,
            'name': _currentUserName,
          };
          await _persistSession();
          return data;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          _resolvedBaseUrl = baseUrl;
          throw Exception(_extractErrorDetail(response.body, 'Falha ao registrar conta na API'));
        }
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      } catch (e) {
        if (e is Exception &&
            !e.toString().contains('SocketException') &&
            !e.toString().contains('Connection refused') &&
            !e.toString().contains('Failed host lookup')) {
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
    _activeToken = 'mock-jwt-token-$cleanEmail';

    final userDeps = <Dependent>[];
    if (cleanDepName.isNotEmpty) {
      final newDepId =
          'dep-${(_totalUniqueDependentsCount + 1).toString().padLeft(3, '0')}';
      userDeps.add(
        Dependent(
          id: newDepId,
          name: cleanDepName,
          commonThreshold: 0.65,
          isPrimary: true,
          safeMessagesCount: 0,
        ),
      );
    } else if (cleanInvite.isNotEmpty) {
      final existing = _findDependentAnywhere(cleanInvite);
      userDeps.add(
        Dependent(
          id: cleanInvite,
          name: existing?.name ?? 'Dependente ($cleanInvite)',
          commonThreshold: existing?.commonThreshold ?? 0.65,
          isPrimary: false,
          safeMessagesCount: existing?.safeMessagesCount ?? 0,
        ),
      );
    }
    _dependentsByEmail[cleanEmail] = userDeps;
    await _persistSession();

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

    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
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
              .timeout(const Duration(milliseconds: 3000));
          if (res.statusCode == 201 || res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            final dep = Dependent.fromJson(jsonDecode(res.body));
            _currentDependents.add(dep);
            return dep;
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            throw Exception(_extractErrorDetail(res.body, 'Erro ao criar dependente'));
          }
        }
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      } catch (e) {
        if (e is Exception &&
            !e.toString().contains('SocketException') &&
            !e.toString().contains('Connection refused')) {
          rethrow;
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 250));
    final newDep = Dependent(
      id: 'dep-${(_totalUniqueDependentsCount + 1).toString().padLeft(3, '0')}',
      name: cleanName,
      commonThreshold: commonThreshold,
      isPrimary: true,
      safeMessagesCount: 0,
    );
    _currentDependents.add(newDep);
    return newDep;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/v1/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': cleanEmail, 'password': password}),
            )
            .timeout(const Duration(milliseconds: 3000));
        if (res.statusCode == 200) {
          _resolvedBaseUrl = baseUrl;
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _activeToken = data['access_token']?.toString();
          _syncGuardianPayload(data, cleanEmail, 'Responsável');
          await _persistSession();
          return data;
        } else if (res.statusCode == 401 || res.statusCode == 422) {
          _resolvedBaseUrl = baseUrl;
          // Se a conta havia sido criada localmente enquanto o celular estava offline,
          // sincroniza automaticamente com /api/v1/auth/register no Backend!
          final localUser = _registeredUsers[cleanEmail];
          if (localUser != null && localUser['password'] == password) {
            final localDeps = _dependentsByEmail[cleanEmail];
            final firstDepName = (localDeps != null && localDeps.isNotEmpty)
                ? localDeps.first.name
                : 'Dependente';
            final regRes = await http
                .post(
                  Uri.parse('$baseUrl/api/v1/auth/register'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'name': localUser['name'] ?? 'Responsável',
                    'email': cleanEmail,
                    'password': password,
                    'dependent_name': firstDepName,
                  }),
                )
                .timeout(const Duration(milliseconds: 3000));
            if (regRes.statusCode == 201 || regRes.statusCode == 200) {
              final data = jsonDecode(regRes.body) as Map<String, dynamic>;
              _activeToken = data['access_token']?.toString();
              _syncGuardianPayload(data, cleanEmail, localUser['name'] ?? 'Responsável');
              await _persistSession();
              return data;
            }
          }
          throw Exception(_extractErrorDetail(res.body, 'E-mail ou senha incorretos'));
        }
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      } catch (e) {
        if (e.toString().contains('E-mail ou senha incorretos') ||
            e.toString().contains('incorretos')) {
          rethrow;
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final localUser = _registeredUsers[cleanEmail];
    if (localUser != null && localUser['password'] == password) {
      _currentUserEmail = cleanEmail;
      _currentUserName = localUser['name'] ?? 'Responsável';
      _activeToken = 'mock-jwt-token-$cleanEmail';
      await _persistSession();
      return {
        'access_token': _activeToken,
        'token_type': 'Bearer',
        'expires_in': 3600,
      };
    }

    throw Exception('Failed to login');
  }

  Future<Map<String, dynamic>> getMe() async {
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .get(
                Uri.parse('$baseUrl/api/v1/auth/me'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            _currentGuardianId = (data['id'] ?? _currentGuardianId).toString();
            _currentUserName = (data['name'] ?? _currentUserName).toString();
            _currentUserEmail = (data['email'] ?? _currentUserEmail).toString();
            return data;
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'id': _currentGuardianId,
      'email': _currentUserEmail,
      'name': _currentUserName,
      'role': 'RESPONSAVEL',
    };
  }

  Future<List<Dependent>> getDependents() async {
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
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
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            final list = (jsonDecode(res.body) as List<dynamic>)
                .map((e) => Dependent.fromJson(e as Map<String, dynamic>))
                .toList();
            _dependentsByEmail[_currentUserEmail] = list;
            return List.unmodifiable(list);
          }
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_currentDependents);
  }

  Future<Dependent> updateThreshold(String dependentId, double threshold) async {
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .patch(
                Uri.parse('$baseUrl/api/v1/dependents/$dependentId/threshold'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
                body: jsonEncode({'common_threshold': threshold}),
              )
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            break;
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            throw Exception(_extractErrorDetail(res.body, 'Falha ao atualizar limiar'));
          }
        }
      } catch (e) {
        if (e.toString().contains('responsável primário') ||
            e.toString().contains('Falha ao atualizar')) {
          rethrow;
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 200));

    final deps = _currentDependents;
    final dependentIndex = deps.indexWhere((d) => d.id == dependentId);
    if (dependentIndex != -1) {
      final updated = deps[dependentIndex].copyWith(
        commonThreshold: threshold,
      );
      deps[dependentIndex] = updated;
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
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final queryParams = <String, String>{
            'limit': limit.toString(),
            'offset': offset.toString(),
          };
          if (dependentId != null && dependentId.isNotEmpty) {
            queryParams['dependent_id'] = dependentId;
          }
          if (status != null) queryParams['status'] = status;
          if (category != null) queryParams['category'] = category;

          final uri = Uri.parse('$baseUrl/api/v1/incidents')
              .replace(queryParameters: queryParams);
          final res = await http
              .get(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
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

    final allowedDepIds = _currentDependents.map((d) => d.id).toSet();
    var filtered = _mockIncidents
        .where((inc) => allowedDepIds.contains(inc.dependentId))
        .toList();

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
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
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
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
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
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .post(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId/view'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            return;
          }
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
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
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
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            return;
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            throw Exception(_extractErrorDetail(res.body, 'Transição de status inválida'));
          }
        }
      } catch (e) {
        if (e.toString().contains('Transição')) {
          rethrow;
        }
      }
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
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .get(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId/report'),
                headers: {
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 3000));
          if (res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
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
    final urls = await _getOrderedBaseUrls();
    for (final baseUrl in urls) {
      try {
        if (_activeToken != null && !_activeToken!.startsWith('mock-')) {
          final res = await http
              .delete(
                Uri.parse('$baseUrl/api/v1/incidents/$incidentId'),
                headers: {
                  'Authorization': 'Bearer $_activeToken',
                },
              )
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 204 || res.statusCode == 200) {
            _resolvedBaseUrl = baseUrl;
            _mockIncidents.removeWhere((inc) => inc.id == incidentId);
            return;
          } else if (res.statusCode >= 400 && res.statusCode < 500) {
            throw Exception(_extractErrorDetail(res.body, 'Apenas o responsável primário pode excluir o incidente'));
          }
        }
      } catch (e) {
        if (e.toString().contains('responsável primário')) {
          rethrow;
        }
      }
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