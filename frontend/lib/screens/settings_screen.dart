import 'package:flutter/material.dart';
// TODO: trocar pelo ApiService real quando o backend for integrado
// import '../services/api_service.dart';
import '../services/mock_api_service.dart';
import '../models/dependent.dart';

class _SensitivityLevel {
  final String title;
  final String subtitle;
  final double threshold;
  final IconData icon;

  const _SensitivityLevel({
    required this.title,
    required this.subtitle,
    required this.threshold,
    required this.icon,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MockApiService _apiService = MockApiService();
  List<Dependent> _dependents = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, double> _thresholdValues = {};

  static const List<_SensitivityLevel> _levels = [
    _SensitivityLevel(
      title: 'Rigorosa',
      subtitle: 'Ideal para crianças menores. Registra qualquer indício moderado de ofensa.',
      threshold: 0.50,
      icon: Icons.shield,
    ),
    _SensitivityLevel(
      title: 'Equilibrada (Recomendado)',
      subtitle: 'Filtra ironias ou provocações leves e foca em ofensas claras.',
      threshold: 0.65,
      icon: Icons.verified_user,
    ),
    _SensitivityLevel(
      title: 'Flexível',
      subtitle: 'Ideal para adolescentes. Notifica apenas ofensas fortes e alertas críticos.',
      threshold: 0.80,
      icon: Icons.tune,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDependents();
  }

  Future<void> _loadDependents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dependents = await _apiService.getDependents();

      Map<String, double> thresholdValues = {};
      for (final dependent in dependents) {
        thresholdValues[dependent.id] = _normalizeToPreset(dependent.commonThreshold);
      }

      setState(() {
        _dependents = dependents;
        _thresholdValues = thresholdValues;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar dependentes';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Mapeia qualquer valor entre 0.50 e 0.84 para o nível pré-definido mais próximo (0.50, 0.65 ou 0.80)
  double _normalizeToPreset(double value) {
    if (value < 0.58) return 0.50;
    if (value < 0.73) return 0.65;
    return 0.80;
  }

  Future<void> _updateThreshold(String dependentId, double threshold) async {
    try {
      await _apiService.updateThreshold(dependentId, threshold);

      setState(() {
        _thresholdValues[dependentId] = threshold;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nível de proteção atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao atualizar nível de proteção')),
        );
      }
    }
  }

  String _getDependentLabel(Dependent dependent) {
    final primaryLabel = dependent.isPrimary ? ' (Primário)' : ' (Secundário)';
    return '${dependent.name}$primaryLabel';
  }

  Future<void> _showAddDependentDialog() async {
    final nameController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Adicionar Dependente'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nome do filho(a)',
            prefixIcon: Icon(Icons.child_care, color: Colors.black),
          ),
          autofocus: true,
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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirm == true && nameController.text.trim().isNotEmpty) {
      await _apiService.createDependent(name: nameController.text.trim());
      await _loadDependents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dependente cadastrado com sucesso!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Configurações de Proteção'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.black),
            tooltip: 'Adicionar Dependente',
            onPressed: _showAddDependentDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _dependents.isEmpty
                  ? const Center(child: Text('Nenhum dependente cadastrado'))
                  : ListView.builder(
                      itemCount: _dependents.length,
                      itemBuilder: (context, index) {
                        final dependent = _dependents[index];
                        final selectedThreshold =
                            _thresholdValues[dependent.id] ?? 0.65;

                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getDependentLabel(dependent),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Chip(
                                      avatar: const Icon(
                                        Icons.shield_outlined,
                                        size: 16,
                                        color: Colors.black,
                                      ),
                                      label: Text(
                                        'Seguras: ${dependent.safeMessagesCount}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: const Color(0xFFF3F4F6),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Escolha o nível de sensibilidade para alertas comuns:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._levels.map((level) {
                                  final isSelected =
                                      (selectedThreshold - level.threshold).abs() <
                                          0.01;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF0E58A8).withOpacity(0.08)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF0E58A8)
                                            : const Color(0xFFE5E7EB),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: RadioListTile<double>(
                                      value: level.threshold,
                                      groupValue: selectedThreshold,
                                      activeColor: const Color(0xFF0E58A8),
                                      secondary: Icon(
                                        level.icon,
                                        color: Colors.black,
                                      ),
                                      title: Text(
                                        level.title,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        level.subtitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      onChanged: dependent.isPrimary
                                          ? (value) {
                                              if (value != null) {
                                                _updateThreshold(
                                                    dependent.id, value);
                                              }
                                            }
                                          : null,
                                    ),
                                  );
                                }),
                                const SizedBox(height: 4),
                                Text(
                                  'Proteções Fixas: Alertas Críticos (≥ 85%) e piso do Modo Gamer (≥ 70% em salas de jogo) são aplicados automaticamente pelo sistema.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (!dependent.isPrimary)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Apenas o responsável primário pode alterar o nível de proteção.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}