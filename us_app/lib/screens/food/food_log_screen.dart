import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/food_log_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/bottom_nav.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class FoodLogScreen extends ConsumerStatefulWidget {
  const FoodLogScreen({super.key});

  @override
  ConsumerState<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends ConsumerState<FoodLogScreen> {
  bool _viewingPartner = false;

  @override
  Widget build(BuildContext context) {
    final tc          = ref.watch(themeProvider).colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final myName      = coupleState?.currentUser?.name.split(' ').first ?? 'Me';
    final partnerName = coupleState?.partner?.name.split(' ').first ?? 'Her';

    final foodAsync = ref.watch(foodProvider);
    final notifier  = ref.read(foodProvider.notifier);

    final viewedId = _viewingPartner
        ? coupleState?.partner?.id
        : coupleState?.currentUser?.id;

    final todayLogs = _viewingPartner
        ? notifier.todayPartnerLogs
        : notifier.todayMyLogs;

    final allLogs = foodAsync.valueOrNull ?? [];
    final viewedLogs = viewedId == null
        ? <FoodLogModel>[]
        : allLogs.where((l) => l.userId == viewedId).toList();

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: tc.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Food Log 🍱',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        actions: [
          _ViewToggle(
            viewingPartner: _viewingPartner,
            myLabel:       myName,
            partnerLabel:  partnerName,
            onChanged:     (v) => setState(() => _viewingPartner = v),
            tc:            tc,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: foodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            Center(child: Text('Failed to load food log', style: TextStyle(color: tc.textPrimary))),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // ── Today's meal grid ─────────────────────────────────────
            _MealGrid(
              todayLogs: todayLogs,
              tc:        tc,
              onTapMeal: (meal) =>
                  context.push('/food/add?meal=$meal'),
            ),
            const SizedBox(height: 20),

            // ── Recent logs ───────────────────────────────────────────
            if (viewedLogs.isEmpty)
              _EmptyState(
                partnerName:   partnerName,
                viewingPartner: _viewingPartner,
                tc:            tc,
              )
            else
              _RecentSection(logs: viewedLogs, tc: tc),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/food/add'),
        backgroundColor: tc.iconColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 0,
        onTap: (i) {
          const routes = ['/home', '/memory', '/finance', '/planner', '/ai-chat'];
          if (i < routes.length) context.go(routes[i]);
        },
      ),
    );
  }
}

// ── View toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.viewingPartner,
    required this.myLabel,
    required this.partnerLabel,
    required this.onChanged,
    required this.tc,
  });

  final bool        viewingPartner;
  final String      myLabel;
  final String      partnerLabel;
  final void Function(bool) onChanged;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            label: myLabel,
            active: !viewingPartner,
            onTap:  () => onChanged(false),
            tc:     tc,
          ),
          _Pill(
            label: partnerLabel,
            active: viewingPartner,
            onTap:  () => onChanged(true),
            tc:     tc,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    required this.tc,
  });

  final String      label;
  final bool        active;
  final VoidCallback onTap;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tc.iconColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : tc.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Meal grid ─────────────────────────────────────────────────────────────────

class _MealGrid extends StatelessWidget {
  const _MealGrid({
    required this.todayLogs,
    required this.tc,
    required this.onTapMeal,
  });

  final List<FoodLogModel> todayLogs;
  final ThemeColors        tc;
  final void Function(String meal) onTapMeal;

  static const _meals = [
    (type: FoodLogModel.mealBreakfast, emoji: '🌅', label: 'Breakfast'),
    (type: FoodLogModel.mealLunch,     emoji: '☀️', label: 'Lunch'),
    (type: FoodLogModel.mealDinner,    emoji: '🌙', label: 'Dinner'),
    (type: FoodLogModel.mealSnack,     emoji: '🍪', label: 'Snack'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: _meals.map((m) {
        final log = todayLogs.where((l) => l.mealType == m.type).firstOrNull;
        return _MealCard(
          emoji:   m.emoji,
          label:   m.label,
          log:     log,
          tc:      tc,
          onTap:   () => onTapMeal(m.type),
        );
      }).toList(),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.emoji,
    required this.label,
    required this.log,
    required this.tc,
    required this.onTap,
  });

  final String        emoji;
  final String        label;
  final FoodLogModel? log;
  final ThemeColors   tc;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    final logged = log != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: logged
              ? tc.iconColor.withValues(alpha: 0.08)
              : tc.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: logged
                ? tc.iconColor.withValues(alpha: 0.3)
                : tc.borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: logged
                        ? tc.iconColor
                        : tc.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
                if (log?.moodEmoji.isNotEmpty == true) ...[
                  const Spacer(),
                  Text(log!.moodEmoji,
                      style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            Text(
              logged ? log!.description : 'Not logged',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: logged ? tc.textPrimary.withValues(alpha: 0.8) : tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent logs section ───────────────────────────────────────────────────────

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.logs, required this.tc});
  final List<FoodLogModel> logs;
  final ThemeColors        tc;

  @override
  Widget build(BuildContext context) {
    // Group by date
    final groups = <String, List<FoodLogModel>>{};
    final today     = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    for (final log in logs) {
      final d = log.loggedAt;
      String key;
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        key = 'Today';
      } else if (d.year == yesterday.year &&
          d.month == yesterday.month &&
          d.day == yesterday.day) {
        key = 'Yesterday';
      } else {
        key = DateFormat('EEE, d MMM').format(d);
      }
      groups.putIfAbsent(key, () => []).add(log);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                entry.key,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tc.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map((log) => _LogTile(log: log, tc: tc)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({required this.log, required this.tc});
  final FoodLogModel log;
  final ThemeColors  tc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) {
        ref.read(foodProvider.notifier).deleteLog(log.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: _LogThumbnail(photoUrl: log.photoUrl, emoji: log.mealEmoji, tc: tc),
          title: Text(
            log.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tc.textPrimary,
            ),
          ),
          subtitle: Text(
            '${DateFormat('h:mm a').format(log.loggedAt)}'
            '${log.calories != null ? '  •  ${log.calories} kcal' : ''}'
            '${log.moodEmoji.isNotEmpty ? '  ${log.moodEmoji}' : ''}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: tc.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogThumbnail extends StatelessWidget {
  const _LogThumbnail({required this.photoUrl, required this.emoji, required this.tc});
  final String? photoUrl;
  final String  emoji;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback,
        ),
      );
    }
    return _fallback;
  }

  Widget get _fallback => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tc.iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tc.iconColor.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.partnerName,
    required this.viewingPartner,
    required this.tc,
  });

  final String      partnerName;
  final bool        viewingPartner;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍱', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              viewingPartner
                  ? "Log $partnerName's first meal of the day"
                  : 'Log your first meal of the day',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
