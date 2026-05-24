import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: const Center(
        child: Text(
          'Login Screen',
          style: TextStyle(color: Color(0xFFF9E4EA), fontSize: 20),
        ),
      ),
    );
  }
}
