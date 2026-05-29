import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// V2 typography system — Playfair Display (headings), DM Sans (body), DM Mono (numbers).
/// No italic variants anywhere.
class AppTextStyles {
  AppTextStyles._();

  // ── Display / Hero ────────────────────────────────────────────────────────
  static TextStyle display({Color? color, double? fontSize}) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize ?? 32,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle headline({Color? color, double? fontSize}) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize ?? 24,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle headlineMedium({Color? color, double? fontSize}) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize ?? 20,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  // ── Body ─────────────────────────────────────────────────────────────────
  static TextStyle titleLarge({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle titleMedium({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 16,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle body({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle bodyMedium({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 14,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle caption({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 12,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.muted,
        fontStyle: FontStyle.normal,
      );

  static TextStyle captionMedium({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.muted,
        fontStyle: FontStyle.normal,
      );

  static TextStyle label({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 11,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.muted,
        fontStyle: FontStyle.normal,
        letterSpacing: 0.8,
      );

  // ── Mono (numbers, codes) ─────────────────────────────────────────────────
  static TextStyle mono({Color? color, double? fontSize}) =>
      GoogleFonts.dmMono(
        fontSize: fontSize ?? 14,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  static TextStyle monoLarge({Color? color, double? fontSize}) =>
      GoogleFonts.dmMono(
        fontSize: fontSize ?? 28,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.deep,
        fontStyle: FontStyle.normal,
      );

  // ── Button text ───────────────────────────────────────────────────────────
  static TextStyle button({Color? color, double? fontSize}) =>
      GoogleFonts.dmSans(
        fontSize: fontSize ?? 15,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white,
        fontStyle: FontStyle.normal,
        letterSpacing: 0.3,
      );

  // ── AppBar title ──────────────────────────────────────────────────────────
  static TextStyle appBar({Color? color}) =>
      GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.rose,
        fontStyle: FontStyle.normal,
      );
}
