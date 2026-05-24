import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Base Palette
  static const rose = Color(0xFFE8607A);
  static const roseLight = Color(0xFFF4A3B3);
  static const blush = Color(0xFFF9E4EA);
  static const mauve = Color(0xFFC97B93);
  static const deep = Color(0xFF1A0A0F);
  static const cream = Color(0xFFFEFAF9);
  static const darkBg = Color(0xFF0F0509);

  // Mood Theme Accents
  static const cozyMaroon = Color(0xFF4A1020);
  static const cozyAmber = Color(0xFFFCA311);
  static const rainyBlueGrey = Color(0xFF5A6B7C);
  static const dateGold = Color(0xFFD4AF37);
}

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.bold,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.bold,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
         color: textColor, fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.dmSans(color: textColor, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.dmSans(color: textColor, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.dmSans(color: textColor),
      bodyMedium: GoogleFonts.dmSans(color: textColor),
      bodySmall: GoogleFonts.dmSans(color: textColor),
      labelLarge: GoogleFonts.dmMono(color: textColor),
      labelMedium: GoogleFonts.dmMono(color: textColor),
      labelSmall: GoogleFonts.dmMono(color: textColor),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      primaryColor: AppColors.rose,
      colorScheme: const ColorScheme.light(
        primary: AppColors.rose,
        secondary: AppColors.mauve,
        surface: AppColors.blush,
        onPrimary: Colors.white,
        onSurface: AppColors.deep,
      ),
      textTheme: _buildTextTheme(ThemeData.light().textTheme, AppColors.deep),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.rose,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.rose,
        secondary: AppColors.mauve,
        surface: AppColors.deep,
        onPrimary: Colors.white,
        onSurface: AppColors.cream,
      ),
      textTheme: _buildTextTheme(ThemeData.dark().textTheme, AppColors.cream),
    );
  }
}
