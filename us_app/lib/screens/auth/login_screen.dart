import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/rose_button.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Listen for errors and show snackbar
    ref.listen(authProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
            colors: [
              Color(0xFF1A0A0F),
              Color(0xFF3D1020),
              Color(0xFF1A0A0F),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative Area (Top 42%)
            Positioned(
              top: -50,
              right: -50,
              child: _BlurredCircle(
                color: AppColors.rose.withValues(alpha: 0.4),
                size: 200,
              ),
            ),
            Positioned(
              top: 150,
              left: -40,
              child: _BlurredCircle(
                color: AppColors.mauve.withValues(alpha: 0.3),
                size: 150,
              ),
            ),

            Column(
              children: [
                const Spacer(flex: 42),
                // Bottom Container (Bottom 58%)
                Expanded(
                  flex: 58,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 26,
                              color: AppColors.deep,
                              height: 1.2,
                            ),
                            children: [
                              const TextSpan(text: "Your love story,\n"),
                              TextSpan(
                                text: "starts here.",
                                style: GoogleFonts.playfairDisplay(
                                  
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Everything in one place. Just for the two of you.",
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 40),
                        RoseButton(
                          label: "Continue with Google",
                          isLoading: isLoading,
                          onTap: () => ref.read(authProvider.notifier).signInWithGoogle(),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            "Private. Just the two of you.",
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurredCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurredCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
