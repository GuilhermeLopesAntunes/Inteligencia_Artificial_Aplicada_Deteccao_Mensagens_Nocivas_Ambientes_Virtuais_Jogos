import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// TODO: trocar pelo ApiService real quando o backend for integrado
// import '../services/api_service.dart';
import '../services/mock_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // final ApiService _apiService = ApiService();
  final MockApiService _apiService = MockApiService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Ignora o resultado pois o token já foi salvo no ApiService
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/feed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'E-mail ou senha incorretos';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48.0).clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    SvgPicture.asset(
                      'assets/LogoApp.svg',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    // Título com fonte YuGothic
                    const Text(
                      'Acesse sua conta.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'YuGothic',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    // Subtítulo
                    Text(
                      'proteja quem você ama!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontFamily: 'YuGothic',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Email input
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Digite seu usuário',
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
                        prefixIcon: const Icon(Icons.person, color: Colors.black),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // Password input
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Digite sua senha',
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
                        prefixIcon: const Icon(Icons.lock, color: Colors.black),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.black,
                          ),
                          tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 24),
                    // Error message
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),
                    // Entrar button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
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
                              'ENTRAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Link para o formulário de registro
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Não possui uma Conta? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed('/register');
                          },
                          child: const Text(
                            'Registrar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0E58A8),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Dica temporária enquanto o app usa dados fictícios
                    Text(
                      'Modo demonstração\ntest@exemplo.com / senha123',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}