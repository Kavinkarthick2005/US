import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeColors — single source of truth for every dynamic color
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
// All mood themes — 5 public + 1 secret
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

  // The Originals — secret theme, never referenced by name in UI until unlocked
  static const theOriginals = ThemeColors(
    backgroundColor: Color(0xFF120308),
    cardColor:       Color(0xFF1F0610),
    textPrimary:     Color(0xFFF0E6D3),
    textSecondary:   Color(0xFFD4B896),
    textMuted:       Color(0xFF8A6B5A),
    borderColor:     Color(0xFF3E0E1E),
    iconColor:       Color(0xFFD4AF37),
    inputFillColor:  Color(0xFF190408),
    bottomNavColor:  Color(0xFF1F0610),
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
    'softMorning':  softMorning,
    'cozyNight':    cozyNight,
    'dateNight':    dateNight,
    'rainyMood':    rainyMood,
    'anniversary':  anniversary,
    'theOriginals': theOriginals,
    'default':      defaultTheme,
  };

  // Public themes shown in settings (Originals shown only when unlocked)
  static const List<String> publicThemeKeys = [
    'softMorning',
    'cozyNight',
    'dateNight',
    'rainyMood',
    'anniversary',
  ];

  static const Map<String, String> themeDisplayNames = {
    'softMorning':  'Soft Morning',
    'cozyNight':    'Cozy Night',
    'dateNight':    'Date Night',
    'rainyMood':    'Rainy Mood',
    'anniversary':  'Anniversary',
    'theOriginals': 'The Originals',
    'default':      'Default',
  };

  static const Map<String, List<Color>> themePreviewGradients = {
    'softMorning':  [Color(0xFFE8607A), Color(0xFFF9E4EA)],
    'cozyNight':    [Color(0xFF1E0D14), Color(0xFF3D1525)],
    'dateNight':    [Color(0xFF1A1400), Color(0xFF2A2200)],
    'rainyMood':    [Color(0xFF242E42), Color(0xFF2E3E58)],
    'anniversary':  [Color(0xFF2E0D16), Color(0xFF4A1525)],
    'theOriginals': [Color(0xFF1F0610), Color(0xFF3E0E1E)],
    'default':      [Color(0xFFE8607A), Color(0xFFF9E4EA)],
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
  final bool isOriginalsUnlocked;

  AppThemeState({
    required this.moodTheme,
    required this.accentColor,
    this.wallpaperPath,
    required this.isDark,
    this.isOriginalsUnlocked = false,
  });

  ThemeColors get colors =>
      MoodThemes.all[moodTheme] ?? MoodThemes.defaultTheme;

  AppThemeState copyWith({
    String? moodTheme,
    Color? accentColor,
    String? wallpaperPath,
    bool? isDark,
    bool clearWallpaper = false,
    bool? isOriginalsUnlocked,
  }) {
    return AppThemeState(
      moodTheme:           moodTheme           ?? this.moodTheme,
      accentColor:         accentColor         ?? this.accentColor,
      wallpaperPath:       clearWallpaper ? null : (wallpaperPath ?? this.wallpaperPath),
      isDark:              isDark              ?? this.isDark,
      isOriginalsUnlocked: isOriginalsUnlocked ?? this.isOriginalsUnlocked,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends StateNotifier<AppThemeState> {
  ThemeNotifier()
      : super(AppThemeState(
          moodTheme:   'default',
          accentColor: AppColors.rose,
          isDark:      false,
        )) {
    loadSettings();
  }

  static const _prefMood      = 'theme_mood_theme';
  static const _prefAccent    = 'theme_accent_color';
  static const _prefWallpaper = 'theme_wallpaper_path';
  static const _prefIsDark    = 'theme_is_dark';
  static const _prefOriginals = 'originals_unlocked';

  Future<void> loadSettings() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final mood        = prefs.getString(_prefMood) ?? 'default';
      final accentHex   = prefs.getString(_prefAccent);
      final wallpaper   = prefs.getString(_prefWallpaper);
      final isDark      = prefs.getBool(_prefIsDark) ?? false;
      final originals   = prefs.getBool(_prefOriginals) ?? false;

      // Sync originals unlock with Supabase
      bool sbOriginals = originals;
      try {
        final sb = Supabase.instance.client;
        final user = sb.auth.currentUser;
        if (user != null) {
          final profile = await sb.from('profiles').select('originals_unlocked').eq('id', user.id).maybeSingle();
          if (profile != null && profile['originals_unlocked'] == true) {
            sbOriginals = true;
            await prefs.setBool(_prefOriginals, true);
          }
        }
      } catch (_) {}

      Color accent = AppColors.rose;
      if (accentHex != null) {
        final val = int.tryParse(accentHex, radix: 16);
        if (val != null) accent = Color(val);
      }

      state = AppThemeState(
        moodTheme:           mood,
        accentColor:         accent,
        wallpaperPath:       wallpaper,
        isDark:              isDark,
        isOriginalsUnlocked: sbOriginals,
      );
    } catch (_) {}
  }

  Future<void> setMoodTheme(String theme) async {
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
      case 'theOriginals':
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

  /// Called when the 3-question quiz is successfully completed.
  Future<void> unlockOriginals() async {
    state = state.copyWith(isOriginalsUnlocked: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefOriginals, true);
      
      final sb = Supabase.instance.client;
      final user = sb.auth.currentUser;
      if (user != null) {
        await sb.from('profiles').update({'originals_unlocked': true}).eq('id', user.id);
      }
    } catch (_) {}
  }
  
  bool verifyAnswer(int questionNumber, String answer) {
    final bytes = utf8.encode(answer.trim().toLowerCase());
    final digest = sha256.convert(bytes);
    final hash = digest.toString();

    if (questionNumber == 1) {
      return hash == '670671cd97404156226e507973f2ab8330d3022ca96e0c93bdbdb320c41adcaf';
    } else if (questionNumber == 2) {
      return hash == 'c2deeb1fe8fec7f83d45a0784dd01968301aadc6223d9a51b2b504dd46a9ed36';
    } else if (questionNumber == 3) {
      return hash == 'ce83293c66150ed42f52747cca6a91b85332c740cde625195b15f1abb4b90196';
    }
    return false;
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

  // ── Material ThemeData ────────────────────────────────────────────────────

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
          fontSize: 28, fontWeight: FontWeight.w700,
          color: tc.textPrimary, fontStyle: FontStyle.normal),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 22, fontWeight: FontWeight.bold,
          color: tc.textPrimary, fontStyle: FontStyle.normal),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18, fontWeight: FontWeight.w500,
          color: tc.textPrimary, fontStyle: FontStyle.normal),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: tc.textPrimary.withValues(alpha: 0.85),
          fontStyle: FontStyle.normal),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: tc.textMuted, fontStyle: FontStyle.normal),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:   tc.backgroundColor,
        foregroundColor:   tc.textPrimary,
        elevation:         0,
        centerTitle:       true,
        titleTextStyle:    GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: primary, fontStyle: FontStyle.normal),
      ),
      cardTheme: CardThemeData(
        color:     tc.cardColor,
        elevation: 0,
        shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: tc.borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          minimumSize: const Size(double.infinity, 54),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600, fontSize: 15,
            fontStyle: FontStyle.normal),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: tc.inputFillColor,
        border:    OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.dmSans(
          color: tc.textMuted, fontSize: 14, fontStyle: FontStyle.normal),
        labelStyle: GoogleFonts.dmSans(
          color: tc.textSecondary, fontSize: 14, fontStyle: FontStyle.normal),
      ),
      iconTheme:    IconThemeData(color: tc.iconColor),
      dividerColor: tc.borderColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeState>(
    (ref) => ThemeNotifier());
