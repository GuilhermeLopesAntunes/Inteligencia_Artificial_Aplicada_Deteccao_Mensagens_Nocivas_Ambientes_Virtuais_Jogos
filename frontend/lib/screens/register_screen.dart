import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/mock_api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _dependentNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  final MockApiService _apiService = MockApiService();
  bool _useInviteCode = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final dependentName = _dependentNameController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Preencha todos os dados do responsável.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'As senhas não coincidem.';
      });
      return;
    }

    if (!_useInviteCode && dependentName.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o nome do filho(a) que será monitorado.';
      });
      return;
    }

    if (_useInviteCode && inviteCode.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o código de convite ou ID do dependente.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.register(
        name: name,
        email: email,
        password: password,
        dependentName: _useInviteCode ? null : dependentName,
        inviteCode: _useInviteCode ? inviteCode : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _useInviteCode
                  ? 'Conta criada e vinculada como Responsável Secundário!'
                  : 'Conta criada e dependente "$dependentName" vinculado com sucesso!',
            ),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/feed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: const Color(0xFFFDFCFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFF0E58A8), width: 2),
      ),
      prefixIcon: Icon(icon, color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Criar Conta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SvgPicture.asset(
                'assets/LogoApp.svg',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                'Crie sua conta.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'YuGothic',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'proteja quem você ama!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'YuGothic',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                  label: 'Nome do responsável',
                  icon: Icons.badge_outlined,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: _buildInputDecoration(
                  label: 'Digite seu e-mail',
                  icon: Icons.email_outlined,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: _buildInputDecoration(
                  label: 'Crie uma senha',
                  icon: Icons.lock_outline,
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: _buildInputDecoration(
                  label: 'Confirme sua senha',
                  icon: Icons.lock,
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Vínculo com a Criança (Dependente)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Cadastrar Filho(a)'),
                      selected: !_useInviteCode,
                      selectedColor: const Color(0xFF0E58A8).withOpacity(0.15),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _useInviteCode = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Usar Código'),
                      selected: _useInviteCode,
                      selectedColor: const Color(0xFF0E58A8).withOpacity(0.15),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _useInviteCode = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_useInviteCode)
                TextField(
                  controller: _dependentNameController,
                  decoration: _buildInputDecoration(
                    label: 'Nome do filho(a) / dependente',
                    hint: 'Ex.: Gabriel',
                    icon: Icons.child_care,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                )
              else
                TextField(
                  controller: _inviteCodeController,
                  decoration: _buildInputDecoration(
                    label: 'Código de convite ou ID (ex.: dep-001)',
                    icon: Icons.vpn_key_outlined,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E58A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'REGISTRAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dependentNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }
}
