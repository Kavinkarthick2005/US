import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/couple_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/partner_care_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../models/memory_model.dart';
import '../../models/food_log_model.dart';
import '../../models/wishlist_model.dart';
import '../../utils/pronoun_helper.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/v2/space_header.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/visibility_badge.dart';

class SheSpaceScreen extends ConsumerStatefulWidget {
  const SheSpaceScreen({super.key});

  @override
  ConsumerState<SheSpaceScreen> createState() => _SheSpaceScreenState();
}

class _SheSpaceScreenState extends ConsumerState<SheSpaceScreen> {
  bool _loadingLocal = true;
  String? _partnerMood;
  double? _partnerEnergy;
  String? _partnerNote;

  static const List<Color> _sheGradient = [
    Color(0xFFC97B93),
    Color(0xFFE8A0B4),
  ];

  @override
  void initState() {
    super.initState();
    _loadPartnerTodayMood();
  }

  Future<void> _loadPartnerTodayMood() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final coupleState = ref.read(coupleProvider).valueOrNull;
      final partner = coupleState?.partner;
      final gender = partner?.gender ?? 'she';

      // Load partner's today card check-in state
      if (mounted) {
        setState(() {
          _partnerMood = prefs.getString('${gender}_today_mood');
          _partnerEnergy = prefs.getDouble('${gender}_today_energy');
          _partnerNote = prefs.getString('${gender}_today_note');
          _loadingLocal = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocal = false);
    }
  }

