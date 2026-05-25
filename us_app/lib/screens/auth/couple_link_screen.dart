import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_colors.dart';
import '../../providers/couple_provider.dart';
import '../../utils/pronoun_helper.dart';
import '../../widgets/rose_button.dart';

class CoupleLinkScreen extends ConsumerStatefulWidget {
  const CoupleLinkScreen({super.key});

  @override
  ConsumerState<CoupleLinkScreen> createState() => _CoupleLinkScreenState();
}

class _CoupleLinkScreenState extends ConsumerState<CoupleLinkScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  bool _isLinking = false;
  bool _showConfetti = false;

  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _onLink() async {
    if (_codeController.text.length < 6) return;

    setState(() => _isLinking = true);
    try {
      await ref.read(coupleProvider.notifier).linkPartner(_codeController.text);

      setState(() {
        _isLinking = false;
        _showConfetti = true;
      });
      _confettiController.forward();

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _isLinking = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Code not found. Check and try again."),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  // ── Share Helpers ─────────────────────────────────────────────────────────

  String _shareMessage(String code) =>
      'Download the Us app and enter my couple code: $code 💕';

  String _deepLink(String code) =>
      'https://usapp.link/join?code=$code';

  Future<void> _copyDeepLink(String code) async {
    _copyToClipboard(_deepLink(code), 'Deep link copied to clipboard!');
  }

  Future<void> _nativeShare(String code) async {
    if (kIsWeb) {
      // For web — try navigator.share via url_launcher fallback
      _copyToClipboard(_shareMessage(code), 'Copied! Share this code with your partner.');
    } else {
      try {
        await Share.share(
          _shareMessage(code),
          subject: 'Join me on Us app!',
        );
      } catch (_) {
        _copyToClipboard(_shareMessage(code), 'Copied to clipboard.');
      }
    }
  }

  void _copyToClipboard(String text, String snackMsg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snackMsg), backgroundColor: AppColors.rose),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = ref.watch(coupleProvider);
    final pronoun = coupleState.valueOrNull?.currentUser?.partnerPronoun ?? 'she';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 80, bottom: 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.rose, AppColors.mauve],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Connect with ${PronounHelper.object(pronoun).toLowerCase()} 💕",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // SECTION 1 — YOUR CODE
                coupleState.when(
                  data: (state) => _buildYourCodeCard(
                      state.currentUser?.coupleCode ?? "------"),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text("Error: $e"),
                ),

                const SizedBox(height: 16),
                Text(
                  "— or —",
                  style: GoogleFonts.dmSans(color: AppColors.muted),
                ),
                const SizedBox(height: 16),

                // SECTION 2 — ENTER CODE
                _buildEnterCodeCard(pronoun),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => context.go('/home'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.rose,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Set up data first & link later",
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_showConfetti) _ConfettiOverlay(controller: _confettiController),
        ],
      ),
    );
  }

  Widget _buildYourCodeCard(String code) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "YOUR CODE",
            style: GoogleFonts.dmMono(
              fontSize: 11,
              color: AppColors.rose,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.rosePale, width: 2),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.rosePale.withValues(alpha: 0.2),
            ),
            child: Text(
              code,
              style: GoogleFonts.dmMono(
                fontSize: 32,
                color: AppColors.deep,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Share row — 2 buttons
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  label: 'Copy Link',
                  icon: Icons.link_rounded,
                  color: AppColors.rose,
                  onTap: () => _copyDeepLink(code),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareButton(
                  label: 'Share',
                  icon: Icons.share_rounded,
                  color: AppColors.mauve,
                  onTap: () => _nativeShare(code),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Copy code button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deep,
              side: const BorderSide(color: AppColors.blush),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
            onPressed: () => _copyToClipboard(code, 'Code copied to clipboard!'),
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.rose),
            label: Text(
              'Copy Code',
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            "Give this code to your partner",
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterCodeCard(String pronoun) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "${PronounHelper.possessive(pronoun).toUpperCase()} CODE",
            style: GoogleFonts.dmMono(
              fontSize: 11,
              color: AppColors.rose,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.dmMono(
              fontSize: 32,
              color: AppColors.deep,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: "XXXXXX",
              hintStyle: TextStyle(color: AppColors.blush),
              counterText: "",
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.blush, width: 2),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.rose, width: 2),
              ),
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 32),
          RoseButton(
            label: "Link Up 💕",
            isLoading: _isLinking,
            onTap: _codeController.text.length == 6 ? _onLink : null,
          ),
        ],
      ),
    );
  }
}

// ── Share Button ──────────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confetti ──────────────────────────────────────────────────────────────────

class _ConfettiOverlay extends StatelessWidget {
  final AnimationController controller;

  const _ConfettiOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final random = Random();

    final List<Map<String, dynamic>> particles = List.generate(20, (index) {
      return {
        'x': random.nextDouble() * size.width,
        'delay': random.nextDouble(),
        'color': [
          AppColors.rose,
          AppColors.mauve,
          AppColors.warning
        ][random.nextInt(3)],
        'size': 8.0 + random.nextDouble() * 8.0,
      };
    });

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            children: particles.map((p) {
              final progress =
                  (controller.value - (p['delay'] * 0.3)).clamp(0.0, 1.0);
              final y = progress * size.height;
              return Positioned(
                left: p['x'],
                top: -20 + y,
                child: Opacity(
                  opacity: 1.0 - progress,
                  child: Container(
                    width: p['size'],
                    height: p['size'],
                    decoration: BoxDecoration(
                      color: p['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
