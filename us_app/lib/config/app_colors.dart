import 'package:flutter/material.dart';

/// All brand color tokens for the Us app.
class AppColors {
  AppColors._();

  // ── Primary rose palette ─────────────────────────────────
  static const Color rose      = Color(0xFFE8607A);
  static const Color roseLight = Color(0xFFF4A3B3);
  static const Color rosePale  = Color(0xFFFDF0F3);
  static const Color blush     = Color(0xFFF9E4EA);
  static const Color mauve     = Color(0xFFC97B93);

  // ── Neutral / text ──────────────────────────────────────
  static const Color deep      = Color(0xFF1A0A0F);
  static const Color mid       = Color(0xFF4A2535);
  static const Color muted     = Color(0xFF8A6070);
  static const Color cream     = Color(0xFFFEFAF9);

  // ── Dark-mode surfaces ───────────────────────────────────
  static const Color darkBg     = Color(0xFF0F0509);
  static const Color darkCard   = Color(0xFF1E0D14);
  static const Color darkBorder = Color(0xFF3D1525);

  // ── Semantic ─────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF7D);
  static const Color warning = Color(0xFFE6A817);
}
