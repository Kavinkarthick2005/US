import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/reminder_model.dart';
import '../../models/timetable_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/pronoun_helper.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/rose_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/memory');
        break;
      case 2:
        context.go('/finance');
        break;
      case 3:
        context.go('/planner');
        break;
      case 4:
        context.go('/ai-chat');
        break;
    }
  }

  void _showAddReminderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddReminderSheet(),
    );
  }

  void _showAddSlotSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddSlotSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      bottomNavigationBar: BottomNav(
        currentIndex: 3,
        onTap: _onBottomNavTapped,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: tc.iconColor,
        onPressed: _tabController.index == 0
            ? _showAddReminderSheet
            : _showAddSlotSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        backgroundColor: tc.backgroundColor,
        elevation: 0,
        title: Text(
          'Planner',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: tc.iconColor,
          unselectedLabelColor: tc.textMuted,
          indicatorColor: tc.iconColor,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Reminders'),
            Tab(text: 'Timetable'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RemindersTab(),
          _TimetableTab(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Reminders Tab 
// ═════════════════════════════════════════════════════════════════════════════

class _RemindersTab extends ConsumerWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(remindersProvider);
    final tc = ref.watch(themeProvider).colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final pronoun = coupleState?.currentUser?.partnerPronoun ?? 'she';

    return state.when(
      data: (_) {
        final notifier = ref.read(remindersProvider.notifier);
        final todays = notifier.todaysReminders;
        final upcoming = notifier.upcomingReminders;
        final later = notifier.laterReminders;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // Cycle Tracker banner
            GestureDetector(
              onTap: () => context.go('/planner/period'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tc.iconColor, tc.iconColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('🩸', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cycle Tracker',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track ${PronounHelper.possessive(pronoun).toLowerCase()} cycle & set care reminders',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.8)),
                  ],
                ),
              ),
            ),
            if (todays.isNotEmpty) ...[
              _buildSectionHeader('Today', tc),
              ...todays.map((r) => _ReminderCard(reminder: r, tc: tc)),
              const SizedBox(height: 24),
            ],
            if (upcoming.isNotEmpty) ...[
              _buildSectionHeader('This Week', tc),
              ...upcoming.map((r) => _ReminderCard(reminder: r, tc: tc)),
              const SizedBox(height: 24),
            ],
            if (later.isNotEmpty || (todays.isEmpty && upcoming.isEmpty)) ...[
              _buildSectionHeader(
                  later.isNotEmpty ? 'Later / Repeating' : 'All Reminders', tc),
              if (later.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No reminders set yet.',
                      style: GoogleFonts.dmSans(color: tc.textMuted),
                    ),
                  ),
                ),
              ...later.map((r) => _ReminderCard(reminder: r, tc: tc)),
              const SizedBox(height: 80),
            ],
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: tc.iconColor)),
      error: (e, st) => Center(child: Text('Error: $e', style: TextStyle(color: tc.textPrimary))),
    );
  }

  Widget _buildSectionHeader(String title, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tc.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  final ReminderModel reminder;
  final ThemeColors tc;
  const _ReminderCard({required this.reminder, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: tc.cardColor,
            title: Text('Delete Reminder?',
                style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.bold, color: tc.textPrimary)),
            content: Text('Are you sure you want to remove this reminder?',
                style: GoogleFonts.dmSans(color: tc.textSecondary)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.dmSans(color: tc.textMuted)),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: tc.iconColor),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: GoogleFonts.dmSans(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: tc.iconColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: BorderRadius.circular(12),
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
            Text(reminder.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: tc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat.jm().format(reminder.remindAt)} • ${reminder.repeatType.toUpperCase()}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: tc.iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: reminder.isActive,
              activeThumbColor: tc.iconColor,
              activeTrackColor: tc.iconColor.withValues(alpha: 0.4),
              onChanged: (val) {
                ref
                    .read(remindersProvider.notifier)
                    .toggleReminder(reminder.id, val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final TextEditingController _titleCtrl = TextEditingController();

  String _selectedCategory = ReminderModel.catCustom;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _repeatType = ReminderModel.repeatNone;
  int _remindWho = 0;
  bool _isSaving = false;

  final _categories = [
    {'icon': '🩸', 'id': ReminderModel.catPeriod,    'label': 'Period'},
    {'icon': '🍽',  'id': ReminderModel.catFood,      'label': 'Food'},
    {'icon': '💊', 'id': ReminderModel.catMedicine,   'label': 'Medicine'},
    {'icon': '💕', 'id': ReminderModel.catDate,       'label': 'Date'},
    {'icon': '💧', 'id': ReminderModel.catHydration,  'label': 'Hydration'},
    {'icon': '✏️', 'id': ReminderModel.catCustom,     'label': 'Custom'},
  ];

  Future<void> _pickDate(ThemeColors tc) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: tc.iconColor,
            surface: tc.cardColor,
            onSurface: tc.textPrimary,
          ),
          dialogBackgroundColor: tc.backgroundColor,
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime(ThemeColors tc) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: tc.iconColor,
            surface: tc.cardColor,
            onSurface: tc.textPrimary,
          ),
          dialogBackgroundColor: tc.backgroundColor,
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  void _onSave() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final coupleState = ref.read(coupleProvider).valueOrNull;
      final myId        = coupleState?.currentUser?.id;
      final partnerId   = coupleState?.partner?.id;

      if (myId == null) throw Exception('Not authenticated');

      final remindAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final remindersNotifier = ref.read(remindersProvider.notifier);
      const uuid = Uuid();

      if (_remindWho == 0 || _remindWho == 2) {
        await remindersNotifier.addReminder(ReminderModel(
          id: uuid.v4(),
          userId: myId,
          remindTo: myId,
          title: _titleCtrl.text.trim(),
          remindAt: remindAt,
          repeatType: _repeatType,
          category: _selectedCategory,
          isActive: true,
          createdAt: DateTime.now(),
        ));
      }

      if ((_remindWho == 1 || _remindWho == 2) && partnerId != null) {
        await remindersNotifier.addReminder(ReminderModel(
          id: uuid.v4(),
          userId: myId,
          remindTo: partnerId,
          title: _titleCtrl.text.trim(),
          remindAt: remindAt,
          repeatType: _repeatType,
          category: _selectedCategory,
          isActive: true,
          createdAt: DateTime.now(),
        ));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reminder set!')));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
              'New Reminder',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'What to remind?',
                hintStyle: TextStyle(color: tc.textMuted),
                fillColor: tc.inputFillColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tc.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tc.borderColor),
                ),
              ),
              style: GoogleFonts.dmSans(
                  color: tc.textPrimary, fontWeight: FontWeight.w500),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final isSelected = _selectedCategory == c['id'];
                return ChoiceChip(
                  label: Text('${c['icon']} ${c['label']}'),
                  selected: isSelected,
                  selectedColor: tc.iconColor,
                  backgroundColor: tc.backgroundColor,
                  side: BorderSide(color: isSelected ? tc.iconColor : tc.borderColor),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : tc.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = c['id']!);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(tc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: tc.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat.MMMd().format(_selectedDate),
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: tc.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(tc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: tc.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _selectedTime.format(context),
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: tc.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _repeatType,
              decoration: InputDecoration(
                labelText: 'Repeat',
                labelStyle: TextStyle(color: tc.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tc.borderColor)),
              ),
              dropdownColor: tc.cardColor,
              style: TextStyle(color: tc.textPrimary),
              items: const [
                DropdownMenuItem(
                    value: ReminderModel.repeatNone,    child: Text('None')),
                DropdownMenuItem(
                    value: ReminderModel.repeatDaily,   child: Text('Daily')),
                DropdownMenuItem(
                    value: ReminderModel.repeatWeekly,  child: Text('Weekly')),
                DropdownMenuItem(
                    value: ReminderModel.repeatMonthly, child: Text('Monthly')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _repeatType = val);
              },
            ),
            const SizedBox(height: 24),
            Text('Remind Who?',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600, color: tc.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSegment(0, 'Me', tc),
                const SizedBox(width: 8),
                _buildSegment(1, 'Her', tc),
                const SizedBox(width: 8),
                _buildSegment(2, 'Both', tc),
              ],
            ),
            const SizedBox(height: 32),
            RoseButton(
              label: 'Set Reminder',
              isLoading: _isSaving,
              onTap: _titleCtrl.text.trim().isNotEmpty ? _onSave : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(int index, String label, ThemeColors tc) {
    final isSelected = _remindWho == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _remindWho = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? tc.iconColor : tc.backgroundColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: isSelected ? tc.iconColor : tc.borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : tc.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Timetable Tab
// ═════════════════════════════════════════════════════════════════════════════

class _TimetableTab extends ConsumerStatefulWidget {
  const _TimetableTab();

  @override
  ConsumerState<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends ConsumerState<_TimetableTab> {
  late int _selectedDay;

  static const _kDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    // DateTime.weekday: 1=Mon…7=Sun → model: 0=Mon…6=Sun
    _selectedDay = DateTime.now().weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final tc          = ref.watch(themeProvider).colors;
    final ttAsync     = ref.watch(timetableProvider);
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id ?? '';
    final partnerId   = coupleState?.partner?.id     ?? '';

    return ttAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: tc.iconColor)),
      error: (_, __) =>
          Center(child: Text('Failed to load timetable', style: TextStyle(color: tc.textPrimary))),
      data: (_) {
        final notifier     = ref.read(timetableProvider.notifier);
        final mySlots      = notifier.getSlotsForDay(_selectedDay, myId);
        final partnerSlots = notifier.getSlotsForDay(_selectedDay, partnerId);
        final overlaps     = notifier.getFreeOverlapForDay(_selectedDay);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _DaySelector(
              selected:  _selectedDay,
              onChanged: (d) => setState(() => _selectedDay = d),
              tc:        tc,
            ),
            const SizedBox(height: 12),
            _FreeOverlapBanner(
              overlaps: overlaps,
              dayName:  _kDays[_selectedDay],
              tc:       tc,
            ),
            const SizedBox(height: 16),
            _DualScheduleView(
              mySlots:          mySlots,
              partnerSlots:     partnerSlots,
              myAvatarUrl:      coupleState?.currentUser?.avatarUrl,
              partnerName:      coupleState?.partner?.name.split(' ').first ?? 'Her',
              partnerAvatarUrl: coupleState?.partner?.avatarUrl,
              tc:               tc,
            ),
          ],
        );
      },
    );
  }
}

