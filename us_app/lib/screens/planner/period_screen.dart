import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/period_model.dart';
import '../../providers/period_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/rose_button.dart';

class PeriodScreen extends ConsumerStatefulWidget {
  const PeriodScreen({super.key});

  @override
  ConsumerState<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends ConsumerState<PeriodScreen> {
  void _showLogSheet(ThemeColors tc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogPeriodSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodState = ref.watch(periodProvider);
    final tc          = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: Column(
        children: [
          _buildHeader(tc),
          Expanded(
            child: periodState.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: tc.iconColor),
              ),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: tc.textPrimary))),
              data: (cycle) => _buildContent(cycle, tc),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        border: Border(bottom: BorderSide(color: tc.borderColor)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 24, 24),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: tc.textPrimary, size: 20),
                onPressed: () => context.pop(),
              ),
              Text(
                'Cycle Tracker',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────

  Widget _buildContent(PeriodCycleModel? cycle, ThemeColors tc) {
    final notifier = ref.read(periodProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _buildStatusCard(cycle, notifier, tc),
        const SizedBox(height: 20),
        RoseButton(label: 'Log Period Start', onTap: () => _showLogSheet(tc)),
        const SizedBox(height: 32),
        _buildCareTips(tc),
        const SizedBox(height: 32),
        _buildHistory(tc),
      ],
    );
  }

  // ── Status Card ────────────────────────────────────────────────────────────

  Widget _buildStatusCard(PeriodCycleModel? cycle, PeriodNotifier notifier, ThemeColors tc) {
    Widget cardContent;

    if (cycle == null) {
      cardContent = _buildNoDataContent(tc);
    } else if (notifier.currentlyOnPeriod) {
      cardContent = _buildOnPeriodContent(cycle, notifier, tc);
    } else {
      cardContent = _buildCountdownContent(cycle, notifier, tc);
    }

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tc.iconColor.withValues(alpha: 0.40),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tc.iconColor.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GlassCard(
        borderRadius: 19,
        padding: const EdgeInsets.all(24),
        child: cardContent,
      ),
    );
  }

  // No data state
  Widget _buildNoDataContent(ThemeColors tc) {
    return Column(
      children: [
        const Text('🩸', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          'No cycle logged yet',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: tc.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Log her first period to start tracking',
          style: GoogleFonts.dmSans(fontSize: 13, color: tc.textMuted),
        ),
      ],
    );
  }

  // Currently on period state
  Widget _buildOnPeriodContent(PeriodCycleModel cycle, PeriodNotifier notifier, ThemeColors tc) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start = DateTime(
        cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
    final dayNum = today.difference(start).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Day $dayNum',
              style: GoogleFonts.playfairDisplay(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: tc.iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'of her period',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: tc.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Be gentle with her today 💕',
          style: GoogleFonts.dmSans(fontSize: 14, color: tc.textMuted),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: tc.iconColor,
            side: BorderSide(color: tc.iconColor),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () =>
              notifier.updateEndDate(cycle.id, DateTime.now()),
          child: Text(
            'Mark period as ended',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600, color: tc.iconColor),
          ),
        ),
      ],
    );
  }

  // Countdown state
  Widget _buildCountdownContent(PeriodCycleModel cycle, PeriodNotifier notifier, ThemeColors tc) {
    final daysUntil = notifier.daysUntilNext ?? 0;
    final nextDate = notifier.nextPeriodDate;

    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start = DateTime(
        cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
    final daysElapsed = today.difference(start).inDays;
    final progress = (daysElapsed / cycle.cycleLength).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next period in',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: tc.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daysUntil <= 0 ? '0' : '$daysUntil',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: tc.iconColor,
                    ),
                  ),
                  Text(
                    daysUntil <= 0 ? 'Due today!' : 'days',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: tc.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (nextDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Around ${DateFormat.MMMd().format(nextDate)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(120, 120),
                    painter: _CycleArcPainter(progress, tc.iconColor, tc.borderColor),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Day $daysElapsed',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                      Text(
                        'of ${cycle.cycleLength}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: tc.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCareTips(ThemeColors tc) {
    final memoriesState = ref.watch(memoryProvider);
    final cardWidth =
        (MediaQuery.of(context).size.width - 40 - 12) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to care for her 💕',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        memoriesState.when(
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const SizedBox(),
          data: (memories) {
            final tips = memories.where((m) => 
                m.category.toLowerCase() == 'habit' || 
                m.category.toLowerCase() == 'food' ||
                m.category.toLowerCase() == 'care').toList();
            
            return Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: tips.isEmpty 
                    ? [
                        Text('No care tips added yet. Add one below!', 
                          style: GoogleFonts.dmSans(color: tc.textMuted))
                      ]
                    : tips.map((m) {
                    return SizedBox(
                      width: cardWidth,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tc.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: tc.borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.category.toLowerCase() == 'food' ? '🍲' : '💕',
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m.content,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: tc.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  style: GoogleFonts.dmSans(color: tc.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Add a new care reminder...',
                    hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                    filled: true,
                    fillColor: tc.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tc.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tc.borderColor),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add_circle, color: tc.iconColor),
                      onPressed: () {}, // Handled by onSubmitted
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      final coupleState = ref.read(coupleProvider).valueOrNull;
                      final partnerId = coupleState?.partner?.id ?? coupleState?.currentUser?.id ?? 'single_mode';
                      ref.read(memoryProvider.notifier).addMemory(
                        val.trim(),
                        'care',
                        partnerId,
                      );
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── History ────────────────────────────────────────────────────────────────

  Widget _buildHistory(ThemeColors tc) {
    final historyState = ref.watch(periodHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        historyState.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: tc.iconColor)),
          error: (e, _) =>
              Text('Error: $e', style: GoogleFonts.dmSans(color: tc.textMuted)),
          data: (entries) {
            // Only show completed cycles
            final completed =
                entries.where((c) => c.endDate != null).toList();
            if (completed.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No completed cycles yet',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: tc.textMuted),
                  ),
                ),
              );
            }
            return Column(
              children: completed
                  .map((c) => _buildHistoryItem(c, tc))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryItem(PeriodCycleModel cycle, ThemeColors tc) {
    final duration =
        cycle.endDate!.difference(cycle.startDate).inDays + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat.MMMd().format(cycle.startDate)} – ${DateFormat.MMMd().format(cycle.endDate!)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$duration day period',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: tc.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tc.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${cycle.cycleLength}-day cycle',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tc.iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arc Painter ────────────────────────────────────────────────────────────────

class _CycleArcPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  const _CycleArcPainter(this.progress, this.activeColor, this.trackColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    // Progress arc with gradient
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = activeColor
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CycleArcPainter old) => old.progress != progress || old.activeColor != activeColor || old.trackColor != trackColor;
}

// ── Log Period Bottom Sheet ────────────────────────────────────────────────────

class _LogPeriodSheet extends ConsumerStatefulWidget {
  const _LogPeriodSheet();

  @override
  ConsumerState<_LogPeriodSheet> createState() => _LogPeriodSheetState();
}

class _LogPeriodSheetState extends ConsumerState<_LogPeriodSheet> {
  DateTime _startDate = DateTime.now();
  int _cycleLength = 28;
  bool _isSaving = false;

  Future<void> _pickDate(ThemeColors tc) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: tc.iconColor,
            surface: tc.cardColor,
            onSurface: tc.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _save(ThemeColors tc) async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(periodProvider.notifier)
          .logPeriod(_startDate, _cycleLength);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text("Logged. I'll remind you before next time 💕"),
          backgroundColor: tc.iconColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tc.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Log Period Start',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Date picker row
          Text(
            'When did it start?',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tc.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickDate(tc),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: tc.borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: tc.iconColor, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat.yMMMd().format(_startDate),
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: tc.textMuted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Cycle length slider
          RichText(
            text: TextSpan(
              style: GoogleFonts.dmSans(fontSize: 14, color: tc.textPrimary),
              children: [
                const TextSpan(text: 'Her cycle is usually '),
                TextSpan(
                  text: '$_cycleLength',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: tc.iconColor,
                  ),
                ),
                const TextSpan(text: ' days'),
              ],
            ),
          ),
          Slider(
            value: _cycleLength.toDouble(),
            min: 21,
            max: 35,
            divisions: 14,
            activeColor: tc.iconColor,
            inactiveColor: tc.iconColor.withValues(alpha: 0.3),
            label: '$_cycleLength days',
            onChanged: (v) => setState(() => _cycleLength = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('21',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: tc.textMuted)),
              Text('35',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: tc.textMuted)),
            ],
          ),
          const SizedBox(height: 28),

          RoseButton(
            label: 'Save',
            isLoading: _isSaving,
            onTap: _isSaving ? null : () => _save(tc),
          ),
        ],
      ),
      ),
    );
  }
}
