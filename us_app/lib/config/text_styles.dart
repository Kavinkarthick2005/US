import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralised typography tokens for the Us app.
class AppText {
  AppText._();

  /// Playfair Display 28sp italic — hero headlines
  static TextStyle get display => GoogleFonts.playfairDisplay(
        fontSize: 28,
        
        fontWeight: FontWeight.w700,
        color: AppColors.deep,
      );

  /// Playfair Display 22sp bold — section headings
  static TextStyle get heading => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.deep,
      );

  /// DM Sans 18sp w500 — card / list titles
  static TextStyle get title => GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.deep,
      );

  /// DM Sans 14sp w400 — body copy
  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.mid,
      );

  /// DM Sans 12sp w400 — captions, timestamps
  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      );

  /// DM Mono 12sp — code / mono snippets
  static TextStyle get mono => GoogleFonts.dmMono(
        fontSize: 12,
        color: AppColors.muted,
      );
}
