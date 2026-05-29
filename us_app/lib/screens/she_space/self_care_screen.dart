import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/v2/space_header.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Habit {
  const _Habit({required this.emoji, required this.label});
  final String emoji;
  final String label;
}

const List<_Habit> _habits = [
  _Habit(emoji: '💊', label: 'Took medication'),
  _Habit(emoji: '💧', label: 'Drank 8 glasses of water'),
  _Habit(emoji: '🧴', label: 'Skincare routine'),
  _Habit(emoji: '🚶', label: '10 min walk'),
  _Habit(emoji: '😴', label: 'Sleep 7+ hours'),
  _Habit(emoji: '🍎', label: 'Ate healthy'),
  _Habit(emoji: '🧘', label: 'Mindfulness moment'),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SelfCareScreen extends ConsumerStatefulWidget {
  const SelfCareScreen({super.key});

  @override
  ConsumerState<SelfCareScreen> createState() => _SelfCareScreenState();
}

class _SelfCareScreenState extends ConsumerState<SelfCareScreen> {
  static const List<Color> _sheGradient = [
    Color(0xFFC97B93),
    Color(0xFFE8A0B4),
  ];

  late List<bool> _checked;
  int _streak = 0;
  bool _loading = true;

  String get _todayKey {
    final now = DateTime.now();
    return 'self_care_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _keyForDate(DateTime d) {
    return 'self_care_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _checked = List.filled(_habits.length, false);
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_todayKey);
      if (raw != null) {
        final List<dynamic> json = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _checked = List<bool>.from(json.map((e) => e as bool));
          });
        }
      }
      // Calculate streak
      int streak = 0;
      final today = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        final key = _keyForDate(date);
        final dayRaw = prefs.getString(key);
        if (dayRaw != null) {
          final List<dynamic> dayJson = jsonDecode(dayRaw);
          final completed = dayJson.where((e) => e == true).length;
          if (completed >= 5) {
            streak++;
          } else {
            break;
          }
        } else {
          if (i == 0) continue; // today might not be saved yet
          break;
        }
      }
      if (mounted) {
        setState(() {
          _streak = streak;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveChecked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todayKey, jsonEncode(_checked));
      // Recalculate streak
      int streak = 0;
      final today = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        final key = _keyForDate(date);
        final dayRaw = prefs.getString(key);
        if (dayRaw != null) {
          final List<dynamic> dayJson = jsonDecode(dayRaw);
          final completed = dayJson.where((e) => e == true).length;
          if (completed >= 5) {
            streak++;
          } else {
            break;
          }
        } else {
          if (i == 0) continue;
          break;
        }
      }
      if (mounted) setState(() => _streak = streak);
    } catch (_) {}
  }

  void _toggle(int index, bool value) {
    setState(() => _checked[index] = value);
    _saveChecked();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    final completedCount = _checked.where((c) => c).length;
    final allDone = completedCount == _habits.length;

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Self Care',
              gradientColors: _sheGradient,
              onBack: () => Navigator.of(context).pop(),
            ).animate().fadeIn(duration: 350.ms),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFC97B93),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Progress section
                        _ProgressSection(
                          completedCount: completedCount,
                          total: _habits.length,
                          streak: _streak,
                          allDone: allDone,
                          colors: colors,
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 20),

                        if (allDone)
                          _CongratulatoryBanner()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .scale(begin: const Offset(0.9, 0.9)),

                        if (allDone) const SizedBox(height: 16),

                        // Habit cards
                        ...List.generate(_habits.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HabitCard(
                              habit: _habits[index],
                              checked: _checked[index],
                              onChanged: (v) => _toggle(index, v),
                              colors: colors,
                              delay: Duration(milliseconds: 150 + index * 70),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.completedCount,
    required this.total,
    required this.streak,
    required this.allDone,
    required this.colors,
  });

  final int completedCount;
  final int total;
  final int streak;
  final bool allDone;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final progress = completedCount / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC97B93).withOpacity(0.12),
            const Color(0xFFE8A0B4).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC97B93).withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  fontStyle: FontStyle.normal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC97B93), Color(0xFFE8A0B4)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$streak day streak 🔥',
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFC97B93).withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFC97B93),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedCount/$total',
                style: GoogleFonts.dmMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC97B93),
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CongratulatoryBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC97B93), Color(0xFFE8A0B4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You nailed it today! 🌟',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.checked,
    required this.onChanged,
    required this.colors,
    required this.delay,
  });

  final _Habit habit;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final ThemeColors colors;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: checked
            ? const Color(0xFFC97B93).withValues(alpha: 0.08)
            : colors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: checked
              ? const Color(0xFFC97B93).withValues(alpha: 0.4)
              : colors.borderColor,
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Text(habit.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(
          habit.label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: checked
                ? const Color(0xFFC97B93)
                : colors.textPrimary,
            fontStyle: FontStyle.normal,
            decoration: checked ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: checked,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: const Color(0xFFC97B93),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay).slideX(begin: -0.08, end: 0);
  }
}
