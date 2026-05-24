import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SplashScreen
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ───────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _taglineCtrl;

  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    // Logo: 800 ms fade + slide
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));

    // Tagline: fades in 200 ms after logo starts
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineOpacity =
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut);

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Start logo animation
    _logoCtrl.forward();
    // Start tagline 200 ms later
    await Future.delayed(const Duration(milliseconds: 200));
    _taglineCtrl.forward();
    // Navigate after 2200 ms total
    await Future.delayed(const Duration(milliseconds: 2000));
    _navigate();
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('partner_id')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      final hasPartner = data != null && data['partner_id'] != null;
      context.go(hasPartner ? '/home' : '/link-partner');
    } catch (_) {
      if (!mounted) return;
      context.go('/link-partner');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // 135 deg gradient: deep → dark rose → deep
            stops: [0.0, 0.5, 1.0],
            colors: [
              Color(0xFF1A0A0F),
              Color(0xFF3D1020),
              Color(0xFF1A0A0F),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoOpacity,
                child: SlideTransition(
                  position: _logoSlide,
                  child: Text(
                    'Us',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 68,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Tagline ─────────────────────────────────────────────
              FadeTransition(
                opacity: _taglineOpacity,
                child: Text(
                  'made with love',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.roseLight,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heart CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _HeartIcon extends StatelessWidget {
  const _HeartIcon({
    required this.color,
    this.width = 40,
    this.height = 36,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _HeartPainter(color: color),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    // Classic heart shape built from cubic beziers
    path.moveTo(w * 0.5, h * 0.85);
    path.cubicTo(
      w * 0.1,
      h * 0.6,
      -w * 0.05,
      h * 0.35,
      w * 0.25,
      h * 0.2,
    );
    path.cubicTo(
      w * 0.4,
      h * 0.1,
      w * 0.5,
      h * 0.2,
      w * 0.5,
      h * 0.3,
    );
    path.cubicTo(
      w * 0.5,
      h * 0.2,
      w * 0.6,
      h * 0.1,
      w * 0.75,
      h * 0.2,
    );
    path.cubicTo(
      w * 1.05,
      h * 0.35,
      w * 0.9,
      h * 0.6,
      w * 0.5,
      h * 0.85,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.color != color;
}
