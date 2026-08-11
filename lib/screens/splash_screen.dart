import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.jpeg',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 24),
            const Text(
              'SPDDC',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'PRECISION. TRUST. EXCELLENCE.',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: Color(0xFFB8860B), // Rich Gold
              ),
            ),
          ],
        ),
      ),
    );
  }
}
