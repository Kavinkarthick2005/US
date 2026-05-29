import 'package:flutter/material.dart';

/// All brand color tokens for the Us app — V2.
class AppColors {
  AppColors._();

  // ── Primary rose palette ──────────────────────────────────────────────────
  static const Color rose      = Color(0xFFE8607A);
  static const Color roseLight = Color(0xFFF4A3B3);
  static const Color rosePale  = Color(0xFFFDF0F3);
  static const Color blush     = Color(0xFFF9E4EA);
  static const Color mauve     = Color(0xFFC97B93);

  // ── Neutral / text ────────────────────────────────────────────────────────
  static const Color deep      = Color(0xFF1A0A0F);
  static const Color mid       = Color(0xFF4A2535);
  static const Color muted     = Color(0xFF8A6070);
  static const Color cream     = Color(0xFFFEFAF9);

  // ── Dark-mode surfaces ────────────────────────────────────────────────────
  static const Color darkBg     = Color(0xFF0F0509);
  static const Color darkCard   = Color(0xFF1E0D14);
  static const Color darkBorder = Color(0xFF3D1525);

  // ── Gold accent (Date Night / Us Space) ───────────────────────────────────
  static const Color gold      = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFEDD97A);
  static const Color goldMuted = Color(0xFF8A7A50);

  // ── He Space ─────────────────────────────────────────────────────────────
  static const Color heSpacePrimary    = Color(0xFFE8607A);
  static const Color heSpaceAccent     = Color(0xFF1A0A0F);
  static const Color heSpaceCard       = Color(0xFF1E0D14);
  static const Color heSpaceBg         = Color(0xFF0F0509);
  static const Color heSpaceGlow       = Color(0xFFE8607A);

  // ── She Space ────────────────────────────────────────────────────────────
  static const Color sheSpacePrimary   = Color(0xFFC97B93);
  static const Color sheSpaceAccent    = Color(0xFFF9E4EA);
  static const Color sheSpaceCard      = Color(0xFFFFFFFF);
  static const Color sheSpaceBg        = Color(0xFFFEFAF9);
  static const Color sheSpaceGlow      = Color(0xFFC97B93);

  // ── Us Space ─────────────────────────────────────────────────────────────
  static const Color usSpacePrimary    = Color(0xFFD4AF37);
  static const Color usSpaceAccent     = Color(0xFF1A0A0F);
  static const Color usSpaceCard       = Color(0xFF1E0D14);
  static const Color usSpaceBg         = Color(0xFF0A0305);
  static const Color usSpaceGlow       = Color(0xFFD4AF37);

  // ── The Originals (secret theme) ─────────────────────────────────────────
  static const Color originBg          = Color(0xFF120308);
  static const Color originCard        = Color(0xFF1F0610);
  static const Color originText        = Color(0xFFF0E6D3);
  static const Color originTextSub     = Color(0xFFD4B896);
  static const Color originTextMuted   = Color(0xFF8A6B5A);
  static const Color originBorder      = Color(0xFF3E0E1E);
  static const Color originAccent      = Color(0xFFD4AF37);
  static const Color originInput       = Color(0xFF190408);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF7D);
  static const Color warning = Color(0xFFE6A817);
  static const Color error   = Color(0xFFE85C5C);

  // ── Space gradient helpers ────────────────────────────────────────────────
  static const List<Color> heGradient = [Color(0xFFE8607A), Color(0xFF9B2647)];
  static const List<Color> sheGradient = [Color(0xFFC97B93), Color(0xFFE8A0B4)];
  static const List<Color> usGradient  = [Color(0xFF1A0A0F), Color(0xFF3D1525)];
  static const List<Color> goldGradient = [Color(0xFFD4AF37), Color(0xFF9B7D1A)];
}
