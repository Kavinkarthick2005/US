import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/v2/easter_egg_overlay.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin, LogoEasterEggMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _navigate();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('gender')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          if (profile == null || profile['gender'] == null) {
            context.go('/onboarding');
          } else {
            context.go('/us-space');
          }
        }
      } catch (_) {
        if (mounted) context.go('/us-space');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF0F0509),
                  Color(0xFF1E0D14),
                  Color(0xFF2E1020),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [
                  0.0,
                  0.5 + _bgController.value * 0.2,
                  1.0,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Ambient glow circles
                _GlowCircle(
                  color: const Color(0xFFE8607A),
                  size: 280,
                  top: -60,
                  left: -80,
                  opacity: 0.12 + _bgController.value * 0.05,
                ),
                _GlowCircle(
                  color: const Color(0xFFC97B93),
                  size: 200,
                  bottom: 40,
                  right: -60,
                  opacity: 0.10 + _bgController.value * 0.04,
                ),

                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo — long-press triggers Easter egg
                      GestureDetector(
                        onLongPress: handleLogoLongPress,
                        child: Column(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE8607A),
                                    Color(0xFFC97B93),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE8607A)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Us',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                              ),
                            )
                                .animate(
                                  onPlay: (c) =>
                                      c.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(0.97, 0.97),
                                  end: const Offset(1.03, 1.03),
                                  duration: 2000.ms,
                                  curve: Curves.easeInOut,
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'a space only for us',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.55),
                          fontStyle: FontStyle.normal,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 500.ms),

                      const SizedBox(height: 64),

                      // Loading indicator
                      SizedBox(
                        width: 40,
                        child: LinearProgressIndicator(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE8607A)),
                          minHeight: 2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 800.ms),
                    ],
                  ),
                ),

                // Version tag
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Text(
                    'V2',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmMono(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.2),
                      fontStyle: FontStyle.normal,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 1200.ms),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double opacity;

  const _GlowCircle({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
