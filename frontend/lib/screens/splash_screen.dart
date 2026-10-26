import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/mock_api_service.dart';
import 'login_screen.dart';
import 'feed_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    final results = await Future.wait<dynamic>([
      MockApiService().restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    final bool isAuth = results.first == true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => isAuth ? const FeedScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/LogoApp.svg',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 46),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF0E58A8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}