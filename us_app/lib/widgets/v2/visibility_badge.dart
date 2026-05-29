import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VisibilityBadge extends StatelessWidget {
  final String visibility; // 'private' | 'partner_visible' | 'shared'
  final bool compact;

  const VisibilityBadge({
    super.key,
    required this.visibility,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    Color color;
    Color bgColor;

    switch (visibility) {
      case 'private':
        icon = Icons.lock_rounded;
        label = 'Private';
        color = const Color(0xFFFFB3C6);
        bgColor = const Color(0xFF9B2647).withValues(alpha: 0.18);
        break;
      case 'partner_visible':
        icon = Icons.visibility_rounded;
        label = 'For Her';
        color = const Color(0xFFC97B93);
        bgColor = const Color(0xFFC97B93).withValues(alpha: 0.15);
        break;
      case 'shared':
      default:
        icon = Icons.favorite_rounded;
        label = 'Shared';
        color = const Color(0xFFE8607A);
        bgColor = const Color(0xFFE8607A).withValues(alpha: 0.15);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.bold,
              color: color,
              fontStyle: FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
