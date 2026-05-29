import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../config/app_colors.dart';
import '../../models/memory_model.dart';
import '../../providers/recap_provider.dart';
import '../../widgets/v2/space_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Slide gradient palettes — each slide gets a unique dark gradient
// ─────────────────────────────────────────────────────────────────────────────
const _slideGradients = [
  [Color(0xFF1A0A0F), Color(0xFF3D1525)],
  [Color(0xFF0D0620), Color(0xFF2A1A4A)],
  [Color(0xFF0A1A10), Color(0xFF1A3D1E)],
  [Color(0xFF1A100A), Color(0xFF3D2515)],
  [Color(0xFF1A0A0F), Color(0xFF3D1525)],
];

class MonthlyRecapScreen extends ConsumerStatefulWidget {
  const MonthlyRecapScreen({super.key});

  @override
  ConsumerState<MonthlyRecapScreen> createState() =>
      _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends ConsumerState<MonthlyRecapScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthKey = DateTime(now.year, now.month, 1);
    final recapAsync = ref.watch(monthlyRecapProvider(monthKey));

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: Column(
        children: [
          SpaceSubHeader(
            title: 'Monthly Recap',
            gradientColors: const [Color(0xFF1A0A0F), Color(0xFF3D1525)],
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: recapAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.rose),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load recap',
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
              data: (recap) => Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _Slide1Cover(recap: recap),
                      _Slide2DaysMemories(recap: recap),
                      _Slide3Spending(recap: recap),
                      _Slide4Moments(recap: recap),
                      _Slide5Wrapup(recap: recap),
                    ],
                  ),

