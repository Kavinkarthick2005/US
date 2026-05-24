import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeColors — the single source of truth for every dynamic color in the app
// ─────────────────────────────────────────────────────────────────────────────

class ThemeColors {
  final Color backgroundColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderColor;
  final Color iconColor;
  final Color inputFillColor;
  final Color bottomNavColor;

  const ThemeColors({
    required this.backgroundColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderColor,
    required this.iconColor,
    required this.inputFillColor,
    required this.bottomNavColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// All 6 mood themes — complete color sets
// ─────────────────────────────────────────────────────────────────────────────

class MoodThemes {
  MoodThemes._();

  static const softMorning = ThemeColors(
    backgroundColor: Color(0xFFFEFAF9),
    cardColor:       Color(0xFFFFFFFF),
    textPrimary:     Color(0xFF1A0A0F),
    textSecondary:   Color(0xFF4A2535),
    textMuted:       Color(0xFF8A6070),
    borderColor:     Color(0xFFF0DDE4),
    iconColor:       Color(0xFFE8607A),
    inputFillColor:  Color(0xFFFDF0F3),
    bottomNavColor:  Color(0xFFFFFFFF),
  );

  static const cozyNight = ThemeColors(
    backgroundColor: Color(0xFF0A0308),
    cardColor:       Color(0xFF1E0D14),
    textPrimary:     Color(0xFFF4C6D2),
    textSecondary:   Color(0xFFC97B93),
    textMuted:       Color(0xFF8A6070),
    borderColor:     Color(0xFF3D1525),
    iconColor:       Color(0xFFE6A817),
    inputFillColor:  Color(0xFF150810),
    bottomNavColor:  Color(0xFF1E0D14),
  );

  static const dateNight = ThemeColors(
    backgroundColor: Color(0xFF000000),
    cardColor:       Color(0xFF1A1400),
    textPrimary:     Color(0xFFF5F0DC),
    textSecondary:   Color(0xFFD4AF37),
    textMuted:       Color(0xFF8A7A50),
    borderColor:     Color(0xFF2A2200),
    iconColor:       Color(0xFFD4AF37),
    inputFillColor:  Color(0xFF0D0D00),
    bottomNavColor:  Color(0xFF1A1400),
  );

  static const rainyMood = ThemeColors(
    backgroundColor: Color(0xFF1A2030),
    cardColor:       Color(0xFF242E42),
    textPrimary:     Color(0xFFE8EEF8),
    textSecondary:   Color(0xFF7AAAD4),
    textMuted:       Color(0xFF5A7090),
    borderColor:     Color(0xFF2E3E58),
    iconColor:       Color(0xFF7AAAD4),
    inputFillColor:  Color(0xFF1E2838),
    bottomNavColor:  Color(0xFF242E42),
  );

  static const anniversary = ThemeColors(
    backgroundColor: Color(0xFF1A050A),
    cardColor:       Color(0xFF2E0D16),
    textPrimary:     Color(0xFFFFD6E0),
    textSecondary:   Color(0xFFFF6B8A),
    textMuted:       Color(0xFFA05070),
    borderColor:     Color(0xFF4A1525),
    iconColor:       Color(0xFFFF6B8A),
    inputFillColor:  Color(0xFF220810),
    bottomNavColor:  Color(0xFF2E0D16),
  );

  static const defaultTheme = ThemeColors(
    backgroundColor: Color(0xFFFEFAF9),
    cardColor:       Color(0xFFFFFFFF),
    textPrimary:     Color(0xFF1A0A0F),
    textSecondary:   Color(0xFF4A2535),
    textMuted:       Color(0xFF8A6070),
    borderColor:     Color(0xFFF0DDE4),
    iconColor:       Color(0xFFE8607A),
    inputFillColor:  Color(0xFFFDF0F3),
    bottomNavColor:  Color(0xFFFFFFFF),
  );

  static const Map<String, ThemeColors> all = {
    'softMorning': softMorning,
    'cozyNight':   cozyNight,
    'dateNight':   dateNight,
    'rainyMood':   rainyMood,
    'anniversary': anniversary,
    'default':     defaultTheme,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AppThemeState {
  final String moodTheme;
  final Color accentColor;
  final String? wallpaperPath;
  final bool isDark;

  AppThemeState({
    required this.moodTheme,
    required this.accentColor,
    this.wallpaperPath,
    required this.isDark,
  });

  /// Returns the ThemeColors for the current moodTheme.
  ThemeColors get colors =>
      MoodThemes.all[moodTheme] ?? MoodThemes.defaultTheme;

  AppThemeState copyWith({
    String? moodTheme,
    Color? accentColor,
    String? wallpaperPath,
    bool? isDark,
    bool clearWallpaper = false,
  }) {
    return AppThemeState(
      moodTheme:     moodTheme    ?? this.moodTheme,
      accentColor:   accentColor  ?? this.accentColor,
      wallpaperPath: clearWallpaper ? null : (wallpaperPath ?? this.wallpaperPath),
      isDark:        isDark       ?? this.isDark,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends StateNotifier<AppThemeState> {
  ThemeNotifier()
      : super(AppThemeState(
          moodTheme:    'default',
          accentColor:  AppColors.rose,
          wallpaperPath: null,
          isDark:        false,
        )) {
    loadSettings();
  }

  static const _prefMood      = 'theme_mood_theme';
  static const _prefAccent    = 'theme_accent_color';
  static const _prefWallpaper = 'theme_wallpaper_path';
  static const _prefIsDark    = 'theme_is_dark';

  Future<void> loadSettings() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final mood     = prefs.getString(_prefMood) ?? 'default';
      final accentHex = prefs.getString(_prefAccent);
      final wallpaper = prefs.getString(_prefWallpaper);
      final isDark   = prefs.getBool(_prefIsDark) ?? false;

      Color accent = AppColors.rose;
      if (accentHex != null) {
        final val = int.tryParse(accentHex, radix: 16);
        if (val != null) accent = Color(val);
      }

      state = AppThemeState(
        moodTheme:    mood,
        accentColor:  accent,
        wallpaperPath: wallpaper,
        isDark:        isDark,
      );
    } catch (_) {}
  }

  Future<void> setMoodTheme(String theme) async {
    // Auto-adjust dark flag to match theme intent
    final dark = _isDarkTheme(theme);
    state = state.copyWith(moodTheme: theme, isDark: dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMood, theme);
      await prefs.setBool(_prefIsDark, dark);
    } catch (_) {}
  }

  bool _isDarkTheme(String theme) {
    switch (theme) {
      case 'cozyNight':
      case 'dateNight':
      case 'rainyMood':
      case 'anniversary':
        return true;
      default:
        return false;
    }
  }

  Future<void> setWallpaper(String path) async {
    state = state.copyWith(wallpaperPath: path);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefWallpaper, path);
    } catch (_) {}
  }

  Future<void> clearWallpaper() async {
    state = state.copyWith(clearWallpaper: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefWallpaper);
    } catch (_) {}
  }

  Future<void> setIsDark(bool dark) async {
    state = state.copyWith(isDark: dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsDark, dark);
    } catch (_) {}
  }

  Future<Color> extractPaletteFromImage(File imageFile) async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        maximumColorCount: 16,
      );
      final color = generator.vibrantColor?.color ??
                    generator.dominantColor?.color ??
                    AppColors.rose;

