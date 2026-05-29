import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/recap_provider.dart';
import '../../widgets/couple_avatar.dart';

class MonthlyRecapScreen extends ConsumerStatefulWidget {
  final int month;
  final int year;

  const MonthlyRecapScreen({super.key, required this.month, required this.year});

  @override
  ConsumerState<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends ConsumerState<MonthlyRecapScreen> {
  final PageController _pageController = PageController();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isTakingScreenshot = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(recapProvider.notifier).generateRecap(widget.month, widget.year);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _shareScreenshot() async {
    setState(() => _isTakingScreenshot = true);
    try {
      final image = await _screenshotController.capture(delay: const Duration(milliseconds: 10));
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/our_month.png').create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'Our month together 💕');
      }
    } finally {
      if (mounted) setState(() => _isTakingScreenshot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recapAsync = ref.watch(recapProvider);
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final currentUser = ref.watch(currentUserProvider);
    final partner = coupleState?.partner;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0509),
      body: recapAsync.when(
        loading: () => _buildLoadingState(),
        error: (err, _) => _buildErrorState(err.toString()),
        data: (data) {
          if (data == null) return _buildLoadingState();
          return Stack(
            children: [
              Screenshot(
                controller: _screenshotController,
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSlide1Opening(data, currentUser?.userMetadata?['avatar_url'], partner?.avatarUrl),
                    _buildSlide2Mood(data),
                    _buildSlide3Memories(data),
                    _buildSlide4Finances(data),
                    _buildSlide5Partner(data, partner?.name),
                    _buildSlide6Moments(data),
                    _buildSlide7Insight(data),
                  ],
                ),
              ),
              // Overlay controls (hidden during screenshot)
              if (!_isTakingScreenshot) ...[
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: 7,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 6,
                        dotWidth: 6,
                        activeDotColor: AppColors.rose,
                        dotColor: Colors.white24,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💕', style: TextStyle(fontSize: 48)).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 1.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
          const SizedBox(height: 24),
          Text(
            'Generating Your Story...',
            style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          ).animate().fadeIn(duration: 1.seconds),
          const SizedBox(height: 12),
          Text(
            'Reflecting on memories, drops, and shared moments...',
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white54),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not generate recap: $error', style: const TextStyle(color: Colors.white54)),
      ),
    );
  }

  // ── SLIDES ───────────────────────────────────────────────────────────────

  Widget _buildSlide1Opening(RecapData data, String? myAvatar, String? partnerAvatar) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(data.year, data.month));
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3D1525), Color(0xFF0F0509)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoupleAvatar(myAvatarUrl: myAvatar, partnerAvatarUrl: partnerAvatar, size: 100)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              const SizedBox(height: 40),
              Text(
                monthName.toUpperCase(),
                style: GoogleFonts.dmMono(fontSize: 16, letterSpacing: 6, color: AppColors.rose, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5),
              const SizedBox(height: 16),
              Text(
                'Your month,\ntogether 💑',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold, height: 1.2),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide2Mood(RecapData data) {
    return Container(
      color: const Color(0xFF1A0A0F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'THIS MONTH WAS A',
              style: GoogleFonts.dmSans(fontSize: 14, letterSpacing: 4, color: Colors.white54, fontWeight: FontWeight.bold),
            ).animate().fadeIn(),
            const SizedBox(height: 24),
            Text(
              data.moodLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(fontSize: 56, color: AppColors.rose, fontWeight: FontWeight.bold, height: 1.1),
            ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${data.daysInMonth} days shared together',
                  style: GoogleFonts.dmSans(fontSize: 18, color: Colors.white70),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide3Memories(RecapData data) {
    return Container(
      color: const Color(0xFF2C131C),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You captured the magic.',
                style: GoogleFonts.playfairDisplay(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold, height: 1.2),
              ).animate().fadeIn().slideX(begin: -0.1),
              const SizedBox(height: 48),
              _buildStatRow('🧠', data.memoriesCount, 'memories saved', delay: 300),
              const SizedBox(height: 32),
              _buildStatRow('📸', data.dropsCount, 'moments shared', delay: 600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String emoji, int count, String label, {required int delay}) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 48)).animate().fadeIn(delay: delay.ms).scale(),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: GoogleFonts.dmMono(fontSize: 42, color: AppColors.rose, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: (delay + 100).ms),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 18, color: Colors.white70),
            ).animate().fadeIn(delay: (delay + 200).ms),
          ],
        ),
      ],
    );
  }

  Widget _buildSlide4Finances(RecapData data) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1B0B), Color(0xFF0F0509)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'INVESTED IN US',
              style: GoogleFonts.dmSans(fontSize: 14, letterSpacing: 4, color: Colors.white54, fontWeight: FontWeight.bold),
            ).animate().fadeIn(),
            const SizedBox(height: 24),
            Text(
              '₹${data.totalExpenses.toInt()}',
              style: GoogleFonts.playfairDisplay(fontSize: 64, color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 300.ms).scale(),
            const SizedBox(height: 16),
            Text(
              'Spent together this month 💸',
              style: GoogleFonts.dmSans(fontSize: 18, color: Colors.white70),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Mostly on ${data.topCategory}',
                style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white),
              ),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide5Partner(RecapData data, String? partnerName) {
    final pName = partnerName?.split(' ').first ?? 'Partner';
    return Container(
      color: const Color(0xFF1E0D14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$pName's Highlights",
              style: GoogleFonts.playfairDisplay(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
            ).animate().fadeIn().slideX(begin: -0.1),
            const SizedBox(height: 40),
            _buildHighlightItem('🌸', 'Cared for during period', '${data.periodDays} days', 300),
            const SizedBox(height: 24),
            _buildHighlightItem('🍲', 'Favorite shared food', data.topFood, 500),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightItem(String emoji, String title, String subtitle, int delay) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
        ).animate().fadeIn(delay: delay.ms).scale(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white54),
              ).animate().fadeIn(delay: (delay + 100).ms),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(delay: (delay + 200).ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlide6Moments(RecapData data) {
    return Container(
      color: const Color(0xFF0F0509),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Story',
              style: GoogleFonts.dmSans(fontSize: 14, letterSpacing: 4, color: AppColors.rose, fontWeight: FontWeight.bold),
            ).animate().fadeIn(),
            const SizedBox(height: 16),
            Text(
              'Top Moments 💕',
              style: GoogleFonts.playfairDisplay(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 48),
            ...data.topMoments.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key + 1}.', style: GoogleFonts.dmMono(fontSize: 24, color: AppColors.rose, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.dmSans(fontSize: 20, color: Colors.white70, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (400 + (e.key * 200)).ms).slideX(begin: 0.1);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide7Insight(RecapData data) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D1525), Color(0xFF0F0509)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💌', style: TextStyle(fontSize: 48)).animate().fadeIn().scale(),
              const SizedBox(height: 32),
              Text(
                '"${data.insightText}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(fontSize: 28, color: Colors.white, fontStyle: FontStyle.italic, height: 1.4),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 24),
              Text(
                '— Your Us AI 💕',
                style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.rose, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 800.ms),
              const SizedBox(height: 64),
              if (!_isTakingScreenshot)
                ElevatedButton.icon(
                  onPressed: _shareScreenshot,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text('Save Our Month 💕', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3D1525),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.5),
            ],
          ),
        ),
      ),
    );
  }
}
