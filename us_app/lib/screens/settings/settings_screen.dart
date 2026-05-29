import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/analytics_service.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _startDateText;
  bool _dailyFood = true;
  bool _hydration = true;
  bool _period    = true;

  File? _selectedWallpaperFile;
  Color? _extractedColor;
  bool _extractingColor = false;

  bool _showOriginalsOverlay = false;
  bool _hasPin = false;
  int _versionTaps = 0;

  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('couple_start_date');
      final food      = prefs.getBool('reminder_daily_food') ?? true;
      final water     = prefs.getBool('reminder_hydration')  ?? true;
      final cycle     = prefs.getBool('reminder_period')     ?? true;
      
      final pin = await _secureStorage.read(key: 'wishlist_pin');

      setState(() {
        if (savedDate != null) {
          _startDateText = DateFormat.yMMMd().format(DateTime.parse(savedDate));
        }
        _dailyFood = food;
        _hydration = water;
        _period    = cycle;
        _hasPin    = pin != null && pin.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.rose,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final prefs   = await SharedPreferences.getInstance();
      await prefs.setString('couple_start_date', picked.toIso8601String());
      setState(() {
        _startDateText = DateFormat.yMMMd().format(picked);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anniversary start date saved! 💕')),
        );
      }
    }
  }

  void _showUnlinkDialog() {
    String typed = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A0A0F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              title: Text(
                'Are you sure?',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will:\n• remove your couple connection\n• stop shared syncing\n• disable shared spaces\n\nYour personal data remains safe.',
                    style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type UNLINK to confirm.',
                    style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    style: GoogleFonts.dmSans(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    onChanged: (val) {
                      setStateDialog(() => typed = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.dmSans(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: typed == 'UNLINK' ? () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    await ref.read(coupleProvider.notifier).unlinkPartner();
                    if (mounted) context.go('/login');
                  } : null,
                  child: const Text('Unlink Partner'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _pickWallpaper() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _selectedWallpaperFile = File(picked.path);
          _extractingColor = true;
        });

        final extractedColor = await ref
            .read(themeProvider.notifier)
            .extractPaletteFromImage(_selectedWallpaperFile!);

        setState(() {
          _extractedColor  = extractedColor;
          _extractingColor = false;
        });
      }
    } catch (_) {
      setState(() => _extractingColor = false);
    }
  }

  Future<void> _saveWallpaper() async {
    if (_selectedWallpaperFile == null) return;
    await ref
        .read(themeProvider.notifier)
        .setWallpaper(_selectedWallpaperFile!.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Custom wallpaper applied to dashboard! ✨')),
      );
    }
  }

  Future<void> _removeWallpaper() async {
    await ref.read(themeProvider.notifier).clearWallpaper();
    setState(() {
      _selectedWallpaperFile = null;
      _extractedColor = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper cleared from dashboard.')),
      );
    }
  }

  Future<void> _toggleReminder(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() {
      if (key == 'reminder_daily_food') _dailyFood = val;
      if (key == 'reminder_hydration')  _hydration = val;
      if (key == 'reminder_period')     _period    = val;
    });
  }

  void _onOriginalsUnlocked() {
    HapticFeedback.mediumImpact();
    AnalyticsService.logThemeUnlocked('The Originals');
    setState(() => _showOriginalsOverlay = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOriginalsOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState  = ref.watch(themeProvider);
    final tc          = themeState.colors;
    final coupleState = ref.watch(coupleProvider);
    final partner     = coupleState.valueOrNull?.partner;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: tc.backgroundColor,
          appBar: AppBar(
            backgroundColor: tc.cardColor,
            elevation: 0.5,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: tc.textPrimary, size: 20),
              onPressed: () => context.go('/us-space'),
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            children: [
              // ── SECTION: APPEARANCE ─────────────────────────────────────────
              _buildSectionHeader('Appearance 🎨', tc),
              _buildVibesSection(themeState, tc),
              const SizedBox(height: 24),

              // ── SECTION: THE ORIGINALS (SECRET) ────────────────────────────
              _buildSectionHeader('Discover 🔮', tc),
              _buildOriginalsSection(themeState, tc),
              const SizedBox(height: 24),

              // ── SECTION: COUPLE ROOM ────────────────────────────────────────
              _buildSectionHeader('Anniversary Room 💕', tc),
              _buildCoupleCard(partner, tc),
              const SizedBox(height: 24),

              // ── SECTION: ACCOUNT ─────────────────────────────────────────────
              _buildSectionHeader('Account 👤', tc),
              _buildAccountSection(tc),
              const SizedBox(height: 24),

              // ── SECTION: WISHLIST PIN ────────────────────────────────────────
              _buildSectionHeader('Security 🔒', tc),
              _buildWishlistPinSection(tc),
              const SizedBox(height: 24),

              // ── SECTION: SMART REMINDERS ─────────────────────────────────────
              _buildSectionHeader('Smart Reminders 🔔', tc),
              _buildRemindersSection(tc),
              const SizedBox(height: 24),

              // ── SECTION: ABOUT ────────────────────────────────────────────────
              _buildSectionHeader('About ℹ️', tc),
              _buildAboutSection(tc),
              const SizedBox(height: 48),
            ],
          ),
        ),

        // Originals unlock overlay
        if (_showOriginalsOverlay) _OriginalsSuccessOverlay(),
      ],
    );
  }

  // ── Section header ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: tc.textPrimary,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }

  // ── Appearance / Mood Theme section ────────────────────────────────────────

  static const _publicMoodDefs = [
    (key: 'softMorning',  name: 'Soft Morning',  theme: MoodThemes.softMorning),
    (key: 'cozyNight',    name: 'Cozy Night',    theme: MoodThemes.cozyNight),
    (key: 'dateNight',    name: 'Date Night',    theme: MoodThemes.dateNight),
    (key: 'rainyMood',    name: 'Rainy Mood',    theme: MoodThemes.rainyMood),
    (key: 'anniversary',  name: 'Anniversary',   theme: MoodThemes.anniversary),
    (key: 'default',      name: 'Us Default',    theme: MoodThemes.defaultTheme),
  ];

  Widget _buildVibesSection(AppThemeState themeState, ThemeColors tc) {
    final showOriginals = themeState.isOriginalsUnlocked;
    final allDefs = [
      ..._publicMoodDefs,
      if (showOriginals)
        (
          key: 'theOriginals',
          name: 'The Originals',
          theme: MoodThemes.theOriginals
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOOD THEME',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: tc.textMuted,
              letterSpacing: 1.2,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allDefs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final def      = allDefs[index];
                final isActive = themeState.moodTheme == def.key;
                final preview  = def.theme;
                final gradient = MoodThemes.themePreviewGradients[def.key] ??
                    [preview.backgroundColor, preview.cardColor];

                return GestureDetector(
                  onTap: () =>
                      ref.read(themeProvider.notifier).setMoodTheme(def.key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? AppColors.rose : tc.borderColor,
                            width: isActive ? 2.5 : 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.rose.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (isActive)
                                const Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              if (def.key == MoodThemes.theOriginals)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 14)
                                      .animate(onPlay: (c) => c.repeat(reverse: true))
                                      .scale(duration: 1.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.2, 1.2)),
                                )
                              else
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: preview.iconColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            def.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: def.key == MoodThemes.theOriginals ? const Color(0xFFD4AF37) : tc.textPrimary,
                              fontStyle: def.key == MoodThemes.theOriginals ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: tc.borderColor),
          const SizedBox(height: 16),
          Text(
            'COUPLE WALLPAPER',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: tc.textMuted,
              letterSpacing: 1.2,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: tc.borderColor,
                  child: _selectedWallpaperFile != null
                      ? Image.file(_selectedWallpaperFile!, fit: BoxFit.cover)
                      : (ref.watch(themeProvider).wallpaperPath != null
                          ? Image.file(
                              File(ref.watch(themeProvider).wallpaperPath!),
                              fit: BoxFit.cover)
                          : Icon(Icons.camera_alt_rounded,
                              color: tc.iconColor, size: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tc.iconColor.withValues(alpha: 0.15),
                            foregroundColor: tc.iconColor,
                            minimumSize: const Size(100, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: _pickWallpaper,
                          child: Text('Choose Photo',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.normal)),
                        ),
                        if (ref.watch(themeProvider).wallpaperPath != null ||
                            _selectedWallpaperFile != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded,
                                color: Colors.redAccent),
                            onPressed: _removeWallpaper,
                            tooltip: 'Remove wallpaper',
                          ),
                        ],
                      ],
                    ),
                    if (_extractingColor)
                      const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (_extractedColor != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Extracted Accent:',
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: tc.textMuted,
                            fontStyle: FontStyle.normal),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildColorCircle(_extractedColor!),
                          const Spacer(),
                          TextButton(
                            onPressed: _saveWallpaper,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Apply',
                              style: GoogleFonts.dmSans(
                                color: tc.iconColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  // ── The Originals section ──────────────────────────────────────────────────

  Widget _buildOriginalsSection(AppThemeState themeState, ThemeColors tc) {
    final unlocked = themeState.isOriginalsUnlocked;

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
              : tc.borderColor,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked
                ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                : tc.borderColor.withValues(alpha: 0.5),
          ),
          child: Icon(
            unlocked ? Icons.auto_awesome_rounded : Icons.lock_rounded,
            color: unlocked
                ? const Color(0xFFD4AF37)
                : tc.textMuted,
            size: 20,
          ),
        ),
        title: Text(
          unlocked ? 'The Originals ✨' : 'Unlock something special',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: unlocked ? const Color(0xFFD4AF37) : tc.textPrimary,
            fontStyle: FontStyle.normal,
          ),
        ),
        subtitle: Text(
          unlocked
              ? 'Secret theme unlocked'
              : 'A theme for those who know',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: tc.textMuted,
            fontStyle: FontStyle.normal,
          ),
        ),
        trailing: unlocked
            ? null
            : Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: tc.textMuted),
        onTap: unlocked
            ? null
            : () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => _OriginalsQuizDialog(
                    onUnlocked: () {
                      ref.read(themeProvider.notifier).unlockOriginals();
                      Navigator.of(ctx).pop();
                      _onOriginalsUnlocked();
                    },
                  ),
                );
              },
      ),
    );
  }

  // ── Couple card ────────────────────────────────────────────────────────────

  Widget _buildCoupleCard(dynamic partner, ThemeColors tc) {
    final avatar     = partner?.avatarUrl;
    final name       = partner?.name ?? 'No partner linked';
    final linkedText = _startDateText != null
        ? 'Linked since $_startDateText'
        : 'Start date not configured';

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tc.iconColor.withValues(alpha: 0.15),
                  border: Border.all(color: tc.iconColor, width: 1.5),
                  image: avatar != null
                      ? DecorationImage(
                          image: NetworkImage(avatar), fit: BoxFit.cover)
                      : null,
                ),
                child: avatar == null
                    ? Icon(Icons.person, color: tc.iconColor, size: 24)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: tc.textPrimary,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linkedText,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: tc.textMuted,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: tc.borderColor),
          
          // Pronouns Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Partner Pronouns',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: tc.textSecondary,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                Row(
                  children: ['she', 'he', 'they'].map((p) {
                    final isSelected = partner?.partnerPronoun == p;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(coupleProvider.notifier).updatePartnerPronoun(p);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? tc.iconColor.withValues(alpha: 0.15) : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? tc.iconColor : tc.borderColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            p == 'she' ? 'She/Her' : p == 'he' ? 'He/Him' : 'They/Them',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: isSelected ? tc.iconColor : tc.textMuted,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tc.borderColor),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _selectStartDate,
                icon: Icon(Icons.calendar_month_rounded,
                    color: tc.iconColor, size: 18),
                label: Text(
                  'Start Date',
                  style: GoogleFonts.dmSans(
                      color: tc.iconColor,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.normal),
                ),
              ),
              TextButton.icon(
                onPressed: _showUnlinkDialog,
                icon: const Icon(Icons.link_off_rounded,
                    color: Colors.redAccent, size: 18),
                label: Text(
                  'Unlink',
                  style: GoogleFonts.dmSans(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.normal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Account section ────────────────────────────────────────────────────────

  Widget _buildAccountSection(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.borderColor),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.link_rounded, color: tc.iconColor, size: 22),
            title: Text(
              'Link Partner',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  color: tc.textPrimary,
                  fontStyle: FontStyle.normal),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: tc.textMuted),
            onTap: () => context.go('/link-partner'),
          ),
          Divider(height: 1, color: tc.borderColor, indent: 56),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: Colors.redAccent, size: 22),
            title: Text(
              'Sign Out',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  color: Colors.redAccent,
                  fontStyle: FontStyle.normal),
            ),
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  // ── Wishlist PIN section ───────────────────────────────────────────────────

  Widget _buildWishlistPinSection(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.borderColor),
      ),
      child: Column(
        children: [
          if (!_hasPin)
            ListTile(
              leading: Icon(Icons.password_rounded, color: tc.iconColor, size: 22),
              title: Text(
                'Set Wishlist PIN',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    color: tc.textPrimary,
                    fontStyle: FontStyle.normal),
              ),
              subtitle: Text(
                'Protect hidden items with a 4-digit PIN',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: tc.textMuted,
                    fontStyle: FontStyle.normal),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: tc.textMuted),
              onTap: () => _showPinDialog(tc, isSetting: true),
            )
          else ...[
            ListTile(
              leading: Icon(Icons.password_rounded, color: tc.iconColor, size: 22),
              title: Text(
                'Change PIN',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    color: tc.textPrimary,
                    fontStyle: FontStyle.normal),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: tc.textMuted),
              onTap: () => _showPinDialog(tc, isSetting: true, isChanging: true),
            ),
            Divider(height: 1, color: tc.borderColor, indent: 56),
            ListTile(
              leading: Icon(Icons.lock_open_rounded, color: Colors.orangeAccent, size: 22),
              title: Text(
                'Forgot PIN / Disable PIN',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    color: Colors.orangeAccent,
                    fontStyle: FontStyle.normal),
              ),
              onTap: () async {
                await _secureStorage.delete(key: 'wishlist_pin');
                setState(() => _hasPin = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wishlist PIN has been disabled.')),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showPinDialog(ThemeColors tc, {bool isSetting = false, bool isChanging = false}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String enteredPin = '';
        return AlertDialog(
          backgroundColor: tc.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: tc.borderColor),
          ),
          title: Text(
            isChanging ? 'Enter New PIN' : 'Set Wishlist PIN',
            style: GoogleFonts.playfairDisplay(
              color: tc.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter a 4-digit PIN to secure your hidden wishlist items.',
                style: GoogleFonts.dmSans(color: tc.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PinCodeTextField(
                appContext: context,
                length: 4,
                obscureText: true,
                animationType: AnimationType.scale,
                keyboardType: TextInputType.number,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: tc.inputFillColor,
                  inactiveFillColor: tc.inputFillColor,
                  selectedFillColor: tc.inputFillColor,
                  activeColor: tc.iconColor,
                  inactiveColor: tc.borderColor,
                  selectedColor: tc.iconColor,
                ),
                textStyle: GoogleFonts.dmMono(
                  fontSize: 24,
                  color: tc.textPrimary,
                ),
                enableActiveFill: true,
                onChanged: (val) {
                  enteredPin = val;
                },
                onCompleted: (val) async {
                  await _secureStorage.write(key: 'wishlist_pin', value: val);
                  setState(() => _hasPin = true);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isChanging ? 'Wishlist PIN changed successfully 🔒' : 'Wishlist PIN set successfully 🔒')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Reminders section ──────────────────────────────────────────────────────

  Widget _buildRemindersSection(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.borderColor),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildSwitchRow('Daily food reminders', 'reminder_daily_food',
              _dailyFood, Icons.restaurant_rounded, tc),
          Divider(height: 1, color: tc.borderColor),
          _buildSwitchRow('Hydration reminders', 'reminder_hydration',
              _hydration, Icons.water_drop_rounded, tc),
          Divider(height: 1, color: tc.borderColor),
          _buildSwitchRow('Period reminders', 'reminder_period',
              _period, Icons.auto_awesome_rounded, tc),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
      String label, String key, bool currentVal, IconData icon, ThemeColors tc) {
    return SwitchListTile(
      value: currentVal,
      onChanged: (val) => _toggleReminder(key, val),
      title: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: tc.textPrimary,
          fontStyle: FontStyle.normal,
        ),
      ),
      secondary: Icon(icon, color: tc.iconColor, size: 20),
      activeColor: tc.iconColor,
    );
  }

  // ── About section ──────────────────────────────────────────────────────────

  Widget _buildAboutSection(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Us V2',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: tc.iconColor,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 2.0.0',
            style: GoogleFonts.dmMono(
              fontSize: 12,
              color: tc.textMuted,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Made with love 💕',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: tc.textSecondary,
              fontStyle: FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The Originals Quiz Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _OriginalsQuizDialog extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;

  const _OriginalsQuizDialog({required this.onUnlocked});

  @override
  ConsumerState<_OriginalsQuizDialog> createState() => _OriginalsQuizDialogState();
}

class _OriginalsQuizDialogState extends ConsumerState<_OriginalsQuizDialog> {
  int _questionIndex = 0;
  String _answer = '';
  bool _wrong = false;
  int _failures = 0;

  final _ctrl = TextEditingController();

  static const _questions = [
    'What day makes the year worth it?',
    'What does he call her other personality?',
    'If she had a debit card, what would her PIN be?',
  ];

  static const _hints = [
    'Hint: Think about her birthday...',
    'Hint: Her other personality...',
    'Hint: Try 27...',
  ];

  bool _checkAnswer(String answer) {
    return ref.read(themeProvider.notifier).verifyAnswer(_questionIndex + 1, answer);
  }

  void _submit() {
    final answer = _ctrl.text;
    if (_checkAnswer(answer)) {
      setState(() {
        _wrong = false;
        _answer = '';
        _failures = 0;
        _ctrl.clear();
      });
      if (_questionIndex == 2) {
        widget.onUnlocked();
      } else {
        setState(() => _questionIndex++);
      }
    } else {
      setState(() {
        _wrong = true;
        _failures++;
        if (_questionIndex != 0) {
          _questionIndex = 0; // Reset to Q1 unless already on Q1
        }
        _answer = '';
        _ctrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF120308),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔮', style: TextStyle(fontSize: 40))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: 1200.ms,
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 16),

            // Progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i <= _questionIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 28,
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Question ${_questionIndex + 1} of 3',
              style: GoogleFonts.dmMono(
                fontSize: 11,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                fontStyle: FontStyle.normal,
              ),
            ),
            const SizedBox(height: 20),

            // Question
            Text(
              _questions[_questionIndex],
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontStyle: FontStyle.normal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Answer input
            TextField(
              controller: _ctrl,
              keyboardType: _questionIndex == 0 || _questionIndex == 2 ? TextInputType.number : TextInputType.text,
              obscureText: _questionIndex == 2,
              obscuringCharacter: '●',
              maxLength: _questionIndex == 2 ? 4 : null,
              onChanged: (v) => setState(() => _answer = v),
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 15,
                fontStyle: FontStyle.normal,
              ),
              decoration: InputDecoration(
                hintText: 'Your answer',
                counterText: '',
                hintStyle: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontStyle: FontStyle.normal,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFFD4AF37), width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),

            // Wrong answer message
            if (_wrong) ...[
              const SizedBox(height: 12),
              Text(
                _questionIndex == 0 ? 'Not quite... 💕' : (_questionIndex == 1 ? 'Hmm, that\'s not it 💕' : 'So close... 💕'),
                style: GoogleFonts.dmSans(
                  color: AppColors.rose,
                  fontSize: 13,
                  fontStyle: FontStyle.normal,
                ),
              ).animate().shake(duration: 400.ms),
            ],
            
            // Hint Message after 3 failures
            if (_failures >= 3) ...[
              const SizedBox(height: 8),
              Text(
                _hints[_questionIndex],
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFD4AF37),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 600.ms),
            ],

            const SizedBox(height: 20),

            // Submit button
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFF9B7D1A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _questionIndex == 2 ? 'Unlock 🔒' : 'Next →',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 14,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Originals success overlay — auto-dismiss after 3 seconds
// ─────────────────────────────────────────────────────────────────────────────

class _OriginalsSuccessOverlay extends StatefulWidget {
  const _OriginalsSuccessOverlay();

  @override
  State<_OriginalsSuccessOverlay> createState() =>
      _OriginalsSuccessOverlayState();
}

class _OriginalsSuccessOverlayState extends State<_OriginalsSuccessOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _heartControllers;
  final _heartCount = 14;

  @override
  void initState() {
    super.initState();
    _heartControllers = List.generate(
      _heartCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1100 + (i * 90)),
      )..repeat(),
    );
  }

  @override
  void dispose() {
    for (final c in _heartControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () {},
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF120308), Color(0xFF3E0E1E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Floating hearts
              ..._buildFloatingHearts(size),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 72))
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          duration: 900.ms,
                          begin: const Offset(0.88, 0.88),
                          end: const Offset(1.12, 1.12),
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome, Originals',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD4AF37),
                        fontStyle: FontStyle.normal,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms)
                        .slideY(begin: 0.3, end: 0, delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      '🥀',
                      style: const TextStyle(fontSize: 36),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 500.ms),
                    const SizedBox(height: 48),
                    Text(
                      'Theme unlocked',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                        fontStyle: FontStyle.normal,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 900.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
            begin: const Offset(1.05, 1.05), end: const Offset(1, 1));
  }

  List<Widget> _buildFloatingHearts(Size size) {
    final emojis = ['✨', '🥀', '💛', '🌹', '⭐', '💫'];
    return List.generate(_heartCount, (i) {
      final left  = (i / _heartCount) * size.width;
      final emoji = emojis[i % emojis.length];

      return Positioned(
        left: left,
        bottom: 0,
        child: AnimatedBuilder(
          animation: _heartControllers[i],
          builder: (_, __) {
            final progress = _heartControllers[i].value;
            return Transform.translate(
              offset: Offset(
                14 * (i.isEven ? 1 : -1) * progress,
                -size.height * 1.2 * progress,
              ),
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 1.0),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 13 + (i % 3) * 7.0),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
