import 'package:flutter/material.dart';

/// Pantalla de carga mientras [GoRouter] resuelve auth y onboarding.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
