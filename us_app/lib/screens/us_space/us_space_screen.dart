import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_colors.dart';
import '../../models/memory_model.dart';
import '../../models/wishlist_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/drops_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/period_provider.dart';
import '../../providers/partner_care_provider.dart';
import '../../providers/recap_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/couple_avatar.dart';
import '../../widgets/v2/glass_container.dart';

class UsSpaceScreen extends ConsumerStatefulWidget {
  const UsSpaceScreen({super.key});

  @override
  ConsumerState<UsSpaceScreen> createState() => _UsSpaceScreenState();
}

class _UsSpaceScreenState extends ConsumerState<UsSpaceScreen>
    with SingleTickerProviderStateMixin {
  int _daysTogether = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadDaysTogether();
  }

  Future<void> _loadDaysTogether() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('couple_start_date');
      if (saved != null) {
        final start = DateTime.parse(saved);
        final diff = DateTime.now().difference(start).inDays;
        if (mounted) setState(() => _daysTogether = diff >= 0 ? diff : 0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go('/he-space');
        break;
      case 1:
        break; // already here
      case 2:
        context.go('/she-space');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = ref.watch(coupleProvider);
    final themeState = ref.watch(themeProvider);
    final tc = themeState.colors;
    final currentUser = ref.watch(currentUserProvider);

    final myName = currentUser?.userMetadata?['name']?.toString().split(' ').first ?? 'Love';
    final partner = coupleState.valueOrNull?.partner;
    final partnerName = partner?.name.split(' ').first ?? 'Partner';

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      bottomNavigationBar: BottomNav(currentIndex: 1, onTap: _onNavTap),
      body: Stack(
        children: [
          // Background Gradient (Bleeds into content)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF3D1525),
                  Color(0xFF1E0D14),
                  Color(0xFF0F0509),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── HEADER ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Greeting
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting,',
                              style: GoogleFonts.dmSans(
                                color: Colors.white54,
                                fontSize: 13,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            Text(
                              myName,
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                        // Center title
                        Text(
                          'Us',
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        // Right widgets
                        Row(
                          children: [
                            CoupleAvatar(
                              myAvatarUrl: currentUser?.userMetadata?['avatar_url'],
                              partnerAvatarUrl: partner?.avatarUrl,
                              size: 42,
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.go('/settings'),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.08),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── RELATIONSHIP STAT BANNER ─────────────────────────────────
                      _buildRelationshipStatBanner(tc),
                      const SizedBox(height: 24),

                      // ── TODAY SECTION ───────────────────────────────────────────
                      _buildTodaySection(tc, partnerName),
                      const SizedBox(height: 24),

                      // ── QUICK ACTIONS ROW ───────────────────────────────────────
                      _buildQuickActionsRow(tc),
                      const SizedBox(height: 28),

                      // ── LATEST SCRAPBOOK DROP ────────────────────────────────────
                      _buildLatestDropSection(tc, partnerName),
                      const SizedBox(height: 28),

                      // ── SHARED MEMORIES PREVIEW ──────────────────────────────────
                      _buildSharedMemoriesPreview(tc),
                      const SizedBox(height: 28),

                      // ── WISHLIST PEEK ───────────────────────────────────────────
                      _buildWishlistPeek(tc),
                      const SizedBox(height: 28),

                      // ── FINANCES SUMMARY ────────────────────────────────────────
                      _buildFinancesSummary(tc),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Relationship Stat Banner ────────────────────────────────────────────
  Widget _buildRelationshipStatBanner(ThemeColors tc) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final drops = ref.watch(dropsProvider).valueOrNull ?? [];

    String lastDropText = 'No drops yet';
    if (drops.isNotEmpty) {
      final latest = drops.first;
      final diff = DateTime.now().difference(latest.createdAt);
      if (diff.inHours < 1) {
        lastDropText = 'Drop: Just now';
      } else if (diff.inDays < 1) {
        lastDropText = 'Drop: ${diff.inHours}h ago';
      } else {
        lastDropText = 'Drop: ${diff.inDays}d ago';
      }
    }

    return GlassContainer(
      blur: 15,
      tint: Colors.white,
      tintOpacity: 0.05,
      borderRadius: 24,
      border: Border.all(color: Colors.white.withOpacity(0.08)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            // Days together large number
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Text(
                      '$_daysTogether',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: AppColors.rose,
                        fontStyle: FontStyle.normal,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'DAYS TOGETHER',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white70,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(
              height: 50,
              width: 1,
              color: Colors.white12,
            ),
            const SizedBox(width: 16),
            // Small stats
            Expanded(
              flex: 3,
              child: statsAsync.when(
                loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💭', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '${stats['memories']} memories',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('📸', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          lastDropText,
                          style: GoogleFonts.dmSans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Today's Section ─────────────────────────────────────────────────────
  Widget _buildTodaySection(ThemeColors tc, String partnerName) {
    // 1. Free time overlaps today
    final weekday = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
    final timetableState = ref.watch(timetableProvider);
    final todayOverlaps = timetableState.when(
      data: (_) => ref.read(timetableProvider.notifier).getFreeOverlapForDay(weekday),
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    // 2. Period tracking comfort status
    final currentlyOnPeriod = ref.watch(periodProvider.notifier).currentlyOnPeriod;
    final daysUntilNext = ref.watch(periodProvider.notifier).daysUntilNext;
    final showPeriodComfort = currentlyOnPeriod || (daysUntilNext != null && daysUntilNext <= 3);
    final isPeriodWeek = currentlyOnPeriod || (daysUntilNext != null && daysUntilNext <= 7);

    // 3. Partner Care Memories context
    final partnerCareMemories = ref.watch(partnerCareProvider).valueOrNull ?? [];

    // 4. Reminders for today
    final remindersAsync = ref.watch(remindersProvider);
    final todayReminders = remindersAsync.when(
      data: (list) {
        final now = DateTime.now();
        return list.where((r) =>
            r.remindAt.year == now.year &&
            r.remindAt.month == now.month &&
            r.remindAt.day == now.day).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );

    if (todayOverlaps.isEmpty && !showPeriodComfort && !isPeriodWeek && todayReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'TODAY',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white54,
              fontStyle: FontStyle.normal,
            ),
          ),
        ),
        // Free Overlap banner
        if (todayOverlaps.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('💕', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You're both free today!",
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF81C784),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      Text(
                        todayOverlaps.join(', '),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white70,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'ai_chat_prefill',
                      "We're both free today (${todayOverlaps.join(', ')}). Suggest a creative and romantic relationship micro-activity we can do right now! 💕",
                    );
                    if (mounted) context.go('/us-space/ai-chat');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    'Plan ✨',
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Period Alert Card
        if (showPeriodComfort) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('🌸', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentlyOnPeriod ? 'Comfort Mode is active 💕' : 'Cycle starts soon',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.rose,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      Text(
                        currentlyOnPeriod
                            ? 'She is currently on her cycle. Bring her comfort food!'
                            : 'Starting in $daysUntilNext days. Be extra thoughtful.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white70,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Cycle Comfort Surfaced Panel (Period Week)
        if (isPeriodWeek) ...[
          _buildPeriodComfortSection(partnerCareMemories, tc),
          const SizedBox(height: 10),
        ],

        // Free Time Destination Surfaced Panel (Overlap)
        if (todayOverlaps.isNotEmpty) ...[
          _buildFreeTimeDestinationsSection(partnerCareMemories, tc),
          const SizedBox(height: 10),
        ],

        // Today Reminders Horizontal list
        if (todayReminders.isNotEmpty) ...[
          SizedBox(
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: todayReminders.length,
              itemBuilder: (context, i) {
                final r = todayReminders[i];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Text(r.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            Text(
                              DateFormat.jm().format(r.remindAt),
                              style: GoogleFonts.dmMono(
                                color: Colors.white38,
                                fontSize: 11,
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
          ),
        ],
      ],
    );
  }

  // ── 3. Quick Actions row ───────────────────────────────────────────────────
  Widget _buildQuickActionsRow(ThemeColors tc) {
    final actions = [
      {'emoji': '📸', 'label': 'Drop', 'route': '/us-space/drops/add'},
      {'emoji': '🧠', 'label': 'Memory', 'route': '/he-space/partner-care/add'},
      {'emoji': '💸', 'label': 'Expense', 'route': '/us-space/finance/add'},
      {'emoji': '✨', 'label': 'Ask AI', 'route': '/us-space/ai-chat'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        return GestureDetector(
          onTap: () => context.go(a['route']!),
          child: Column(
            children: [
              GlassContainer(
                blur: 10,
                width: 64,
                height: 64,
                borderRadius: 32,
                tintOpacity: 0.08,
                tint: Colors.white,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                child: Center(
                  child: Text(
                    a['emoji']!,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 3.seconds, color: AppColors.rose.withOpacity(0.1)),
              const SizedBox(height: 8),
              Text(
                a['label']!,
                style: GoogleFonts.dmSans(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 4. Latest Scrapbook Drop (Polaroid Cinematic Style) ─────────────────────
  Widget _buildLatestDropSection(ThemeColors tc, String partnerName) {
    final drops = ref.watch(dropsProvider).valueOrNull ?? [];
    final myId = Supabase.instance.client.auth.currentUser?.id;
    
    // Find the latest drop overall, ideally partner's if available
    final partnerDrops = drops.where((d) => d.addedBy != myId).toList();
    final latestDrop = partnerDrops.isNotEmpty ? partnerDrops.first : (drops.isNotEmpty ? drops.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'LATEST DROP MOMENT',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white54,
              fontStyle: FontStyle.normal,
            ),
          ),
        ),
        if (latestDrop == null)
          GestureDetector(
            onTap: () => context.go('/us-space/drops/add'),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.02),
                border: Border.all(color: Colors.white.withOpacity(0.08), style: BorderStyle.solid),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💕', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 10),
                    Text(
                      'Send your first moment 💕',
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share a quick polaroid drop with your love',
                      style: GoogleFonts.dmSans(
                        color: Colors.white30,
                        fontSize: 12,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () => context.go('/us-space/drops'),
            child: Center(
              child: Transform.rotate(
                angle: -0.015,
                child: Container(
                  width: 310,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F6F0), // Classic warm cream polaroid background
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo frame
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: CachedNetworkImage(
                            imageUrl: latestDrop.photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
                            errorWidget: (_, __, ___) => Container(color: Colors.black12, child: const Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Stamped caption & ink text
                      Text(
                        latestDrop.caption ?? 'Thinking of us... 💕',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFF1E1E1E),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.music_note_rounded, size: 14, color: Colors.black38),
                              const SizedBox(width: 4),
                              Text(
                                latestDrop.songTitle ?? 'Our Song',
                                style: GoogleFonts.dmMono(
                                  color: Colors.black45,
                                  fontSize: 11,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            timeago.format(latestDrop.createdAt),
                            style: GoogleFonts.dmSans(
                              color: Colors.black38,
                              fontSize: 11,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── 5. Shared Memories Horizontal Preview ──────────────────────────────────
  Widget _buildSharedMemoriesPreview(ThemeColors tc) {
    final memories = ref.watch(memoryProvider).valueOrNull ?? [];
    final sharedList = memories.where((m) => m.visibility == 'shared').take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'SHARED SCRAPBOOK MEMORIES',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white54,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/us-space/memories'),
              child: Text(
                'See all',
                style: GoogleFonts.dmSans(
                  color: AppColors.rose,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (sharedList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Text(
              'No shared memories yet 💭',
              style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.normal),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: sharedList.length,
              itemBuilder: (context, i) {
                final m = sharedList[i];
                final emoji = MemoryModel.categoryEmoji(m.category);
                return Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            m.category.toUpperCase(),
                            style: GoogleFonts.dmMono(
                              color: AppColors.rose,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          m.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: Colors.white70,
                            fontSize: 13,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          DateFormat('MMM d').format(m.createdAt),
                          style: GoogleFonts.dmMono(
                            color: Colors.white24,
                            fontSize: 10,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── 6. Wishlist Peek ────────────────────────────────────────────────────────
  Widget _buildWishlistPeek(ThemeColors tc) {
    final wishlist = ref.watch(wishlistProvider).valueOrNull ?? [];
    final undoneList = wishlist.where((w) => !w.isDone && !w.isHidden).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'WISHLIST PEEK',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white54,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/us-space/wishlist'),
              child: Text(
                'See our list',
                style: GoogleFonts.dmSans(
                  color: AppColors.rose,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (undoneList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'No items in your wishlist yet 💕',
                      style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.normal),
                    ),
                  ),
                )
              else
                ...undoneList.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          item.type == WishlistModel.typeExperience ? Icons.local_activity_outlined : Icons.shopping_bag_outlined,
                          color: AppColors.rose,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ),
                        if (item.price != null)
                          Text(
                            '₹${item.price!.toInt()}',
                            style: GoogleFonts.dmMono(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ── 7. Finances Summary ────────────────────────────────────────────────────
  Widget _buildFinancesSummary(ThemeColors tc) {
    final expenseNotifier = ref.watch(expenseProvider.notifier);
    final totalSpentThisMonth = expenseNotifier.totalThisMonth;
    final totalOutstandingLoans = expenseNotifier.totalUnpaidLoans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'SHARED FINANCES',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white54,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/us-space/finance'),
              child: Text(
                'See finances',
                style: GoogleFonts.dmSans(
                  color: AppColors.rose,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Monthly spend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPENT THIS MONTH',
                      style: GoogleFonts.dmSans(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalSpentThisMonth.toInt()}',
                      style: GoogleFonts.dmMono(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              // Outstanding loans
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OUTSTANDING LOANS',
                      style: GoogleFonts.dmSans(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalOutstandingLoans.toInt()}',
                      style: GoogleFonts.dmMono(
                        color: AppColors.warning,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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

  // ── AI SURFACE: CYCLE COMFORT DETAILS ───────────────────────────────────────
  Widget _buildPeriodComfortSection(List<MemoryModel> partnerCareMemories, ThemeColors tc) {
    final comfortItems = partnerCareMemories.where((m) =>
      m.category == 'food' ||
      m.category == 'craving' ||
      m.category == 'habit' ||
      m.category == 'trigger' ||
      m.category == 'dislike'
    ).toList();

    if (comfortItems.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      blur: 10,
      tint: Colors.white,
      tintOpacity: 0.04,
      borderRadius: 16,
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Cycle Comfort Observations',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...comfortItems.take(3).map((m) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(MemoryModel.categoryEmoji(m.category), style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.content,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: ${m.category.toUpperCase()}',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: Colors.white30,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── AI SURFACE: FREE TIME PLAN DESTINATIONS ─────────────────────────────────
  Widget _buildFreeTimeDestinationsSection(List<MemoryModel> partnerCareMemories, ThemeColors tc) {
    final destinationItems = partnerCareMemories.where((m) =>
      m.category == 'place' ||
      m.category == 'dream'
    ).toList();

    if (destinationItems.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      blur: 10,
      tint: Colors.white,
      tintOpacity: 0.04,
      borderRadius: 16,
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Dream Places & Wishes Surfaced',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...destinationItems.take(3).map((m) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(m.category == 'place' ? '🗺️' : '✨', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.content,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