// ── Day selector ──────────────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selected,
    required this.onChanged,
    required this.tc,
  });

  final int      selected;
  final void Function(int) onChanged;
  final ThemeColors tc;

  static const _kDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? tc.iconColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? tc.iconColor
                      : tc.borderColor,
                ),
              ),
              child: Text(
                _kDays[i],
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? Colors.white
                      : tc.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Free overlap banner ───────────────────────────────────────────────────────

class _FreeOverlapBanner extends StatelessWidget {
  const _FreeOverlapBanner({
    required this.overlaps,
    required this.dayName,
    required this.tc,
  });

  final List<String> overlaps;
  final String       dayName;
  final ThemeColors  tc;

  static const _kGreen     = Color(0xFF4CAF50);
  static const _kGreenDark = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    if (overlaps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No shared free time on $dayName',
          style: GoogleFonts.dmSans(fontSize: 13, color: tc.textMuted),
        ),
      );
    }

    final timeText = overlaps.join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('💕', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're both free $timeText",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kGreenDark, // Need dark green for visibility on lighter themes maybe
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'ai_chat_prefill',
                "We're both free $timeText on $dayName. Suggest something romantic we can do together! 💕",
              );
              if (context.mounted) context.go('/ai-chat');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tc.iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Plan something?',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dual schedule view ────────────────────────────────────────────────────────

