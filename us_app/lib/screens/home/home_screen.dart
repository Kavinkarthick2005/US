import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/couple_avatar.dart';
import '../../widgets/glass_card.dart';

// ── Providers for Dashboard Data ──────────────────────────────────────────────

final _recentMemoriesProvider = FutureProvider.autoDispose((ref) async {
  final supabase = Supabase.instance.client;
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return [];

  try {
    final data = await supabase
        .from('memories')
        .select()
        .order('created_at', ascending: false)
        .limit(3);
    return data as List<dynamic>;
  } catch (e) {
    return [];
  }
});

final _dashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final supabase = Supabase.instance.client;
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return {'memories': 0, 'expenses': 0};

  try {
    final memoriesData =
        await supabase.from('memories').select('id').count(CountOption.exact);

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final expensesData = await supabase
        .from('expenses')
        .select('amount')
        .gte('spent_at', firstDayOfMonth);

    double totalExpenses = 0;
    for (var row in expensesData as List) {
      totalExpenses += (row['amount'] as num).toDouble();
    }

    return {
      'memories': memoriesData.count,
      'expenses': totalExpenses.toInt(),
    };
  } catch (e) {
    return {'memories': 0, 'expenses': 0};
  }
});

// ── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _daysTogether = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadDaysTogether();
  }

  Future<void> _loadDaysTogether() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('couple_start_date');
      if (savedDate != null) {
        final start = DateTime.parse(savedDate);
        final diff = DateTime.now().difference(start).inDays;
        setState(() {
          _daysTogether = diff >= 0 ? diff : 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _onBottomNavTapped(int index) {
    switch (index) {
      case 0: context.go('/home');     break;
      case 1: context.go('/memory');   break;
      case 2: context.go('/finance');  break;
      case 3: context.go('/planner'); break;
      case 4: context.go('/ai-chat'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser  = ref.watch(currentUserProvider);
    final coupleState  = ref.watch(coupleProvider);
    final partner      = coupleState.valueOrNull?.partner;
    final themeState   = ref.watch(themeProvider);
    final tc           = themeState.colors;
    final wallpaperPath = themeState.wallpaperPath;

    final firstName =
        currentUser?.userMetadata?['name']?.toString().split(' ').first ??
            'Love';

    final mainScrollView = CustomScrollView(
      slivers: [
        // ── SLIVER 1: CUSTOM HEADER ─────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          expandedHeight: 110,
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: false,
          title: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_getGreeting()}, $firstName',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Us',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/settings'),
                      child: CoupleAvatar(
                        myAvatarUrl:      currentUser?.userMetadata?['avatar_url'],
                        partnerAvatarUrl: partner?.avatarUrl,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () => context.go('/settings'),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.rose, AppColors.mauve],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),
          ),
        ),

        // ── SLIVER 2: CONTENT ─────────────────────────────────────────────
        SliverPadding(
          padding:
              const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildPartnerCard(partner, tc),
              const SizedBox(height: 32),
              _buildSectionTitle('Today', tc),
              const SizedBox(height: 12),
              _buildTodaysReminders(tc),
              const SizedBox(height: 32),
              _buildQuickActions(context, tc),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Memories', tc),
                  TextButton(
                    onPressed: () => context.go('/memory'),
                    style: TextButton.styleFrom(
                      foregroundColor: tc.iconColor,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See all',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tc.iconColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRecentMemories(tc),
              const SizedBox(height: 32),
              _buildStatsRow(tc),
            ]),
          ),
        ),
      ],
    );

    final scaffoldBody = wallpaperPath != null
        ? Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  File(wallpaperPath),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              ),
              mainScrollView,
            ],
          )
        : mainScrollView;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      bottomNavigationBar: BottomNav(
        currentIndex: 0,
        onTap: _onBottomNavTapped,
      ),
      body: scaffoldBody,
    );
  }

  // ── WIDGET BUILDERS ────────────────────────────────────────────────────────

  Widget _buildPartnerCard(dynamic partner, ThemeColors tc) {
    if (partner == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: tc.cardColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.rose.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: tc.borderColor,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/link-partner'),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tc.iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_rounded,
                        color: tc.iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap to link with her 💕',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tc.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share notes, count days, and log memories!',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: tc.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: tc.iconColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final partnerName   = partner?.name?.split(' ').first ?? 'Partner';
    final partnerAvatar = partner?.avatarUrl;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                AppColors.rose.withValues(alpha: _pulseAnimation.value),
                AppColors.mauve.withValues(alpha: _pulseAnimation.value),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.rose
                    .withValues(alpha: _pulseAnimation.value * 0.4),
                blurRadius: _pulseAnimation.value * 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: child,
        );
      },
      child: GlassCard(
        borderRadius: 22,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rose, width: 2),
                image: partnerAvatar != null && partnerAvatar.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(partnerAvatar),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppColors.blush,
              ),
              child: partnerAvatar == null || partnerAvatar.isEmpty
                  ? const Icon(Icons.person, color: AppColors.rose, size: 32)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_daysTogether days together',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No mood logged today',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: tc.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _memoryEmoji(String? category) {
    switch (category) {
      case 'food':    return '🍕';
      case 'place':   return '📍';
      case 'habit':   return '😊';
      case 'dislike': return '👎';
      case 'joke':    return '😂';
      case 'recipe':  return '🍳';
      case 'mood':    return '🎭';
      default:        return '💭';
    }
  }

  Widget _buildSectionTitle(String title, ThemeColors tc) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: tc.textPrimary,
      ),
    );
  }

  Widget _buildTodaysReminders(ThemeColors tc) {
    final remindersState = ref.watch(remindersProvider);

    return remindersState.when(
      data: (list) {
        final now = DateTime.now();
        final todays = list.where((r) {
          return r.remindAt.year  == now.year &&
              r.remindAt.month == now.month &&
              r.remindAt.day   == now.day;
        }).toList();

        if (todays.isEmpty) {
          return Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: tc.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.borderColor),
            ),
            alignment: Alignment.center,
            child: Text(
              'Nothing today 💕',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: tc.textMuted,
              ),
            ),
          );
        }

        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: todays.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final r = todays[index];
              return Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tc.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tc.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(r.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.jm().format(r.remindAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Text('Error: $e'),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeColors tc) {
    final actions = [
      {'icon': Icons.psychology_rounded,              'label': 'Add Memory 🧠',    'route': '/memory/add'},
      {'icon': Icons.restaurant_rounded,             'label': 'Log Food 🍛',      'route': '/food/add'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Add Expense 💸',   'route': '/finance/add'},
      {'icon': Icons.shopping_bag_outlined,          'label': 'Wishlist 🛍️',      'route': '/wishlist'},
      {'icon': Icons.auto_awesome_rounded,           'label': 'Ask AI ✨',         'route': '/ai-chat'},
      {'icon': Icons.water_drop_rounded,             'label': 'Cycle Tracker 🌸', 'route': '/planner/period'},
      {'icon': Icons.note_alt_rounded,               'label': 'Notes 📝',         'route': '/notes'},
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:  2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: () => context.go(action['route'] as String),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: tc.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action['icon'] as IconData,
                    color: tc.iconColor, size: 24),
                const SizedBox(height: 8),
                Text(
                  action['label'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tc.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentMemories(ThemeColors tc) {
    final memoriesState = ref.watch(_recentMemoriesProvider);

    return memoriesState.when(
      data: (memories) {
        if (memories.isEmpty) {
          return Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: tc.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.borderColor),
            ),
            alignment: Alignment.center,
            child: Text(
              'Add your first memory about her 💕',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: tc.textMuted,
              ),
            ),
          );
        }

        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: memories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final m = memories[index];
              return Container(
                width: 160,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tc.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tc.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _memoryEmoji(m['category'] as String?),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        m['content'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: tc.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m['created_at'] != null
                          ? DateFormat.yMMMd()
                              .format(DateTime.parse(m['created_at']).toLocal())
                          : '',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: tc.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Text('Error loading memories: $e'),
    );
  }

  Widget _buildStatsRow(ThemeColors tc) {
    final statsState = ref.watch(_dashboardStatsProvider);

    return statsState.when(
      data: (stats) {
        return Row(
          children: [
            _buildStatCard('$_daysTogether', 'Days Together', tc),
            const SizedBox(width: 12),
            _buildStatCard('${stats['memories']}', 'Memories Saved', tc),
            const SizedBox(width: 12),
            _buildStatCard('₹${stats['expenses']}', 'This Month', tc),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, st) => Text('Error loading stats: $e'),
    );
  }

  Widget _buildStatCard(String value, String label, ThemeColors tc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: tc.iconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
