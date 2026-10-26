import 'dart:async';
import 'package:flutter/material.dart';
import '../services/mock_api_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../models/incident_summary.dart';
import '../models/dependent.dart';
import 'incident_detail_screen.dart';
import 'settings_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  static const String _allDependentsValue = 'ALL';

  final MockApiService _apiService = MockApiService();
  final NotificationService _notificationService = NotificationService();
  WebsocketService? _wsService;
  Timer? _syncTimer;
  final Set<String> _notifiedIncidentIds = <String>{};
  bool _initialSyncCompleted = false;
  bool _isFetching = false;

  List<IncidentSummary> _incidents = [];
  List<Dependent> _dependents = [];
  bool _isLoading = true;
  String _selectedDependentId = _allDependentsValue;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadData();
    _initWebsocket();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wsService?.connect();
      _loadData(silent: true);
    }
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    _notificationService.onNotificationTap = (String incidentId) {
      if (!mounted) return;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: incidentId),
            ),
          )
          .then((_) => _loadData(silent: true));
    };
  }

  void _triggerPhoneNotification(IncidentSummary incident) {
    _notificationService.showIncidentNotification(incident);
    if (!mounted) return;

    final isCritical = incident.severity == 'CRITICO';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isCritical ? const Color(0xFFDC2626) : const Color(0xFF0E58A8),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        content: Text(
          isCritical
              ? '🚨 ALERTA CRÍTICO (${incident.dependentName}): ${incident.preview}'
              : '⚠️ Novo incidente (${incident.dependentName}): ${incident.preview}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        action: SnackBarAction(
          label: 'VER',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        IncidentDetailScreen(incidentId: incident.id),
                  ),
                )
                .then((_) => _loadData(silent: true));
          },
        ),
      ),
    );
  }

  void _initWebsocket() {
    _wsService = WebsocketService(
      onEvent: (eventType, incident, rawData) {
        if (!mounted) return;
        if ((eventType == 'incident.critical' ||
                eventType == 'incident.created') &&
            incident != null) {
          if (_notifiedIncidentIds.add(incident.id)) {
            _apiService.saveKnownIncidentIds(_notifiedIncidentIds);
            _triggerPhoneNotification(incident);
          }
          // Insere o incidente na tela imediatamente em 0ms sem aguardar o GET
          setState(() {
            final existingIdx =
                _incidents.indexWhere((i) => i.id == incident.id);
            if (existingIdx == -1) {
              _incidents = [incident, ..._incidents];
            } else {
              final copy = List<IncidentSummary>.from(_incidents);
              copy[existingIdx] = incident;
              _incidents = copy;
            }
          });
        }
        _loadData(silent: true);
      },
    );
    _wsService!.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _wsService?.close();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final dependents = await _apiService.getDependents();
      final incidents = await _apiService.getIncidents();

      if (!mounted) return;

      if (!_initialSyncCompleted) {
        for (final inc in incidents) {
          _notifiedIncidentIds.add(inc.id);
        }
        _initialSyncCompleted = true;
      } else {
        for (final inc in incidents) {
          if (_notifiedIncidentIds.add(inc.id)) {
            _triggerPhoneNotification(inc);
          }
        }
      }

      setState(() {
        _dependents = dependents;
        _incidents = incidents;
        final exists = _dependents.any((d) => d.id == _selectedDependentId);
        if (_selectedDependentId != _allDependentsValue && !exists) {
          _selectedDependentId = _allDependentsValue;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _errorMessage = 'Erro ao carregar dados';
        });
      }
    } finally {
      _isFetching = false;
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<IncidentSummary> _filterIncidents() {
    if (_selectedDependentId == _allDependentsValue) {
      return _incidents;
    }
    return _incidents
        .where((incident) => incident.dependentId == _selectedDependentId)
        .toList();
  }

  int _getTotalSafeMessagesCount() {
    if (_selectedDependentId == _allDependentsValue) {
      return _dependents.fold<int>(0, (sum, d) => sum + d.safeMessagesCount);
    }
    final dep = _dependents.where((d) => d.id == _selectedDependentId).firstOrNull;
    return dep?.safeMessagesCount ?? 0;
  }

  String _truncatePreview(String text) {
    if (text.length <= 60) return text;
    return '${text.substring(0, 60)}...';
  }

  String _formatDateTime(String isoString) {
    final parsed = DateTime.tryParse(isoString)?.toLocal();
    if (parsed == null) return isoString;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year} às $hour:$minute';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'DETECTADO':
        return 'Detectado';
      case 'VISUALIZADO':
        return 'Visualizado';
      case 'EM_ANALISE':
        return 'Em análise';
      case 'CONVERSADO_COM_FILHO':
        return 'Conversei com meu filho';
      case 'ENCAMINHADO_A_ESCOLA':
        return 'Encaminhado à escola';
      case 'FALSO_POSITIVO':
        return 'Alarme falso';
      default:
        return status;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'VITIMA':
        return 'Recebeu a mensagem';
      case 'EMISSOR':
        return 'Enviou a mensagem';
      case 'ESPECTADOR':
        return 'Estava no grupo';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredIncidents = _filterIncidents();
    final safeCount = _getTotalSafeMessagesCount();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Feed de Incidentes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Atualizar Feed',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            tooltip: 'Configurações de Proteção',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: 'Sair da Conta',
            onPressed: () {
              _apiService.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0E58A8)),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF0E58A8),
                  onRefresh: _loadData,
                  child: Column(
                    children: [
                      // Filtro por Dependente Monitorado + Contador de Mensagens Seguras
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedDependentId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Dependente Monitorado',
                                prefixIcon: const Icon(
                                  Icons.child_care,
                                  color: Colors.black,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFDFCFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E2E2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E2E2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0E58A8),
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: _allDependentsValue,
                                  child: Text('Todos os dependentes'),
                                ),
                                ..._dependents.map((Dependent dependent) {
                                  return DropdownMenuItem<String>(
                                    value: dependent.id,
                                    child: Text(dependent.name),
                                  );
                                }),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedDependentId = newValue;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E58A8).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF0E58A8).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mensagens seguras descartadas (LGPD): $safeCount',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lista de Cards de Incidentes ou Estado Vazio Amigável
                      Expanded(
                        child: filteredIncidents.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height * 0.5,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.shield_outlined,
                                              size: 56,
                                              color: Colors.black,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Nenhum incidente detectado no momento.\nAs mensagens dos seus dependentes estão seguras.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                itemCount: filteredIncidents.length,
                                itemBuilder: (context, index) {
                                  final incident = filteredIncidents[index];
                                  final isCritical =
                                      incident.severity == 'CRITICO';
                                  final severityColor = isCritical
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFD97706);

                                  return Card(
                                    color: Colors.white,
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isCritical
                                            ? severityColor.withOpacity(0.5)
                                            : const Color(0xFFE5E7EB),
                                        width: isCritical ? 1.5 : 1,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    IncidentDetailScreen(
                                                  incidentId: incident.id,
                                                ),
                                              ),
                                            )
                                            .then((_) => _loadData());
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Linha 1: Badge de Severidade + Status Atual
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: severityColor
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    isCritical
                                                        ? 'CRÍTICO'
                                                        : 'COMUM',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: severityColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    _getStatusLabel(incident.status),
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.end,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: severityColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Linha 2: Nome do Dependente + Papel do Menor
                                            Text(
                                              '${incident.dependentName} - ${_getRoleLabel(incident.detectedRole)}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Linha 3: Prévia truncada em 60 caracteres
                                            Text(
                                              _truncatePreview(incident.preview),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            // Linha 4: Metadados (Confiança, Data/Hora e Alertas extras)
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 6,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  'Confiança: ${(incident.confidence * 100).round()}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  _formatDateTime(
                                                      incident.createdAt),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                if (incident.hasLink)
                                                  const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.link,
                                                        size: 15,
                                                        color: Colors.black,
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Link suspeito',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (incident.escalated)
                                                  const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.priority_high,
                                                        size: 14,
                                                        color: Colors.black,
                                                      ),
                                                      Text(
                                                        'Escalonado',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (incident.integrityMismatch)
                                                  const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.warning_amber,
                                                        size: 14,
                                                        color: Colors.black,
                                                      ),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'Divergência SHA-256',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          color: Colors.red,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}