import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Overlapping couple avatar pair.
///
/// Shows two circular avatars with rose borders. The second avatar is
/// positioned slightly to the right and behind the first (lower z-order).
/// Falls back to a rose circle with the contact's initial when no URL is set.
///
/// Usage:
/// ```dart
/// CoupleAvatar(
///   myAvatarUrl: user.photoUrl,
///   partnerAvatarUrl: partner.photoUrl,
///   size: 40,
/// )
/// ```
class CoupleAvatar extends StatelessWidget {
  const CoupleAvatar({
    super.key,
    this.myAvatarUrl,
    this.partnerAvatarUrl,
    this.size = 40,
  });

  final String? myAvatarUrl;
  final String? partnerAvatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Total widget width: first avatar + half of second avatar offset
    final totalWidth = size + (size * 0.6);
    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Partner avatar (behind, offset right)
          Positioned(
            right: 0,
            child: _Avatar(
              url: partnerAvatarUrl,
              size: size,
              initial: 'P',
            ),
          ),
          // My avatar (in front)
          Positioned(
            left: 0,
            child: _Avatar(
              url: myAvatarUrl,
              size: size,
              initial: 'M',
            ),
          ),
        ],
      ),
    );
  }
}

/// Single circular avatar with rose border and initial fallback.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.size,
    required this.initial,
  });

  final String? url;
  final double size;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.rose, width: 2),
        color: AppColors.blush,
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Fallback(initial: initial, size: size),
                errorWidget: (_, __, ___) => _Fallback(initial: initial, size: size),
              )
            : _Fallback(initial: initial, size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppColors.rose.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.rose,
        ),
      ),
    );
  }
}
