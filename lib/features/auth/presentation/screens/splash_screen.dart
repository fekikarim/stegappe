import 'package:flutter/material.dart';

import '../../../../core/widgets/steg_states.dart';

/// Splash while [AuthController.bootstrap] restores the session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: StegLoading());
  }
}
