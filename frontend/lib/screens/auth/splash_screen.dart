import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Wait for animation + any async session check
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      context.go('/login');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final partnerId = user?.userMetadata?['partner_id'] as String?;

    if (partnerId == null || partnerId.isEmpty) {
      context.go('/link-partner');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: const Center(
          child: Text(
            'us',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontStyle: FontStyle.italic,
              fontSize: 64,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8607A),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