  String _getCareTip(String mood, String partnerName) {
    switch (mood) {
      case '😊':
        return 'Great vibe today! Perfect moment to share a sweet memory or plan a dynamic surprise date together.';
      case '😔':
        return 'Feeling a bit low. A warm hug, her favorite beverage, or simply listening will mean the world today.';
      case '😤':
        return 'Stressed or overwhelmed. Give her space, make her a cup of tea, and take care of small chores silently.';
      case '😴':
        return 'Low on energy. Ensure she gets comfortable rest, bring her a cozy warm meal, and keep the vibe quiet.';
      case '🥰':
        return 'Full of love and warmth! Match her affection with a sweet message, appreciation, or a tightly held hug.';
      default:
        return 'Always a good day to check in, notice the little details, and show her a little extra care.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final tc = themeState.colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;

    final myId = coupleState?.currentUser?.id;
    final partner = coupleState?.partner;
    final partnerName = partner?.name?.split(' ').first ?? 'Her';
    final partnerPronoun = coupleState?.currentUser?.partnerPronoun ?? 'she';

    // Providers
    final periodCycle = ref.watch(periodProvider).valueOrNull;
    final periodNotifier = ref.read(periodProvider.notifier);
    final foodLogs = ref.watch(foodProvider).valueOrNull ?? [];
    final wishlist = ref.watch(wishlistProvider).valueOrNull ?? [];
    final partnerCareMemories = ref.watch(partnerCareProvider).valueOrNull ?? [];

    final currentlyOnPeriod = periodNotifier.currentlyOnPeriod;
    final daysUntilNext = periodNotifier.daysUntilNext;
    final isPeriodWeek = currentlyOnPeriod || (daysUntilNext != null && daysUntilNext <= 7);

    final timetableState = ref.watch(timetableProvider);
    final todayOverlaps = timetableState.when(
      data: (_) => ref.read(timetableProvider.notifier).getFreeOverlapForDay(DateTime.now().weekday - 1),
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    // Filter food logs logged by the female partner (target user)
    // If current user is female, she logs for herself. If partner (male) is looking, he sees her logs.
    final targetFemaleId = partnerPronoun == 'she' ? partner?.id : myId;
    final today = DateTime.now();
    final herTodayLogs = foodLogs.where((l) =>
        l.userId == targetFemaleId &&
        l.loggedAt.year == today.year &&
        l.loggedAt.month == today.month &&
        l.loggedAt.day == today.day
    ).toList();
    final herCalories = herTodayLogs.fold<int>(0, (sum, item) => sum + (item.calories ?? 0));

    // Filter wishlist items marked for her
    final herWishlist = wishlist.where((w) => !w.isDone && !w.isHidden).toList();

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: SafeArea(
        child: _loadingLocal
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC97B93)))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Space Header ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SpaceHeader(
                      emoji: '♀',
                      title: PronounHelper.world(partnerPronoun),
                      subtitle: 'Everything about $partnerName',
                      gradientColors: _sheGradient,
                      trailingWidget: GestureDetector(
                        onTap: () => context.go('/settings'),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                  ),

                  // ── Quick Actions Grid ─────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.25,
                      ),
                      delegate: SliverChildListDelegate([
                        _buildQuickAction('🌸', 'Period', '/she-space/period'),
                        _buildQuickAction('📓', 'Journal', '/she-space/journal'),
                        _buildQuickAction('✨', 'Self Care', '/she-space/self-care'),
                      ]),
                    ),
                  ),

                  // ── Main Content Sections ──────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── PARTNER MOOD CARD ────────────────────────────────
                        _buildSectionTitle('Partner Mood', 'Daily emotional status check-in'),
                        const SizedBox(height: 12),
                        _buildPartnerMoodCard(partnerName, tc),
                        const SizedBox(height: 32),

                        // ── PERIOD STATUS CARD ───────────────────────────────
                        _buildSectionTitle('Cycle Health', 'Feminine tracking & phase comfort'),
                        const SizedBox(height: 12),
                        _buildPeriodStatusCard(periodCycle, periodNotifier, myId, partnerPronoun, tc),
                        const SizedBox(height: 32),

                        // ── AI SURFACE: CYCLE COMFORT CARD ──────────────────
                        if (isPeriodWeek) ...[
                          _buildSectionTitle('AI Comfort Surfacing 🌸', 'Observed cravings & preferences during her cycle week'),
                          const SizedBox(height: 12),
                          _buildCycleComfortPanel(partnerCareMemories, tc),
                          const SizedBox(height: 32),
                        ],

                        // ── AI SURFACE: FREE TIME OVERLAPS CARD ─────────────
                        if (todayOverlaps.isNotEmpty) ...[
                          _buildSectionTitle('Free Time Shared Plans ✨', 'Observed dream places & wishlist for your overlaps today'),
                          const SizedBox(height: 12),
                          _buildFreeTimePlansPanel(partnerCareMemories, herWishlist, tc),
                          const SizedBox(height: 32),
                        ],

                        // ── THINGS SHE LOVES ─────────────────────────────────
                        _buildSectionTitle('Things ${PronounHelper.subject(partnerPronoun)} Loves', 'Remembered preferences & comfort details'),
                        const SizedBox(height: 12),
                        _buildThingsSheLovesSection(partnerCareMemories, tc),
                        const SizedBox(height: 32),

                        // ── FOOD LOG TODAY ───────────────────────────────────
                        _buildSectionTitle('Today\'s Nourishment', 'Shared meal logging overview'),
                        const SizedBox(height: 12),
                        _buildFoodLogSection(herTodayLogs, herCalories, partnerPronoun, myId, targetFemaleId, tc),
                        const SizedBox(height: 32),

                        // ── WISHLIST PREVIEW ─────────────────────────────────
                        _buildSectionTitle('Gifts & Wishlist', 'Surprises she hopes for'),
                        const SizedBox(height: 12),
                        _buildWishlistSection(herWishlist, tc),
                        const SizedBox(height: 32),

                        // ── MEMORIES ABOUT HER ───────────────────────────────
                        _buildSectionTitle('Memories Log', 'Latest moments noticed'),
                        const SizedBox(height: 12),
                        _buildMemoriesSection(partnerCareMemories, tc),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) context.go('/he-space');
          if (index == 1) context.go('/us-space');
        },
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.4),
            fontStyle: FontStyle.normal,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildQuickAction(String emoji, String title, String route) {
    return BlushGlassCard(
      onTap: () => context.push(route),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A0A0F),
              fontStyle: FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Mood Card
  Widget _buildPartnerMoodCard(String partnerName, ThemeColors tc) {
    final hasMood = _partnerMood != null && _partnerMood!.isNotEmpty;
    final tip = _getCareTip(_partnerMood ?? '', partnerName);

    return BlushGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFC97B93).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(hasMood ? _partnerMood! : '💬', style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMood ? '$partnerName is feeling $_partnerMood today' : 'No mood logged today',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A0A0F),
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    if (_partnerEnergy != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Energy: ',
                            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.normal),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _partnerEnergy!,
                                backgroundColor: Colors.black12,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFC97B93)),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(_partnerEnergy! * 100).toInt()}%',
                            style: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFC97B93), fontStyle: FontStyle.normal),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF4A2535),
                      height: 1.4,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Period Card
  Widget _buildPeriodStatusCard(
    dynamic cycle,
    PeriodNotifier notifier,
    String? myId,
    String partnerPronoun,
    ThemeColors tc,
  ) {
    if (cycle == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('🌸', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Text(
              'No cycle logged yet',
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/she-space/period'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC97B93),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Log Cycle',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
      );
    }

    final isMine = myId == cycle.userId;
    final daysUntil = notifier.daysUntilNext ?? 0;
    final isOnPeriod = notifier.currentlyOnPeriod;

    String headerText = '';
    String subText = '';
    double progress = 0.0;

    if (isOnPeriod) {
      final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final startDate = DateTime(cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
      final dayNum = todayDate.difference(startDate).inDays + 1;
      headerText = isMine ? 'Day $dayNum of my cycle 🌸' : 'Day $dayNum of her cycle 🌸';
      subText = isMine ? 'Remember to be extra gentle with yourself today 💕' : 'Be extra sweet, bring her comfort today 💕';
      progress = 1.0;
    } else {
      headerText = isMine
          ? (daysUntil == 0 ? 'My period starts today! 🌸' : 'My period starts in $daysUntil days')
          : (daysUntil == 0 ? 'Her period starts today! 🌸' : 'Her period starts in $daysUntil days');
      subText = isMine ? 'PMS symptoms might be active. Take care of yourself.' : 'Comfort food and dynamic patience is key this week.';
      
      final todayDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final startDate = DateTime(cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
      final daysElapsed = todayDate.difference(startDate).inDays;
      progress = (daysElapsed / cycle.cycleLength).clamp(0.0, 1.0);
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerText,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 160,
                    child: Text(
                      subText,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white60,
                        fontStyle: FontStyle.normal,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/she-space/period'),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC97B93).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(isOnPeriod ? '🩸' : '🌸', style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOnPeriod ? 'Period phase' : 'Follicular / Luteal phase',
                    style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.normal),
                  ),
                  Text(
                    isOnPeriod ? 'Active' : '${(progress * 100).toInt()}% through cycle',
                    style: GoogleFonts.dmMono(fontSize: 10, color: const Color(0xFFE8607A), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFC97B93)),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Loves Carousel
  Widget _buildThingsSheLovesSection(List<MemoryModel> memories, ThemeColors tc) {
    if (memories.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Text(
                'No recorded preferences yet.',
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white30, fontStyle: FontStyle.normal),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/he-space/partner-care'),
                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFFC97B93)),
                label: Text(
                  'Add preferences in Partner Care',
                  style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFC97B93), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 95,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: memories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == memories.length) {
            return GestureDetector(
              onTap: () => context.push('/he-space/partner-care'),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFC97B93), size: 20),
                    const SizedBox(height: 6),
                    Text(
                      'Add New',
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60, fontStyle: FontStyle.normal),
                    ),
                  ],
                ),
              ),
            );
          }

          final m = memories[index];
          final parsed = ParsedMemory.parse(m.content);

          return Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(MemoryModel.categoryEmoji(m.category), style: const TextStyle(fontSize: 16)),
                    VisibilityBadge(visibility: m.visibility, compact: true),
                  ],
                ),
                Text(
                  parsed.cleanContent,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontStyle: FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Food Section
  Widget _buildFoodLogSection(
    List<FoodLogModel> logs,
    int totalCalories,
    String partnerPronoun,
    String? myId,
    String? femaleId,
    ThemeColors tc,
  ) {
    final isMe = myId == femaleId;

    if (logs.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🍲', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMe
                        ? 'You haven\'t logged any meals today.'
                        : '${PronounHelper.subject(partnerPronoun)} hasn\'t logged any meals today.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFC97B93).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isMe
                    ? 'Friendly Reminder: Don\'t forget to take care of yourself and log your food! 💕'
                    : 'Wellness note: Make sure she\'s eating well and staying healthy today! 💝',
                style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFFFB3C6), fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy: $totalCalories kcal shared today',
                style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white70, fontStyle: FontStyle.normal),
              ),
              Icon(Icons.restaurant_rounded, size: 14, color: const Color(0xFFC97B93)),
            ],
          ),
          const SizedBox(height: 10),
          ...logs.take(3).map((l) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l.description,
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.normal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${l.calories ?? 0} kcal',
                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFFC97B93), fontStyle: FontStyle.normal),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // Wishlist Section
  Widget _buildWishlistSection(List<WishlistModel> wishlist, ThemeColors tc) {
    if (wishlist.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Wishlist is empty. Add some ideas! 🎁',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.white30, fontStyle: FontStyle.normal),
          ),
        ),
      );
    }

    return Column(
      children: wishlist.take(2).map((w) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.title,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, fontStyle: FontStyle.normal),
                    ),
                    if (w.price != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '₹${w.price}',
                        style: GoogleFonts.dmMono(fontSize: 10.5, color: const Color(0xFFC97B93), fontStyle: FontStyle.normal),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC97B93).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  w.type.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC97B93),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Memories Section
  Widget _buildMemoriesSection(List<MemoryModel> memories, ThemeColors tc) {
    if (memories.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No logged memories about her yet.',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white30, fontStyle: FontStyle.normal),
          ),
        ),
      );
    }

    return Column(
      children: memories.take(3).map((m) {
        final parsed = ParsedMemory.parse(m.content);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(MemoryModel.categoryEmoji(m.category), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  parsed.cleanContent,
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.normal),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── AI SURFACE: CYCLE COMFORT PANEL ─────────────────────────────────────────
  Widget _buildCycleComfortPanel(List<MemoryModel> partnerCareMemories, ThemeColors tc) {
    final comfortItems = partnerCareMemories.where((m) =>
      m.category == 'food' ||
      m.category == 'craving' ||
      m.category == 'habit' ||
      m.category == 'trigger' ||
      m.category == 'dislike'
    ).toList();

    if (comfortItems.isEmpty) {
      return BlushGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text('🌸', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "No specific cravings or comfort observations logged yet. Add observations in Partner Care to see them here!",
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF4A2535),
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BlushGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFFE8607A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Cycle Comfort Cheat Sheet',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A0A0F),
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comfortItems.length > 4 ? 4 : comfortItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = comfortItems[index];
              String label = 'Observed Details';
              Color labelBg = const Color(0xFFC97B93).withValues(alpha: 0.15);
              Color labelText = const Color(0xFF4A2535);

              if (m.category == 'food' || m.category == 'craving') {
                label = m.category == 'craving' ? 'Craving' : 'Comfort Food';
                labelBg = const Color(0xFFFFE3E8);
                labelText = const Color(0xFFD6335C);
              } else if (m.category == 'trigger' || m.category == 'dislike') {
                label = m.category == 'trigger' ? 'Avoid Trigger' : 'Dislikes';
                labelBg = const Color(0xFFFDE8E8);
                labelText = const Color(0xFFE02424);
              } else if (m.category == 'habit') {
                label = 'Sweet Habit';
                labelBg = const Color(0xFFE1F5FE);
                labelText = const Color(0xFF0288D1);
              }

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(MemoryModel.categoryEmoji(m.category), style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: labelBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: labelText,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d').format(m.createdAt),
                                style: GoogleFonts.dmMono(
                                  fontSize: 9.5,
                                  color: Colors.black45,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.content,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFF4A2535),
                              height: 1.35,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── AI SURFACE: FREE TIME OVERLAPS PANEL ────────────────────────────────────
  Widget _buildFreeTimePlansPanel(
    List<MemoryModel> partnerCareMemories,
    List<WishlistModel> wishlist,
    ThemeColors tc,
  ) {
    final plans = partnerCareMemories.where((m) =>
      m.category == 'place' ||
      m.category == 'dream'
    ).toList();

    return BlushGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_rounded, color: Color(0xFFE8607A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Shared Free Time Ideas',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A0A0F),
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty && wishlist.isEmpty)
            Text(
              "No dream destinations or wishlist items saved yet. Save places she wants to visit in Partner Care or add to the wishlist to surface them here! ✨",
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: const Color(0xFF4A2535),
                fontStyle: FontStyle.normal,
              ),
            )
          else ...[
            if (plans.isNotEmpty) ...[
              Text(
                'Dream Destinations & Journeys',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A2535),
                  fontStyle: FontStyle.normal,
                ),
              ),
              const SizedBox(height: 6),
              ...plans.take(3).map((m) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Text(m.category == 'place' ? '📍' : '🌸', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.content,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF1A0A0F),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            if (wishlist.isNotEmpty) ...[
              Text(
                'Her Wishlist Surprises',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A2535),
                  fontStyle: FontStyle.normal,
                ),
              ),
              const SizedBox(height: 6),
              ...wishlist.take(3).map((w) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC97B93).withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Text(
                          w.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF1A0A0F),
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                    if (w.price != null)
                      Text(
                        '₹${w.price}',
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE8607A),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              )),
            ],
          ],
        ],
      ),
    );
  }
}
