import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subtitleColor;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.textColor = Colors.white,
    this.subtitleColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .slideY(duration: 1500.ms, begin: 0, end: 0.15, curve: Curves.easeInOut),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class GenericErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color textColor;

  const GenericErrorState({
    super.key,
    this.message = 'Something went wrong.',
    required this.onRetry,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, color: textColor.withValues(alpha: 0.8)),
            label: Text(
              'Try again',
              style: GoogleFonts.dmSans(
                color: textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
