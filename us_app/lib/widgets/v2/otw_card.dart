import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../providers/location_provider.dart';
import '../../widgets/v2/glass_container.dart';

class OtwCard extends ConsumerWidget {
  final bool isMyShare;
  
  const OtwCard({super.key, required this.isMyShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);

    if (isMyShare && !locationState.isSharing) {
      return const SizedBox.shrink();
    }
    if (!isMyShare && !locationState.partnerSharing && !locationState.partnerArrived) {
      return const SizedBox.shrink();
    }

    final glowColor = isMyShare ? AppColors.rose : const Color(0xFF4ADE80); // Rose for me, Green for partner
    
    String title = '';
    String message = '';
    String etaText = '';
    VoidCallback onButtonTap = () {};
    String buttonText = '';
    Color buttonColor = glowColor;

    if (isMyShare) {
      title = "📍 You're sharing location";
      message = locationState.activeMessage;
      buttonText = 'Stop Sharing Immediately';
      buttonColor = Colors.redAccent;
      onButtonTap = () {
        ref.read(locationProvider.notifier).stopSharing();
      };
      // Simple ETA calculation or expiration check for UI
      etaText = locationState.destinationLat != null 
          ? 'Calculating ETA...' 
          : 'Active until ${locationState.expiresAt?.hour.toString().padLeft(2, '0')}:${locationState.expiresAt?.minute.toString().padLeft(2, '0')}';
    } else {
      title = "📍 Partner is on the way 💕";
      message = locationState.partnerMessage;
      
      if (locationState.partnerArrived) {
        etaText = 'Arrived!';
        buttonText = 'Got it 💕';
        onButtonTap = () {
          ref.read(locationProvider.notifier).acknowledgeArrival();
        };
      } else {
        if (locationState.partnerEtaMinutes != null) {
          etaText = 'About ${locationState.partnerEtaMinutes} min away (Estimated)';
        } else {
          etaText = 'Location shared';
        }
        buttonText = 'Acknowledge';
        onButtonTap = () {
           ref.read(locationProvider.notifier).acknowledgeArrival();
        };
      }
    }

    return Animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).custom(
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        final double animValue = value as double;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.1 + (0.15 * animValue)),
                blurRadius: 15.0 + (10.0 * animValue),
                spreadRadius: 1.0 + (3.0 * animValue),
              ),
            ],
          ),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            border: Border.all(color: glowColor.withValues(alpha: 0.5), width: 1.5),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                Icon(
                  Icons.near_me_rounded,
                  color: glowColor,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                color: Colors.white,
                fontStyle: FontStyle.normal,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                etaText,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: glowColor,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isMyShare || locationState.partnerArrived)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onButtonTap,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: buttonColor),
                    foregroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
      },
    );
  }
}
