import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Easter egg overlay — shown after long-pressing the logo 7 times on splash.
/// Never referenced in any public UI label or comment that reveals the meaning.
class EasterEggOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const EasterEggOverlay({super.key, required this.onDismiss});

  @override
  State<EasterEggOverlay> createState() => _EasterEggOverlayState();
}

class _EasterEggOverlayState extends State<EasterEggOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _heartControllers;
  final _heartCount = 12;

  @override
  void initState() {
    super.initState();
    _heartControllers = List.generate(
      _heartCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1200 + (i * 80)),
      )..repeat(),
    );
  }

  @override
  void dispose() {
    for (final c in _heartControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF120308), Color(0xFF2E0D16)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Floating hearts
              ..._buildFloatingHearts(size),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '💕',
                      style: TextStyle(fontSize: 72),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          duration: 900.ms,
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.1, 1.1),
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 24),
                    Text(
                      'Made with love',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontStyle: FontStyle.normal,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      'for Kavin & Varsha',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontStyle: FontStyle.normal,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 400.ms)
                        .slideY(begin: 0.3, end: 0, delay: 400.ms),
                    const SizedBox(height: 6),
                    const Text(
                      '💕',
                      style: TextStyle(fontSize: 24),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 600.ms),
                    const SizedBox(height: 48),
                    Text(
                      'tap to dismiss',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontStyle: FontStyle.normal,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 1000.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(1.05, 1.05), end: const Offset(1, 1));
  }

  List<Widget> _buildFloatingHearts(Size size) {
    final emojis = ['💕', '❤️', '🌸', '💖', '✨', '💗'];
    return List.generate(_heartCount, (i) {
      final left  = (i / _heartCount) * size.width;
      final emoji = emojis[i % emojis.length];

      return Positioned(
        left: left,
        bottom: 0,
        child: AnimatedBuilder(
          animation: _heartControllers[i],
          builder: (_, __) {
            final progress = _heartControllers[i].value;
            return Transform.translate(
              offset: Offset(
                15 * (i.isEven ? 1 : -1) * progress,
                -size.height * 1.2 * progress,
              ),
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 1.0),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 14 + (i % 3) * 6.0),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// Mixin for logo tap detector — tracks 7 consecutive long-presses within 3s.
mixin LogoEasterEggMixin<T extends StatefulWidget> on State<T> {
  int _tapCount = 0;
  DateTime? _lastTap;
  bool _overlayShown = false;

  void handleLogoLongPress() {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!).inSeconds > 3) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 7 && !_overlayShown) {
      _tapCount = 0;
      _showEasterEgg();
    }
  }

  void _showEasterEgg() {
    setState(() => _overlayShown = true);
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) => EasterEggOverlay(
        onDismiss: () {
          Navigator.of(ctx).pop();
          setState(() => _overlayShown = false);
        },
      ),
    );
  }
}
