import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/period_model.dart';
import '../models/reminder_model.dart';
import 'couple_provider.dart';

class PeriodNotifier extends AsyncNotifier<PeriodCycleModel?> {
  final _sb = Supabase.instance.client;

  @override
  Future<PeriodCycleModel?> build() async {
    final coupleState = await ref.watch(coupleProvider.future);
    final myId = coupleState.currentUser?.id;
    final partnerId = coupleState.partner?.id;
    if (myId == null) return null;
    return _fetchLatestCycle(myId, partnerId);
  }

  Future<PeriodCycleModel?> _fetchLatestCycle(String myId, String? partnerId) async {
    try {
      var query = _sb.from('period_tracking').select();
      if (partnerId != null) {
        query = query.or('user_id.eq.$myId,user_id.eq.$partnerId');
      } else {
        query = query.eq('user_id', myId);
      }
      
      final data = await query
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return PeriodCycleModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> logPeriod(DateTime startDate, int cycleLength) async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = coupleState?.currentUser?.id;
    final partnerId = coupleState?.partner?.id;
    final targetId = partnerId ?? myId;
    if (myId == null || targetId == null) return;

    try {
      final inserted = await _sb.from('period_tracking').insert({
        'user_id': targetId,
        'start_date': startDate.toUtc().toIso8601String(),
        'cycle_length': cycleLength,
      }).select().single();

    final nextPeriod = startDate.add(Duration(days: cycleLength));
    final myRemind = nextPeriod.subtract(const Duration(days: 3));
    final herRemind = nextPeriod.subtract(const Duration(days: 1));

    await _sb.from('reminders').insert({
      'user_id': myId,
      'remind_to': myId,
      'title': 'Her period starts in 3 days 💕 Be extra kind',
      'remind_at': DateTime(myRemind.year, myRemind.month, myRemind.day, 9, 0)
          .toUtc()
          .toIso8601String(),
      'repeat_type': ReminderModel.repeatNone,
      'category': ReminderModel.catPeriod,
      'is_active': true,
    });

      if (partnerId != null) {
        await _sb.from('reminders').insert({
          'user_id': myId,
          'remind_to': partnerId,
          'title': 'Your period starts tomorrow 🌸',
          'remind_at': DateTime(herRemind.year, herRemind.month, herRemind.day, 8, 0)
              .toUtc()
              .toIso8601String(),
          'repeat_type': ReminderModel.repeatNone,
          'category': ReminderModel.catPeriod,
          'is_active': true,
        });
      }

      state = AsyncData(PeriodCycleModel.fromJson(inserted));
      ref.invalidateSelf();
    } catch (e) {
      print('Period log error: $e');
    }
  }

  Future<void> updateEndDate(String id, DateTime endDate) async {
    final updated = await _sb
        .from('period_tracking')
        .update({'end_date': endDate.toUtc().toIso8601String()})
        .eq('id', id).select().single();
    state = AsyncData(PeriodCycleModel.fromJson(updated));
  }

  // ── Computed getters ────────────────────────────────────────────────────────

  DateTime? get nextPeriodDate {
    final c = state.valueOrNull;
    if (c == null) return null;
    return c.startDate.add(Duration(days: c.cycleLength));
  }

  int? get daysUntilNext {
    final next = nextPeriodDate;
    if (next == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final nextDay = DateTime(next.year, next.month, next.day);
    return nextDay.difference(today).inDays;
  }

  bool get currentlyOnPeriod {
    final c = state.valueOrNull;
    if (c == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start = DateTime(c.startDate.year, c.startDate.month, c.startDate.day);
    return c.endDate == null && !start.isAfter(today);
  }
}

final periodProvider =
    AsyncNotifierProvider<PeriodNotifier, PeriodCycleModel?>(() => PeriodNotifier());

final periodHistoryProvider =
    FutureProvider.autoDispose<List<PeriodCycleModel>>((ref) async {
  final coupleState = await ref.watch(coupleProvider.future);
  final myId = coupleState.currentUser?.id;
  final partnerId = coupleState.partner?.id;
  final targetId = partnerId ?? myId;
  if (targetId == null) return [];

  try {
    final data = await Supabase.instance.client
        .from('period_tracking')
        .select()
        .eq('user_id', targetId)
        .order('start_date', ascending: false)
        .limit(12);
    return (data as List)
        .map((j) => PeriodCycleModel.fromJson(j as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});
