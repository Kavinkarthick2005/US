import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

/// Animated gradient header for each of the three spaces.
/// Shows a space emoji, title, subtitle, and optional avatar row.
class SpaceHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Widget? trailingWidget;
  final Widget? avatarWidget;

  const SpaceHeader({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    this.trailingWidget,
    this.avatarWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 32),
                  )
                      .animate()
                      .scale(
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                        begin: const Offset(0.5, 0.5),
                      ),
                  if (trailingWidget != null) trailingWidget!,
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontStyle: FontStyle.normal,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontStyle: FontStyle.normal,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms),
              if (avatarWidget != null) ...[
                const SizedBox(height: 16),
                avatarWidget!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact header for inner screens (non-home, non-hub).
class SpaceSubHeader extends StatelessWidget {
  final String title;
  final List<Color> gradientColors;
  final VoidCallback? onBack;
  final Widget? action;

  const SpaceSubHeader({
    super.key,
    required this.title,
    required this.gradientColors,
    this.onBack,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated couple avatar row — his & her avatars with a heart between.
class CoupleAvatarBanner extends StatelessWidget {
  final String? myAvatarUrl;
  final String? partnerAvatarUrl;
  final String myName;
  final String partnerName;
  final int daysTogether;
  final Color accentColor;

  const CoupleAvatarBanner({
    super.key,
    this.myAvatarUrl,
    this.partnerAvatarUrl,
    required this.myName,
    required this.partnerName,
    required this.daysTogether,
    this.accentColor = AppColors.rose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Avatar(url: myAvatarUrl, name: myName, accentColor: accentColor)
            .animate()
            .slideX(begin: -0.5, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        const SizedBox(width: 12),
        Column(
          children: [
            const Text('💕', style: TextStyle(fontSize: 24))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: 1200.ms,
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1.15, 1.15),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 4),
            Text(
              '$daysTogether days',
              style: GoogleFonts.dmMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
                fontStyle: FontStyle.normal,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        _Avatar(url: partnerAvatarUrl, name: partnerName, accentColor: accentColor)
            .animate()
            .slideX(begin: 0.5, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final Color accentColor;

  const _Avatar({this.url, required this.name, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            color: accentColor.withValues(alpha: 0.3),
            image: url != null && url!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(url!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: url == null || url!.isEmpty
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
            fontStyle: FontStyle.normal,
          ),
        ),
      ],
    );
  }
}
