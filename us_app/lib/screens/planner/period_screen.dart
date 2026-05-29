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
import '../../utils/pronoun_helper.dart';
import '../../models/memory_model.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';

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
          SpaceSubHeader(
            title: 'Cycle & Care',
            gradientColors: const [Color(0xFFC97B93), Color(0xFFE8A0B4)],
            onBack: () => context.pop(),
          ),
          Expanded(
            child: periodState.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: const Color(0xFFC97B93)),
              ),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: tc.textPrimary))),
              data: (cycle) => _buildContent(cycle, tc),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PeriodCycleModel? cycle, ThemeColors tc) {
    final memories = ref.watch(memoryProvider).valueOrNull ?? [];
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final myId = coupleState?.currentUser?.id;
    final partnerPronoun = coupleState?.currentUser?.partnerPronoun ?? 'she';
    
    // Determine if logged user is female (i.e. self tracking)
    final isMe = cycle != null && cycle.userId == myId;

    final notifier = ref.read(periodProvider.notifier);
    final isOnPeriod = notifier.currentlyOnPeriod;
    final daysUntil = notifier.daysUntilNext ?? 0;

    // Calculate days elapsed in cycle
    int daysElapsed = 0;
    if (cycle != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final start = DateTime(cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
      daysElapsed = today.difference(start).inDays;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── STATUS CARD ──────────────────────────────────────────────────────
        _buildStatusCard(cycle, notifier, isMe, partnerPronoun, tc),
        const SizedBox(height: 20),
        
        ElevatedButton.icon(
          onPressed: () => _showLogSheet(tc),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            isOnPeriod ? 'Log Next Cycle' : 'Log Period Start',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC97B93),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 28),

        // ── CARE MODE CARD ───────────────────────────────────────────────────
        if (cycle != null) ...[
          _buildCareModePanel(daysElapsed, isOnPeriod, isMe, partnerPronoun, tc),
          const SizedBox(height: 28),
        ],

        // ── DYNAMIC CARE TIPS ────────────────────────────────────────────────
        _buildDynamicCareTips(memories, cycle, daysElapsed, isMe, partnerPronoun, tc),
        const SizedBox(height: 28),

        // ── TIMELINE HISTORY ─────────────────────────────────────────────────
        _buildHistoryTimeline(tc),
      ],
    );
  }

  // Status Card with Detailed Cycle Dial Painter
  Widget _buildStatusCard(
    PeriodCycleModel? cycle,
    PeriodNotifier notifier,
    bool isMe,
    String partnerPronoun,
    ThemeColors tc,
  ) {
    if (cycle == null) {
      return BlushGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('🌸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              isMe ? 'Track your cycle to receive personal care' : 'Log her first period to start tracking',
              style: GoogleFonts.dmSans(fontSize: 14.5, color: const Color(0xFF4A2535), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final daysUntil = notifier.daysUntilNext ?? 0;
    final isOnPeriod = notifier.currentlyOnPeriod;
    final nextDate = notifier.nextPeriodDate;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start = DateTime(cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
    final daysElapsed = today.difference(start).inDays;
    final progress = (daysElapsed / cycle.cycleLength).clamp(0.0, 1.0);

    Widget descriptionContent;

    if (isOnPeriod) {
      final dayNum = daysElapsed + 1;
      descriptionContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Day $dayNum',
            style: GoogleFonts.playfairDisplay(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A0A0F),
              fontStyle: FontStyle.normal,
            ),
          ),
          Text(
            isMe ? 'of my period' : 'of her period',
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: 8),
          Text(
            isMe ? 'Be extra gentle today 💕' : 'Be extra gentle today 💕',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: const Color(0xFFC97B93), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC97B93),
              side: const BorderSide(color: Color(0xFFC97B93)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => notifier.updateEndDate(cycle.id, DateTime.now()),
            child: Text(
              'Mark as ended',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
            ),
          ),
        ],
      );
    } else {
      descriptionContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            daysUntil <= 0 ? 'Starts' : '$daysUntil',
            style: GoogleFonts.playfairDisplay(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A0A0F),
              fontStyle: FontStyle.normal,
            ),
          ),
          Text(
            daysUntil <= 0 ? 'today!' : 'days remaining',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.black54, fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
          ),
          if (nextDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'Expected ${DateFormat.MMMd().format(nextDate)}',
              style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.normal),
            ),
          ],
        ],
      );
    }

    return BlushGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: descriptionContent),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _DetailedCycleDial(progress, cycle.cycleLength, isOnPeriod),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Day $daysElapsed',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A0A0F),
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    Text(
                      'of ${cycle.cycleLength}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.black54,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Care Mode dynamic card
  Widget _buildCareModePanel(int daysElapsed, bool isOnPeriod, bool isMe, String partnerPronoun, ThemeColors tc) {
    String title = '';
    String description = '';
    Color statusColor = const Color(0xFFC97B93);

    if (isOnPeriod) {
      title = 'Period Week';
      description = isMe
          ? 'Focus on comfort, warmth, and cozy rests. Your energy is at its lowest phase.'
          : 'Period week — comfort and care are essential. Bring her dynamic warmth, cozy treats, and extra patience.';
      statusColor = const Color(0xFFE8607A);
    } else if (daysElapsed >= 21) {
      title = 'PMS Week';
      description = isMe
          ? 'Hormones shifting. Rest up, lower stressors, and allow yourself deep breaths.'
          : 'PMS week — hormones shifting. Extra patience, listening, and quiet support are needed this week.';
      statusColor = const Color(0xFF9B2647);
    } else if (daysElapsed >= 15) {
      title = 'Luteal Phase';
      description = isMe
          ? 'Energy is shifting. Perfect time for soft mindfulness, light routines, and comfort.'
          : 'Luteal transition. She is transitioning into a calmer phase. Cozy movie nights and low-intensity dates fit best.';
      statusColor = const Color(0xFFC97B93);
    } else if (daysElapsed >= 11 && daysElapsed <= 14) {
      title = 'Fertility / Ovulation';
      description = isMe
          ? 'Estrogen levels at peak! High energy, clear confidence, and great physical state.'
          : 'Ovulation peak. Her mood and energy are at their bright heights! Perfect for active dates and adventures.';
      statusColor = const Color(0xFF8BB5C9);
    } else {
      title = 'Recovery & Focus';
      description = isMe
          ? 'Recovery phase. Focus on rebuilding energies, gym routines, and starting fresh ambitious targets.'
          : 'Recovery phase — energy is returning. A supportive and active week to build projects and share goals.';
      statusColor = const Color(0xFFA0C9A5);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubtitleHeader('Current Cycle Status', 'Dynamic care phase mapping'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(color: statusColor.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.bubble_chart_rounded, color: statusColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.4,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Dynamic Care Tips based on her actual favorite food/habit recorded memories
  Widget _buildDynamicCareTips(
    List<MemoryModel> memories,
    PeriodCycleModel? cycle,
    int daysElapsed,
    bool isMe,
    String partnerPronoun,
    ThemeColors tc,
  ) {
    // Find food preferences in memories
    final preferences = memories.where((m) => m.category == 'food' || m.category == 'habit').toList();

    String comfortFoodText = '';
    if (preferences.isNotEmpty) {
      final item = preferences.first;
      final parsed = ParsedMemory.parse(item.content);
      comfortFoodText = parsed.cleanContent;
    }

    String finalTip = '';
    if (cycle == null) {
      finalTip = 'Record cycle details to generate personalized health suggestions.';
    } else if (comfortFoodText.isNotEmpty) {
      if (isMe) {
        finalTip = 'Since you recorded "$comfortFoodText" in your preferences, it is a great comfort food option to satisfy cravings this week! 🍫';
      } else {
        finalTip = 'She loves "$comfortFoodText"! Surprise her by ordering or making this for her to match her comfort cravings this week! 💝';
      }
    } else {
      if (isMe) {
        finalTip = 'Remember to stay hydrated and prioritize comforting meals (like chocolates, fresh fruits, or warm soups) to nurture yourself this week.';
      } else {
        finalTip = 'No custom food preferences detected in observations yet. Notice what she loves to eat and capture it in He Space so we can dynamic-tailor tips!';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubtitleHeader('Dynamic Care Tips', 'Personalized suggestions from saved preferences'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF160A0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🍲', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      finalTip,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.4,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Add Care reminder TextField
              TextField(
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontStyle: FontStyle.normal),
                decoration: InputDecoration(
                  hintText: 'Add an custom care reminder...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.25), fontStyle: FontStyle.normal),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.02),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: const Icon(Icons.add_circle, size: 18, color: Color(0xFFC97B93)),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    final coupleState = ref.read(coupleProvider).valueOrNull;
                    final targetOwner = coupleState?.partner?.id ?? coupleState?.currentUser?.id ?? 'single_mode';
                    ref.read(memoryProvider.notifier).addMemory(
                          content: val.trim(),
                          category: 'habit',
                          ownerId: targetOwner,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Saved reminder! 🌸', style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
                        backgroundColor: const Color(0xFFC97B93),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // History timeline scrapbook style
  Widget _buildHistoryTimeline(ThemeColors tc) {
    final history = ref.watch(periodHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubtitleHeader('Previous Cycles', 'Feminine history timeline'),
        const SizedBox(height: 14),
        history.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC97B93))),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            final completed = list.where((c) => c.endDate != null).toList();
            if (completed.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No completed cycles logged yet. 🌸',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.white24, fontStyle: FontStyle.normal),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completed.length,
              itemBuilder: (context, idx) {
                final c = completed[idx];
                final duration = c.endDate!.difference(c.startDate).inDays + 1;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('d MMM').format(c.startDate)} – ${DateFormat('d MMM yyyy').format(c.endDate!)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$duration days period flow',
                            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.normal),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC97B93).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${c.cycleLength} days cycle',
                          style: GoogleFonts.dmMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFC97B93),
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubtitleHeader(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          desc,
          style: GoogleFonts.dmSans(fontSize: 10.5, color: Colors.white24, fontStyle: FontStyle.normal),
        ),
      ],
    );
  }
}

// Custom painter drawing Detailed Ovulation, Cycle Dial
class _DetailedCycleDial extends CustomPainter {
  final double progress;
  final int cycleLength;
  final bool isOnPeriod;

  const _DetailedCycleDial(this.progress, this.cycleLength, this.isOnPeriod);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track circle
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Dynamic phase indicators overlay
    // Flow/Period Phase (Days 1-5, red sector)
    final flowPaint = Paint()
      ..color = const Color(0xFFE8607A).withValues(alpha: 0.15)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, -math.pi / 2, (2 * math.pi) * (5 / cycleLength), false, flowPaint);

    // Ovulation / Fertility peak (Days 12-16, blue glow arc)
    final fertilePaint = Paint()
      ..color = const Color(0xFF8BB5C9).withValues(alpha: 0.15)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, -math.pi / 2 + (2 * math.pi) * (11 / cycleLength), (2 * math.pi) * (5 / cycleLength), false, fertilePaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = isOnPeriod ? const Color(0xFFE8607A) : const Color(0xFFC97B93)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, progressPaint);

    // Indicator Dot
    final angle = -math.pi / 2 + 2 * math.pi * progress;
    final dotOffset = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(dotOffset, 7, dotPaint);

    final dotOutline = Paint()
      ..color = const Color(0xFFC97B93)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(dotOffset, 7, dotOutline);
  }

  @override
  bool shouldRepaint(_DetailedCycleDial old) =>
      old.progress != progress || old.cycleLength != cycleLength || old.isOnPeriod != isOnPeriod;
}

// Bottom sheet cycle logger
class _LogPeriodSheet extends ConsumerStatefulWidget {
  const _LogPeriodSheet();

  @override
  ConsumerState<_LogPeriodSheet> createState() => _LogPeriodSheetState();
}

class _LogPeriodSheetState extends ConsumerState<_LogPeriodSheet> {
  DateTime _startDate = DateTime.now();
  int _cycleLength = 28;
  bool _isSaving = false;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 45)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC97B93),
            surface: Color(0xFF160A0D),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(periodProvider.notifier).logPeriod(_startDate, _cycleLength);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text("Cycle logged! Reminders are active 💕", style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
          backgroundColor: const Color(0xFFC97B93),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF160A0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Log Cycle Start',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start Date',
            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white54, fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('d MMMM yyyy').format(_startDate),
                    style: GoogleFonts.dmSans(fontSize: 13.5, color: Colors.white70, fontStyle: FontStyle.normal),
                  ),
                  const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFFC97B93)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Typical Cycle Duration: $_cycleLength days',
            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white54, fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: 6),
          Slider(
            value: _cycleLength.toDouble(),
            min: 21,
            max: 35,
            divisions: 14,
            activeColor: const Color(0xFFC97B93),
            inactiveColor: Colors.white10,
            label: '$_cycleLength days',
            onChanged: (val) => setState(() => _cycleLength = val.round()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC97B93),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Cycle', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
            ),
          ),
        ],
      ),
    );
  }
}
