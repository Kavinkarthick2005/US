import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'couple_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Recap Data Model
// ─────────────────────────────────────────────────────────────────────────────

class MonthlyRecapData {
  final int memoriesAdded;
  final int dropsPosted;
  final double totalExpenses;
  final int daysInMonth;
  final int daysTogether;
  final String topMemoryCategory;
  final Map<String, double> expenseByCategory;
  final int remindersSet;
  final int notesWritten;
  final int wishlistItems;
  final String partnerName;
  final String monthLabel;

  MonthlyRecapData({
    required this.memoriesAdded,
    required this.dropsPosted,
    required this.totalExpenses,
    required this.daysInMonth,
    required this.daysTogether,
    required this.topMemoryCategory,
    required this.expenseByCategory,
    required this.remindersSet,
    required this.notesWritten,
    required this.wishlistItems,
    required this.partnerName,
    required this.monthLabel,
  });

  static MonthlyRecapData empty(String partnerName, String monthLabel) {
    return MonthlyRecapData(
      memoriesAdded:      0,
      dropsPosted:        0,
      totalExpenses:      0,
      daysInMonth:        30,
      daysTogether:       0,
      topMemoryCategory:  'general',
      expenseByCategory:  {},
      remindersSet:       0,
      notesWritten:       0,
      wishlistItems:      0,
      partnerName:        partnerName,
      monthLabel:         monthLabel,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider — takes a DateTime to specify which month to recap
// ─────────────────────────────────────────────────────────────────────────────

final monthlyRecapProvider =
    FutureProvider.autoDispose.family<MonthlyRecapData, DateTime>(
        (ref, month) async {
  final coupleState = await ref.watch(coupleProvider.future);
  final myId        = coupleState.currentUser?.id;
  final partnerId   = coupleState.partner?.id;
  final coupleId    = coupleState.coupleId ?? myId;
  final partnerName = coupleState.partner?.name?.split(' ').first ?? 'your love';

  if (myId == null) {
    return MonthlyRecapData.empty(
        partnerName, _monthLabel(month));
  }

  final sb        = Supabase.instance.client;
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd   = DateTime(month.year, month.month + 1, 1);
  final startStr   = monthStart.toUtc().toIso8601String();
  final endStr     = monthEnd.toUtc().toIso8601String();

  int memoriesAdded     = 0;
  int dropsPosted       = 0;
  double totalExpenses  = 0;
  int remindersSet      = 0;
  int notesWritten      = 0;
  int wishlistItems     = 0;
  final catCount        = <String, int>{};
  final expenseCat      = <String, double>{};

  // Memories this month
  try {
    var q = sb.from('memories').select('category');
    if (partnerId != null) {
      q = q.or('owner_id.eq.$myId,owner_id.eq.$partnerId');
    } else {
      q = q.eq('owner_id', myId);
    }
    final rows = await q
        .gte('created_at', startStr)
        .lt('created_at', endStr);
    memoriesAdded = (rows as List).length;
    for (final r in rows) {
      final cat = r['category'] as String? ?? 'general';
      catCount[cat] = (catCount[cat] ?? 0) + 1;
    }
  } catch (_) {}

  // Drops this month
  if (coupleId != null) {
    try {
      final rows = await sb
          .from('drops')
          .select('id')
          .eq('couple_id', coupleId)
          .gte('created_at', startStr)
          .lt('created_at', endStr);
      dropsPosted = (rows as List).length;
    } catch (_) {}
  }

  // Expenses this month
  try {
    final rows = await sb
        .from('expenses')
        .select('amount,category')
        .eq('added_by', myId)
        .gte('spent_at', startStr)
        .lt('spent_at', endStr);
    for (final r in rows as List) {
      final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
      final cat = r['category'] as String? ?? 'other';
      totalExpenses  += amt;
      expenseCat[cat] = (expenseCat[cat] ?? 0.0) + amt;
    }
  } catch (_) {}

  // Reminders set this month
  try {
    final rows = await sb
        .from('reminders')
        .select('id')
        .eq('user_id', myId)
        .gte('created_at', startStr)
        .lt('created_at', endStr);
    remindersSet = (rows as List).length;
  } catch (_) {}

  // Notes written this month
  try {
    final rows = await sb
        .from('notes')
        .select('id')
        .eq('user_id', myId)
        .gte('created_at', startStr)
        .lt('created_at', endStr);
    notesWritten = (rows as List).length;
  } catch (_) {}

  // Wishlist items added this month
  try {
    final rows = await sb
        .from('wishlist')
        .select('id')
        .eq('added_by', myId)
        .gte('created_at', startStr)
        .lt('created_at', endStr);
    wishlistItems = (rows as List).length;
  } catch (_) {}

  final topCat = catCount.isEmpty
      ? 'general'
      : (catCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  final daysInMonth = monthEnd.difference(monthStart).inDays;

  return MonthlyRecapData(
    memoriesAdded:     memoriesAdded,
    dropsPosted:       dropsPosted,
    totalExpenses:     totalExpenses,
    daysInMonth:       daysInMonth,
    daysTogether:      0,
    topMemoryCategory: topCat,
    expenseByCategory: expenseCat,
    remindersSet:      remindersSet,
    notesWritten:      notesWritten,
    wishlistItems:     wishlistItems,
    partnerName:       partnerName,
    monthLabel:        _monthLabel(month),
  );
});

String _monthLabel(DateTime dt) {
  const months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[dt.month]} ${dt.year}';
}

/// Dashboard stats for the Us Space header.
final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final sb   = Supabase.instance.client;
  final myId = sb.auth.currentUser?.id;
  if (myId == null) return {'memories': 0, 'expenses': 0, 'drops': 0};

  try {
    final memoriesData = await sb
        .from('memories')
        .select('id')
        .count(CountOption.exact);

    final now          = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    final expensesData = await sb
        .from('expenses')
        .select('amount')
        .gte('spent_at', firstOfMonth);

    double totalExpenses = 0;
    for (final row in expensesData as List) {
      totalExpenses += (row['amount'] as num).toDouble();
    }

    int dropsCount = 0;
    try {
      final dropsData = await sb
          .from('drops')
          .select('id')
          .count(CountOption.exact);
      dropsCount = dropsData.count;
    } catch (_) {}

    return {
      'memories': memoriesData.count,
      'expenses': totalExpenses.toInt(),
      'drops':    dropsCount,
    };
  } catch (e) {
    return {'memories': 0, 'expenses': 0, 'drops': 0};
  }
});