                  // Page indicator at bottom
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        SmoothPageIndicator(
                          controller: _pageController,
                          count: 5,
                          effect: ExpandingDotsEffect(
                            activeDotColor: AppColors.rose,
                            dotColor: Colors.white.withValues(alpha: 0.25),
                            dotHeight: 6,
                            dotWidth: 6,
                            expansionFactor: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_currentPage < 4)
                          GestureDetector(
                            onTap: _nextPage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                                color:
                                    Colors.white.withValues(alpha: 0.07),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Next',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontStyle: FontStyle.normal,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 1 — Cover
// ─────────────────────────────────────────────────────────────────────────────
class _Slide1Cover extends StatelessWidget {
  final MonthlyRecapData recap;
  const _Slide1Cover({required this.recap});

  @override
  Widget build(BuildContext context) {
    final gradient = _slideGradients[0];
    return _SlideScaffold(
      gradient: gradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💕', style: TextStyle(fontSize: 64))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                duration: 1200.ms,
                begin: const Offset(0.88, 0.88),
                end: const Offset(1.12, 1.12),
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 32),
          Text(
            recap.monthLabel,
            style: GoogleFonts.playfairDisplay(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.3, end: 0, delay: 200.ms),
          const SizedBox(height: 16),
          Text(
            'Your month in review',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.7),
              fontStyle: FontStyle.normal,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 500.ms),
          const SizedBox(height: 12),
          Text(
            '— with ${recap.partnerName} —',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.rose.withValues(alpha: 0.85),
              fontStyle: FontStyle.normal,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 700.ms),
          const SizedBox(height: 80),
          Text(
            'swipe to see your story',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.35),
              fontStyle: FontStyle.normal,
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 1200.ms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 2 — Days & Memories
// ─────────────────────────────────────────────────────────────────────────────
class _Slide2DaysMemories extends StatefulWidget {
  final MonthlyRecapData recap;
  const _Slide2DaysMemories({required this.recap});

  @override
  State<_Slide2DaysMemories> createState() => _Slide2DaysMemoriesState();
}

class _Slide2DaysMemoriesState extends State<_Slide2DaysMemories> {
  @override
  Widget build(BuildContext context) {
    final gradient = _slideGradients[1];
    return _SlideScaffold(
      gradient: gradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You two shared',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
              fontStyle: FontStyle.normal,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 32),
          _AnimatedCountStat(
            value: widget.recap.memoriesAdded,
            label: 'memories',
            color: const Color(0xFF9B7AFF),
            delay: 200.ms,
          ),
          const SizedBox(height: 24),
          _AnimatedCountStat(
            value: widget.recap.dropsPosted,
            label: 'drops posted',
            color: AppColors.rose,
            delay: 500.ms,
          ),
          const SizedBox(height: 40),
          Text(
            'This month 📅',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
              fontStyle: FontStyle.normal,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 800.ms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 3 — Spending
// ─────────────────────────────────────────────────────────────────────────────
class _Slide3Spending extends StatefulWidget {
  final MonthlyRecapData recap;
  const _Slide3Spending({required this.recap});

  @override
  State<_Slide3Spending> createState() => _Slide3SpendingState();
}

class _Slide3SpendingState extends State<_Slide3Spending> {
  @override
  Widget build(BuildContext context) {
    final gradient = _slideGradients[2];
    final topCategory = widget.recap.expenseByCategory.isNotEmpty
        ? (widget.recap.expenseByCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key
        : null;

    return _SlideScaffold(
      gradient: gradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Together you spent',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 16),
          _AnimatedRupeeCount(
            value: widget.recap.totalExpenses,
            delay: 200.ms,
          ),
          const SizedBox(height: 12),
          Text(
            'this month 💰',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.55),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
          const SizedBox(height: 32),
          if (topCategory != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏷️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Top category: $topCategory',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 900.ms).slideX(
                  begin: -0.2,
                  end: 0,
                  delay: 900.ms,
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 4 — Moments
// ─────────────────────────────────────────────────────────────────────────────
class _Slide4Moments extends StatelessWidget {
  final MonthlyRecapData recap;
  const _Slide4Moments({required this.recap});

  @override
  Widget build(BuildContext context) {
    final gradient = _slideGradients[3];
    final categoryEmoji =
        MemoryModel.categoryEmoji(recap.topMemoryCategory);
    final catLabel = recap.topMemoryCategory[0].toUpperCase() +
        recap.topMemoryCategory.substring(1);

    return _SlideScaffold(
      gradient: gradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            categoryEmoji,
            style: const TextStyle(fontSize: 80),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                duration: 1400.ms,
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.1, 1.1),
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 24),
          Text(
            'Your top vibe was',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            catLabel,
            style: GoogleFonts.playfairDisplay(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 400.ms)
              .slideY(begin: 0.2, end: 0, delay: 400.ms),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SmallStat(
                emoji: '🔔',
                value: recap.remindersSet,
                label: 'reminders',
                delay: 700.ms,
              ),
              const SizedBox(width: 24),
              _SmallStat(
                emoji: '📝',
                value: recap.notesWritten,
                label: 'notes',
                delay: 900.ms,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 5 — Wrap-up
// ─────────────────────────────────────────────────────────────────────────────
class _Slide5Wrapup extends StatelessWidget {
  final MonthlyRecapData recap;
  const _Slide5Wrapup({required this.recap});

  @override
  Widget build(BuildContext context) {
    final gradient = _slideGradients[4];
    final shareText =
        '${recap.monthLabel} in review:\n'
        '📸 ${recap.memoriesAdded} memories\n'
        '💧 ${recap.dropsPosted} drops\n'
        '💰 ₹${recap.totalExpenses.toStringAsFixed(0)} spent\n'
        'Made with love — with ${recap.partnerName} 💕';

    return _SlideScaffold(
      gradient: gradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('❤️', style: TextStyle(fontSize: 80))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                duration: 1000.ms,
                begin: const Offset(0.88, 0.88),
                end: const Offset(1.12, 1.12),
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 32),
          Text(
            'Keep making memories',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.2, end: 0, delay: 200.ms),
          const SizedBox(height: 12),
          Text(
            'with ${recap.partnerName} 💕',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: AppColors.rose.withValues(alpha: 0.85),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
          const SizedBox(height: 64),
          GestureDetector(
            onTap: () => Share.share(shareText),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.rose, AppColors.mauve],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rose.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Share Our Month',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 800.ms)
              .slideY(begin: 0.3, end: 0, delay: 800.ms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared slide scaffold
// ─────────────────────────────────────────────────────────────────────────────
class _SlideScaffold extends StatelessWidget {
  final List<Color> gradient;
  final Widget child;

  const _SlideScaffold({required this.gradient, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated count-up stat
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedCountStat extends StatefulWidget {
  final int value;
  final String label;
  final Color color;
  final Duration delay;

  const _AnimatedCountStat({
    required this.value,
    required this.label,
    required this.color,
    required this.delay,
  });

  @override
  State<_AnimatedCountStat> createState() => _AnimatedCountStatState();
}

class _AnimatedCountStatState extends State<_AnimatedCountStat>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _anim.value.toInt().toString(),
            style: GoogleFonts.dmMono(
              fontSize: 72,
              fontWeight: FontWeight.w700,
              color: widget.color,
              fontStyle: FontStyle.normal,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.label,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.7),
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated rupee count-up
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedRupeeCount extends StatefulWidget {
  final double value;
  final Duration delay;

  const _AnimatedRupeeCount({required this.value, required this.delay});

  @override
  State<_AnimatedRupeeCount> createState() => _AnimatedRupeeCountState();
}

class _AnimatedRupeeCountState extends State<_AnimatedRupeeCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '₹${NumberFormat('#,##,###').format(_anim.value.toInt())}',
        style: GoogleFonts.dmMono(
          fontSize: 58,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4ADE80),
          fontStyle: FontStyle.normal,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small stat pill for Slide 4
// ─────────────────────────────────────────────────────────────────────────────
class _SmallStat extends StatelessWidget {
  final String emoji;
  final int value;
  final String label;
  final Duration delay;

  const _SmallStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: GoogleFonts.dmMono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
              fontStyle: FontStyle.normal,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: delay)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          delay: delay,
          curve: Curves.elasticOut,
        );
  }
}
