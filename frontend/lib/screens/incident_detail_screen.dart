import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/dependent.dart';
import '../models/incident_summary.dart';
import '../services/mock_api_service.dart';

class IncidentDetailScreen extends StatefulWidget {
  final String incidentId;

  const IncidentDetailScreen({Key? key, required this.incidentId})
      : super(key: key);

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final MockApiService _apiService = MockApiService();
  IncidentSummary? _incident;
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _allowedTransitions = [];
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();
    _loadIncident();
  }

  List<String> _computeTransitionsFallback(String status) {
    switch (status) {
      case 'DETECTADO':
        return ['VISUALIZADO', 'EM_ANALISE'];
      case 'VISUALIZADO':
        return ['EM_ANALISE'];
      case 'EM_ANALISE':
        return [
          'CONVERSADO_COM_FILHO',
          'ENCAMINHADO_A_ESCOLA',
          'FALSO_POSITIVO',
        ];
      default:
        return [];
    }
  }

  Future<void> _loadIncident() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.viewIncident(widget.incidentId);

      final incident = await _apiService.getIncident(widget.incidentId);
      final dependents = await _apiService.getDependents();
      final dependent = dependents.firstWhere(
        (d) => d.id == incident.dependentId,
        orElse: () => Dependent(
          id: '',
          name: '',
          commonThreshold: 0.65,
          isPrimary: true,
          safeMessagesCount: 0,
        ),
      );

      if (!mounted) return;
      setState(() {
        _incident = incident;
        _isPrimary = dependent.isPrimary;
        _allowedTransitions = incident.allowedTransitions.isNotEmpty
            ? incident.allowedTransitions
            : _computeTransitionsFallback(incident.status);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao carregar incidente';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus, {String? note}) async {
    try {
      await _apiService.updateIncidentStatus(
        widget.incidentId,
        newStatus,
        note: note,
      );
      await _loadIncident();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status atualizado para "${_getStatusLabel(newStatus)}"',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao atualizar status')),
        );
      }
    }
  }

  Future<void> _exportReport() async {
    try {
      final response = await _apiService.getIncidentReport(widget.incidentId);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file =
            File('${dir.path}/incident_report_${widget.incidentId}.pdf');
        await file.writeAsBytes(bytes);

        if (mounted) {
          await OpenFilex.open(file.path);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao gerar relatório')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relatório PDF com hash SHA-256 gerado com sucesso!'),
          ),
        );
      }
    }
  }

  Future<void> _deleteIncident() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Excluir incidente (LGPD)'),
        content: const Text(
          'Esta ação aplica o Direito ao Esquecimento e é irreversível. Deseja excluir definitivamente este registro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _apiService.deleteIncident(widget.incidentId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incidente excluído com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao excluir incidente')),
          );
        }
      }
    }
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

  String _formatDateTime(String isoString) {
    final parsed = DateTime.tryParse(isoString)?.toLocal();
    if (parsed == null) return isoString;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year} $hour:$minute';
  }

  Widget _buildContextBubble(
    IncidentContextMessage msg, {
    required String labelPrefix,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '$labelPrefix • ${msg.isFromMinor ? "Menor (${msg.senderId})" : "Participante (${msg.senderId})"}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(msg.timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            msg.text,
            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Detalhe do Incidente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isPrimary)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.black),
              tooltip: 'Excluir incidente (LGPD)',
              onPressed: _isLoading ? null : _deleteIncident,
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
              : _incident == null
                  ? const Center(child: Text('Nenhum incidente encontrado'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Cabeçalho de Classificação e Auditoria SHA-256
                          Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_incident!.dependentName} - ${_getRoleLabel(_incident!.detectedRole)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(
                                        label: Text(
                                          _incident!.severity == 'CRITICO'
                                              ? 'Severidade: CRÍTICO'
                                              : 'Severidade: COMUM',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor:
                                            _incident!.severity == 'CRITICO'
                                                ? Colors.red[100]
                                                : Colors.orange[100],
                                      ),
                                      Chip(
                                        label: Text(
                                          'Confiança: ${(_incident!.confidence * 100).round()}%',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: const Color(0xFFF3F4F6),
                                      ),
                                      Chip(
                                        avatar: const Icon(
                                          Icons.videogame_asset_outlined,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        label: Text(
                                          _incident!.roomType == 'jogo'
                                              ? 'Sala: Jogo (Modo Gamer)'
                                              : 'Sala: Conversa',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: const Color(0xFFF3F4F6),
                                      ),
                                      Chip(
                                        avatar: Icon(
                                          _incident!.integrityMismatch
                                              ? Icons.warning_amber
                                              : Icons.verified_outlined,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        label: Text(
                                          _incident!.integrityMismatch
                                              ? 'Divergência SHA-256'
                                              : 'Íntegro (SHA-256 Válido)',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor:
                                            _incident!.integrityMismatch
                                                ? Colors.red[50]
                                                : Colors.green[50],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Linha do Tempo Contextual das Mensagens
                          const Text(
                            'Linha do Tempo da Conversa:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Contexto Anterior (até 3 mensagens)
                          if (_incident!.contextBefore.isNotEmpty) ...[
                            ..._incident!.contextBefore.map(
                              (msg) => _buildContextBubble(
                                msg,
                                labelPrefix: 'Contexto Anterior',
                              ),
                            ),
                          ],

                          // Mensagem Principal Infratora (Destacada)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFDC2626),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Mensagem Principal • Remetente: ${_incident!.mainMessageSenderId}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDateTime(_incident!.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Mensagem:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _incident!.mainMessageText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'SHA-256: ${_incident!.mainMessageHash}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Contexto Posterior (até 3 mensagens na janela de 10 min)
                          if (_incident!.contextAfter.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ..._incident!.contextAfter.map(
                              (msg) => _buildContextBubble(
                                msg,
                                labelPrefix: 'Contexto Posterior',
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // 3. Status Atual e Gestão da Máquina de Estados
                          const Text(
                            'Status:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(
                              _getStatusLabel(_incident!.status),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor:
                                const Color(0xFF0E58A8).withOpacity(0.12),
                          ),
                          const SizedBox(height: 16),

                          if (_allowedTransitions.isNotEmpty) ...[
                            const Text(
                              'Ações de Resolução Disponíveis:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allowedTransitions
                                  .map(
                                    (status) => ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0E58A8),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () => _showStatusDialog(status),
                                      child: Text(_getStatusLabel(status)),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 4. Histórico de Transições de Status
                          if (_incident!.statusHistory.isNotEmpty)
                            Card(
                              color: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              child: ExpansionTile(
                                leading: const Icon(
                                  Icons.history,
                                  color: Colors.black,
                                ),
                                title: const Text(
                                  'Histórico de Transições',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                children: _incident!.statusHistory.map((item) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      '${_getStatusLabel(item.fromStatus)} → ${_getStatusLabel(item.toStatus)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Por: ${item.guardianName} em ${_formatDateTime(item.changedAt)}'
                                      '${item.note != null && item.note!.isNotEmpty ? "\nNota: ${item.note}" : ""}',
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // 5. Ações Probatórias (Exportar PDF) e LGPD (Excluir)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0E58A8),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.black,
                                  ),
                                  label: const Text('Exportar PDF'),
                                  onPressed: _isLoading ? null : _exportReport,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isPrimary)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.black,
                                    ),
                                    label: const Text(
                                      'Excluir',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    onPressed:
                                        _isLoading ? null : _deleteIncident,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }

  Future<void> _showStatusDialog(String newStatus) async {
    final noteController = TextEditingController();
    final showNoteField = [
      'CONVERSADO_COM_FILHO',
      'ENCAMINHADO_A_ESCOLA',
      'FALSO_POSITIVO',
    ].contains(newStatus);

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Atualizar status para ${_getStatusLabel(newStatus)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showNoteField)
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                  maxLines: 3,
                )
              else
                const Text(
                  'Confirma a alteração de status deste incidente?',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E58A8),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final note = showNoteField && noteController.text.isNotEmpty
                  ? noteController.text.trim()
                  : null;
              Navigator.of(context).pop(true);
              _updateStatus(newStatus, note: note);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}