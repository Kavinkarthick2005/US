import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('couple_start_date');
      final food     = prefs.getBool('reminder_daily_food') ?? true;
      final water    = prefs.getBool('reminder_hydration')  ?? true;
      final cycle    = prefs.getBool('reminder_period')     ?? true;

      setState(() {
        if (savedDate != null) {
          _startDateText = DateFormat.yMMMd().format(DateTime.parse(savedDate));
        }
        _dailyFood = food;
        _hydration = water;
        _period    = cycle;
      });
    } catch (_) {}
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.rose,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs   = await SharedPreferences.getInstance();
      final dateStr = picked.toIso8601String();
      await prefs.setString('couple_start_date', dateStr);
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
    await ref.read(themeProvider.notifier).setWallpaper(_selectedWallpaperFile!.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom wallpaper applied to dashboard! ✨')),
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

  void _confirmUnlink(ThemeColors tc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unlink Partner? 💔',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: tc.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to unlink? You will no longer share reminders, memories, or planners.',
          style: GoogleFonts.dmSans(color: tc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final router = GoRouter.of(context);
              Navigator.pop(ctx);
              await ref.read(coupleProvider.notifier).unlinkPartner();
              router.go('/link-partner');
            },
            child: Text('Unlink', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleState  = ref.watch(coupleProvider);
    final partner      = coupleState.valueOrNull?.partner;
    final themeState   = ref.watch(themeProvider);
    final tc           = themeState.colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: tc.cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: tc.textPrimary, size: 20),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Settings ⚙️',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            color: tc.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          // ── SECTION 1: COUPLE ROOM ──────────────────────────────────────────────
          _buildSectionHeader('Anniversary Room 💕', tc),
          _buildCoupleCard(partner, tc),
          const SizedBox(height: 24),

          // ── SECTION 1.5: PRONOUNS ─────────────────────────────────────────────
          _buildSectionHeader('Partner Pronouns 👤', tc),
          _buildPronounsSection(tc),
          const SizedBox(height: 24),

          // ── SECTION 2: AESTHETICS ─────────────────────────────────────────────
          _buildSectionHeader('Your Vibe 🎨', tc),
          _buildVibesSection(themeState, tc),
          const SizedBox(height: 24),

          // ── SECTION 3: REMINDERS ──────────────────────────────────────────
          _buildSectionHeader('Smart Reminders 🔔', tc),
          _buildRemindersSection(tc),
          const SizedBox(height: 24),

          // ── SECTION 4: WISHLIST PIN ───────────────────────────────────────
          _buildSectionHeader('Wishlist PIN 🔒', tc),
          _buildPinSection(tc),
          const SizedBox(height: 24),

          // ── SECTION 5: ABOUT ──────────────────────────────────────────────
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Made with love for Kavin & Varsha 💕',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tc.iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Us App v1.0.0',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: tc.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: tc.textPrimary,
        ),
      ),
    );
  }

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
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linkedText,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: tc.borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _selectStartDate,
                  icon: Icon(Icons.calendar_month_rounded,
                      color: tc.iconColor, size: 18),
                  label: Text(
                    'Edit Start Date',
                    style: GoogleFonts.dmSans(
                        color: tc.iconColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (partner != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmUnlink(tc),
                    icon: const Icon(Icons.link_off_rounded,
                        color: Colors.redAccent, size: 18),
                    label: Text(
                      'Unlink Room',
                      style: GoogleFonts.dmSans(
                          color: Colors.redAccent, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Mood Theme Section ────────────────────────────────────────────────────

  static const _moodDefs = [
    (
      key: 'softMorning',
      name: 'Soft Morning',
      theme: MoodThemes.softMorning,
    ),
    (
      key: 'cozyNight',
      name: 'Cozy Night',
      theme: MoodThemes.cozyNight,
    ),
    (
      key: 'dateNight',
      name: 'Date Night',
      theme: MoodThemes.dateNight,
    ),
    (
      key: 'rainyMood',
      name: 'Rainy Mood',
      theme: MoodThemes.rainyMood,
    ),
    (
      key: 'anniversary',
      name: 'Anniversary',
      theme: MoodThemes.anniversary,
    ),
    (
      key: 'default',
      name: 'Us Default',
      theme: MoodThemes.defaultTheme,
    ),
  ];

  Widget _buildVibesSection(AppThemeState themeState, ThemeColors tc) {
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
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _moodDefs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final def      = _moodDefs[index];
                final isActive = themeState.moodTheme == def.key;
                final preview  = def.theme;

                return GestureDetector(
                  onTap: () =>
                      ref.read(themeProvider.notifier).setMoodTheme(def.key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Preview Card ─────────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? AppColors.rose
                                : tc.borderColor,
                            width: isActive ? 2.5 : 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.rose
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Top half — background color
                            Expanded(
                              child: Container(
                                color: preview.backgroundColor,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.all(6),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: preview.iconColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            // Bottom half — card color
                            Expanded(
                              child: Container(
                                color: preview.cardColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 4,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: preview.textPrimary
                                            .withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 3,
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: preview.textMuted
                                            .withValues(alpha: 0.5),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        def.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: tc.textPrimary,
                        ),
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

          // ── COUPLE WALLPAPER ─────────────────────────────────────────────
          Text(
            'COUPLE WALLPAPER',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: tc.textMuted,
              letterSpacing: 1.2,
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
                      : (themeState.wallpaperPath != null
                          ? Image.file(
                              File(themeState.wallpaperPath!),
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
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (themeState.wallpaperPath != null ||
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
                    const SizedBox(height: 8),
                    if (_extractingColor)
                      const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (_extractedColor != null) ...[
                      Text(
                        'Extracted Accent:',
                        style:
                            GoogleFonts.dmSans(fontSize: 11, color: tc.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildColorCircle(_extractedColor!),
                          const SizedBox(width: 6),
                          _buildColorCircle(
                            HSLColor.fromColor(_extractedColor!)
                                .withLightness(
                                    (HSLColor.fromColor(_extractedColor!)
                                                .lightness +
                                            0.15)
                                        .clamp(0.0, 1.0))
                                .toColor(),
                          ),
                          const SizedBox(width: 6),
                          _buildColorCircle(
                            HSLColor.fromColor(_extractedColor!)
                                .withLightness(
                                    (HSLColor.fromColor(_extractedColor!)
                                                .lightness -
                                            0.15)
                                        .clamp(0.0, 1.0))
                                .toColor(),
                          ),
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

  Widget _buildPronounsSection(ThemeColors tc) {
    final coupleState = ref.watch(coupleProvider);
    final myPronoun = coupleState.valueOrNull?.currentUser?.partnerPronoun ?? 'she';

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
            'My partner uses:',
            style: GoogleFonts.dmSans(color: tc.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildPronounChip('she', 'She / Her', myPronoun, tc),
              _buildPronounChip('he', 'He / Him', myPronoun, tc),
              _buildPronounChip('they', 'They / Them', myPronoun, tc),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPronounChip(String value, String label, String currentValue, ThemeColors tc) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.dmSans(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: tc.iconColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: isSelected ? tc.iconColor : tc.textPrimary),
      backgroundColor: tc.inputFillColor,
      side: BorderSide(color: isSelected ? tc.iconColor : tc.borderColor),
      onSelected: (selected) {
        if (selected) {
          ref.read(coupleProvider.notifier).updatePartnerPronoun(value);
        }
      },
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
          _buildSwitchRow(
              'Daily food reminders', 'reminder_daily_food',
              _dailyFood, Icons.restaurant_rounded, tc),
          Divider(height: 1, color: tc.borderColor),
          _buildSwitchRow(
              'Hydration reminders', 'reminder_hydration',
              _hydration, Icons.water_drop_rounded, tc),
          Divider(height: 1, color: tc.borderColor),
          _buildSwitchRow(
              'Period reminders', 'reminder_period',
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
        ),
      ),
      secondary: Icon(icon, color: tc.iconColor, size: 20),
      activeColor: tc.iconColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildPinSection(ThemeColors tc) {
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
            'Keep your hidden wishlist items safe.',
            style: GoogleFonts.dmSans(color: tc.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.iconColor.withValues(alpha: 0.15),
              foregroundColor: tc.iconColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            label: Text('Set / Change PIN', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
            onPressed: _showPinDialog,
          ),
        ],
      ),
    );
  }

  void _showPinDialog() {
    final tc = ref.read(themeProvider).colors;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Wishlist PIN', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: tc.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Enter 4-digit PIN',
            hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
            counterText: '',
          ),
          style: GoogleFonts.dmSans(color: tc.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (ctrl.text.length == 4) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('wishlist_pin', ctrl.text);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN saved!')));
                }
              }
            },
            child: Text('Save', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
