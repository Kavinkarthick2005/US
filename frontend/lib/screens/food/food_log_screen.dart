import 'package:flutter/material.dart';

class FoodLogScreen extends StatelessWidget {
  const FoodLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF9),
      body: const Center(
        child: Text(
          'Food Log Screen',
          style: TextStyle(color: Color(0xFF1A0A0F), fontSize: 20),
        ),
      ),
    );
  }
}
