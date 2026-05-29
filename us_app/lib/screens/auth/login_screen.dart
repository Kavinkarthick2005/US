import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign in failed. Please try again.',
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null) {
        Supabase.instance.client
            .from('profiles')
            .select('gender')
            .eq('id', user.id)
            .maybeSingle()
            .then((profile) {
              if (mounted) {
                if (profile == null || profile['gender'] == null) {
                  context.go('/onboarding');
                } else {
                  context.go('/us-space');
                }
              }
            }).catchError((_) {
              if (mounted) context.go('/us-space');
            });
      }
    });

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
                  Color(0xFF2A0F1A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5 + _bgController.value * 0.15, 1.0],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Ambient glows
                  Positioned(
                    top: -40,
                    right: -60,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.rose
                            .withValues(alpha: 0.10 + _bgController.value * 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    left: -80,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mauve
                            .withValues(alpha: 0.08 + _bgController.value * 0.03),
                      ),
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Logo + tagline
                        Column(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.rose,
                                    AppColors.mauve,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.rose
                                        .withValues(alpha: 0.35),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Us',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .scale(
                                  duration: 700.ms,
                                  curve: Curves.elasticOut,
                                  begin: const Offset(0.5, 0.5),
                                ),
                            const SizedBox(height: 20),
                            Text(
                              'Your relationship,',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontStyle: FontStyle.normal,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 200.ms),
                            Text(
                              'beautifully kept.',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.rose,
                                fontStyle: FontStyle.normal,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 350.ms),
                            const SizedBox(height: 12),
                            Text(
                              'He Space • Us Space • She Space',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.45),
                                fontStyle: FontStyle.normal,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 500.ms),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // Features strip
                        _FeaturesRow()
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 600.ms),

                        const Spacer(flex: 1),

                        // Google sign-in button
                        _GoogleSignInButton(
                          isLoading: _isLoading,
                          onTap: _signIn,
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 700.ms)
                            .slideY(
                              begin: 0.3,
                              end: 0,
                              delay: 700.ms,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 20),
                        Text(
                          'Private by design. Just the two of you.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                            fontStyle: FontStyle.normal,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 900.ms),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      ('📸', 'Drops'),
      ('💌', 'Letters'),
      ('💰', 'Expenses'),
      ('🌸', 'Cycle'),
      ('🤖', 'AI'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: features
          .map(((String emoji, String label) f) => Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.rose.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.rose.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(f.$1,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    f.$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.rose),
                ),
              )
            else ...[
              // Google G icon
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Text(
                  'G',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A0A0F),
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