      state = state.copyWith(accentColor: color);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccent, color.toARGB32().toRadixString(16));

      return color;
    } catch (_) {
      return AppColors.rose;
    }
  }

  // ── Material ThemeData (used by MaterialApp) ──────────────────────────────

  ThemeData get themeData {
    final tc      = state.colors;
    final primary = state.accentColor;

    final brightness = state.isDark ? Brightness.dark : Brightness.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary:   primary,
        secondary: AppColors.mauve,
        surface:   tc.backgroundColor,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: tc.backgroundColor,
    );

    return _applyTypography(base, tc, primary);
  }

  ThemeData _applyTypography(ThemeData base, ThemeColors tc, Color primary) {
    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor:    tc.textPrimary,
        displayColor: tc.textPrimary,
      ).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 28, fontWeight: FontWeight.w700, color: tc.textPrimary),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 22, fontWeight: FontWeight.bold, color: tc.textPrimary),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18, fontWeight: FontWeight.w500, color: tc.textPrimary),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: tc.textPrimary.withValues(alpha: 0.85)),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: tc.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tc.backgroundColor,
        foregroundColor: tc.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w700, color: primary),
      ),
      cardTheme: CardThemeData(
        color: tc.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: tc.borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: tc.inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      iconTheme: IconThemeData(color: tc.iconColor),
      dividerColor: tc.borderColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeState>(
    (ref) => ThemeNotifier());