class _DualScheduleView extends StatelessWidget {
  const _DualScheduleView({
    required this.mySlots,
    required this.partnerSlots,
    required this.myAvatarUrl,
    required this.partnerName,
    required this.partnerAvatarUrl,
    required this.tc,
  });

  final List<TimetableModel> mySlots;
  final List<TimetableModel> partnerSlots;
  final String?              myAvatarUrl;
  final String               partnerName;
  final String?              partnerAvatarUrl;
  final ThemeColors          tc;

  static const _kStartHour = 6;
  static const _kEndHour   = 23;
  static const _kHourPx    = 50.0;
  static const _kTotalHours = _kEndHour - _kStartHour; // 17
  static const _kTotal      = _kTotalHours * _kHourPx;  // 850

  static String _hourLabel(int h) {
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    final myPartnerFree =
        partnerSlots.where((s) => s.isFree).toList();
    final partnerMyFree =
        mySlots.where((s) => s.isFree).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column headers
        Row(
          children: [
            const SizedBox(width: 52),
            Expanded(
              child: _ColHeader(
                label:     'Me',
                avatarUrl: myAvatarUrl,
                tc:        tc,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ColHeader(
                label:     partnerName,
                avatarUrl: partnerAvatarUrl,
                tc:        tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Timeline + columns
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour labels
            SizedBox(
              width: 44,
              height: _kTotal,
              child: Stack(
                children: List.generate(_kTotalHours + 1, (i) {
                  return Positioned(
                    top: i * _kHourPx - 7,
                    child: Text(
                      _hourLabel(_kStartHour + i),
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: tc.textMuted,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 4),

            // My column
            Expanded(
              child: _ScheduleCol(
                slots:          mySlots,
                overlappingWith: myPartnerFree,
                tc:             tc,
                isMine:         true,
              ),
            ),
            const SizedBox(width: 6),

            // Partner column
            Expanded(
              child: _ScheduleCol(
                slots:          partnerSlots,
                overlappingWith: partnerMyFree,
                tc:             tc,
                isMine:         false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader({
    required this.label,
    required this.avatarUrl,
    required this.tc,
  });

  final String  label;
  final String? avatarUrl;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TtAvatar(url: avatarUrl, size: 22, tc: tc),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TtAvatar extends StatelessWidget {
  const _TtAvatar({required this.url, required this.size, required this.tc});
  final String? url;
  final double  size;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback,
        ),
      );
    }
    return _fallback;
  }

  Widget get _fallback => Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color: tc.iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('💕', style: TextStyle(fontSize: 10)),
        ),
      );
}

class _ScheduleCol extends ConsumerWidget {
  const _ScheduleCol({
    required this.slots,
    required this.overlappingWith,
    required this.tc,
    required this.isMine,
  });

  final List<TimetableModel> slots;
  final List<TimetableModel> overlappingWith;
  final ThemeColors          tc;
  final bool                 isMine;

  static const _kStartHour = 6;
  static const _kHourPx    = 50.0;
  static const _kTotal     = 17 * _kHourPx;

  double _top(TimetableModel s) =>
      ((s.startHour - _kStartHour) * 60 + s.startMin) / 60 * _kHourPx;

  double _height(TimetableModel s) {
    final mins =
        (s.endHour - s.startHour) * 60 + s.endMin - s.startMin;
    return (mins / 60 * _kHourPx).clamp(20.0, double.infinity);
  }

  bool _hasOverlap(TimetableModel slot) {
    if (!slot.isFree) return false;
    final sS = slot.startHour * 60 + slot.startMin;
    final sE = slot.endHour   * 60 + slot.endMin;
    for (final p in overlappingWith) {
      final pS = p.startHour * 60 + p.startMin;
      final pE = p.endHour   * 60 + p.endMin;
      if (sE > pS && sS < pE) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: _kTotal,
      child: Stack(
        children: [
          // Hour grid lines
          ...List.generate(17, (i) => Positioned(
                top:   i * _kHourPx,
                left:  0,
                right: 0,
                child: Container(
                  height: 1,
                  color: tc.borderColor,
                ),
              )),

          // Slots
          ...slots.map((slot) => Positioned(
                top:    _top(slot),
                left:   2,
                right:  2,
                height: _height(slot),
                child:  _SlotBlock(
                  slot:       slot,
                  hasOverlap: _hasOverlap(slot),
                  tc:         tc,
                  isMine:     isMine,
                ),
              )),
        ],
      ),
    );
  }
}

class _SlotBlock extends ConsumerWidget {
  const _SlotBlock({
    required this.slot,
    required this.hasOverlap,
    required this.tc,
    required this.isMine,
  });

  final TimetableModel slot;
  final bool           hasOverlap;
  final ThemeColors    tc;
  final bool           isMine;

  static const _kGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<BoxShadow> shadows = hasOverlap
        ? [
            BoxShadow(
              color:       _kGreen.withValues(alpha: 0.5),
              blurRadius:  10,
              spreadRadius: 1,
            )
          ]
        : [];

    return GestureDetector(
      onLongPress: isMine
          ? () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: tc.cardColor,
                  title: Text('Delete Slot?', style: GoogleFonts.dmSans(color: tc.textPrimary, fontWeight: FontWeight.w600)),
                  content: Text('Remove this time slot from your timetable?', style: GoogleFonts.dmSans(color: tc.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(timetableProvider.notifier).deleteSlot(slot.id);
                        Navigator.pop(ctx);
                      },
                      child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: slot.isFree
              ? _kGreen.withValues(alpha: 0.18)
              : null,
          gradient: slot.isFree
              ? null
              : LinearGradient(
                  colors: isMine
                      ? [tc.iconColor, tc.iconColor.withValues(alpha: 0.7)]
                      : [tc.iconColor.withValues(alpha: 0.7),
                          tc.iconColor.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(6),
          border: slot.isFree
              ? Border.all(
                  color: _kGreen.withValues(alpha: 0.4))
              : null,
          boxShadow: shadows,
        ),
        padding: const EdgeInsets.all(4),
        child: Text(
          slot.isFree ? 'Free' : slot.label,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                slot.isFree ? const Color(0xFF1B5E20) : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Add slot bottom sheet ────────────────────────────────────────────────────

class _AddSlotSheet extends ConsumerStatefulWidget {
  const _AddSlotSheet();

  @override
  ConsumerState<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends ConsumerState<_AddSlotSheet> {
  bool      _forPartner = false;
  int?      _selectedDay;
  TimeOfDay _startTime  = const TimeOfDay(hour: 9,  minute: 0);
  TimeOfDay _endTime    = const TimeOfDay(hour: 10, minute: 0);
  String    _preset     = '';
  final     _customCtrl = TextEditingController();
  bool      _isFree     = false;
  bool      _isSaving   = false;

  static const _kPresets = [
    'College 📚', 'Work 💼', 'Gym 🏋️',
    'Class 📖', 'Lunch 🍽', 'Sleep 💤', 'Free 🌿',
  ];
  static const _kDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart, required ThemeColors tc}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary:   tc.iconColor,
            onPrimary: Colors.white,
            surface:   tc.cardColor,
            onSurface: tc.textPrimary,
          ),
          dialogBackgroundColor: tc.backgroundColor,
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String get _effectiveLabel =>
      _customCtrl.text.trim().isNotEmpty
          ? _customCtrl.text.trim()
          : _preset;

  Future<void> _submit(ThemeColors tc) async {
    if (_selectedDay == null || _effectiveLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select a day and label',
              style: GoogleFonts.dmSans()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final couple    = ref.read(coupleProvider).valueOrNull;
    final myId      = couple?.currentUser?.id;
    final partnerId = couple?.partner?.id;
    final userId    = _forPartner ? partnerId : myId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(timetableProvider.notifier).addSlot(TimetableModel(
        id:        const Uuid().v4(),
        userId:    userId,
        dayOfWeek: _selectedDay!,
        startHour: _startTime.hour,
        startMin:  _startTime.minute,
        endHour:   _endTime.hour,
        endMin:    _endTime.minute,
        label:     _effectiveLabel,
        isFree:    _isFree,
      ));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Slot added 💕',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
          backgroundColor: tc.iconColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc          = ref.watch(themeProvider).colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final partnerName =
        coupleState?.partner?.name.split(' ').first ?? 'Her';

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left:   20,
        right:  20,
        top:    16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: tc.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Schedule Slot',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Who
            if (coupleState?.partner != null) ...[
              Row(
                children: [
                  _SheetSeg(
                    label:  'My schedule',
                    active: !_forPartner,
                    tc:     tc,
                    onTap:  () => setState(() => _forPartner = false),
                  ),
                  const SizedBox(width: 8),
                  _SheetSeg(
                    label:  "$partnerName's",
                    active: _forPartner,
                    tc:     tc,
                    onTap:  () => setState(() => _forPartner = true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Text('Day',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tc.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (i) {
                final active = _selectedDay == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? tc.iconColor : tc.backgroundColor,
                      border: Border.all(color: active ? tc.iconColor : tc.borderColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _kDays[i],
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: active ? Colors.white : tc.textSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Time row
            Row(
              children: [
                Expanded(
                  child: _TimePickerBtn(
                    label: 'Start',
                    time:  _startTime,
                    tc:    tc,
                    onTap: () => _pickTime(isStart: true, tc: tc),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerBtn(
                    label: 'End',
                    time:  _endTime,
                    tc:    tc,
                    onTap: () => _pickTime(isStart: false, tc: tc),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Label',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tc.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kPresets.map((p) {
                final active = _preset == p &&
                    _customCtrl.text.trim().isEmpty;
                return GestureDetector(
                  onTap: () => setState(() {
                    _preset = p;
                    _customCtrl.clear();
                    if (p == 'Free 🌿') _isFree = true;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? tc.iconColor.withValues(alpha: 0.15)
                          : tc.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active
                            ? tc.iconColor
                            : tc.borderColor,
                      ),
                    ),
                    child: Text(
                      p,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: active ? tc.iconColor : tc.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customCtrl,
              onChanged:  (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Or type a custom label…',
                hintStyle: GoogleFonts.dmSans(
                    color: tc.textMuted, fontSize: 13),
                fillColor: tc.inputFillColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: tc.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: tc.borderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: tc.textPrimary),
            ),
            const SizedBox(height: 16),

            // isFree toggle
            Row(
              children: [
                const Text('🌿', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mark as Free Time',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _isFree,
                  activeThumbColor:
                      const Color(0xFF4CAF50),
                  activeTrackColor:
                      const Color(0xFF4CAF50).withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _isFree = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            RoseButton(
              label:     'Add',
              isLoading: _isSaving,
              onTap:     _isSaving ? null : () => _submit(tc),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSeg extends StatelessWidget {
  const _SheetSeg({
    required this.label,
    required this.active,
    required this.tc,
    required this.onTap,
  });

  final String   label;
  final bool     active;
  final ThemeColors tc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? tc.iconColor : tc.backgroundColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: active ? tc.iconColor : tc.borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.w500,
              color: active ? Colors.white : tc.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerBtn extends StatelessWidget {
  const _TimePickerBtn({
    required this.label,
    required this.time,
    required this.tc,
    required this.onTap,
  });

  final String       label;
  final TimeOfDay    time;
  final ThemeColors  tc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: tc.borderColor),
          borderRadius: BorderRadius.circular(12),
          color: tc.backgroundColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: tc.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              time.format(context),
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
