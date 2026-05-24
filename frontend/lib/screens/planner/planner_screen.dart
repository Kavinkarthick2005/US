import 'package:flutter/material.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF9),
      body: const Center(
        child: Text(
          'Planner Screen',
          style: TextStyle(color: Color(0xFF1A0A0F), fontSize: 20),
        ),
      ),
    );
  }
}
