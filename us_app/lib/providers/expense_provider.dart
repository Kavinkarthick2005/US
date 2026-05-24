import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_model.dart';
import 'couple_provider.dart';

class ExpenseNotifier extends AsyncNotifier<List<ExpenseModel>> {
  final _sb = Supabase.instance.client;

  @override
  Future<List<ExpenseModel>> build() async {
    final coupleState = await ref.watch(coupleProvider.future);
    final coupleId = coupleState.coupleId;
    final myId = coupleState.currentUser?.id;
    if (myId == null) return [];
    
    if (coupleId != null) {
      return fetchExpenses(coupleId: coupleId);
    } else {
      return fetchExpenses(myId: myId);
    }
  }

  Future<List<ExpenseModel>> fetchExpenses({String? coupleId, String? myId}) async {
    try {
      final query = _sb.from('expenses').select();
      final data = await (coupleId != null 
          ? query.eq('couple_id', coupleId).order('spent_at', ascending: false)
          : query.eq('added_by', myId!).order('spent_at', ascending: false));
          
      return (data as List)
          .map((j) => ExpenseModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addExpense(ExpenseModel e) async {
    await _sb.from('expenses').insert(e.toJson());
    if (state.hasValue) {
      state = AsyncData([e, ...state.value!]);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> markLoanPaid(String id) async {
    await _sb.from('expenses').update({'is_paid': true}).eq('id', id);
    if (state.hasValue) {
      final updated = state.value!.map((e) {
        if (e.id == id) {
          return ExpenseModel(
            id: e.id,
            coupleId: e.coupleId,
            addedBy: e.addedBy,
            amount: e.amount,
            category: e.category,
            description: e.description,
            isLoan: e.isLoan,
            loanTo: e.loanTo,
            isPaid: true,
            spentAt: e.spentAt,
            createdAt: e.createdAt,
          );
        }
        return e;
      }).toList();
      state = AsyncData(updated);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> deleteExpense(String id) async {
    await _sb.from('expenses').delete().eq('id', id);
    if (state.hasValue) {
      state = AsyncData(state.value!.where((e) => e.id != id).toList());
    } else {
      ref.invalidateSelf();
    }
  }

  // ── Computed getters ────────────────────────────────────────────────────────

  double get totalThisMonth {
    final now = DateTime.now();
    return (state.valueOrNull ?? [])
        .where((e) =>
            !e.isLoan &&
            e.spentAt.year == now.year &&
            e.spentAt.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double get totalUnpaidLoans {
    return (state.valueOrNull ?? [])
        .where((e) => e.isLoan && !e.isPaid)
        .fold(0.0, (s, e) => s + e.amount);
  }

  Map<String, double> get expensesByCategory {
    final now = DateTime.now();
    final result = <String, double>{};
    for (final e in state.valueOrNull ?? []) {
      if (!e.isLoan &&
          e.spentAt.year == now.year &&
          e.spentAt.month == now.month) {
        result[e.category] = (result[e.category] ?? 0) + e.amount;
      }
    }
    return result;
  }

  // isLoan, addedBy=me, loanTo=partner → "You Owe Her"
  List<ExpenseModel> get myLoans {
    final c       = ref.read(coupleProvider).valueOrNull;
    final myId    = c?.currentUser?.id;
    final partner = c?.partner?.id;
    if (myId == null || partner == null) return [];
    return (state.valueOrNull ?? [])
        .where((e) =>
            e.isLoan && !e.isPaid && e.addedBy == myId && e.loanTo == partner)
        .toList();
  }

  // isLoan, loanTo=me → "She Owes You"
  List<ExpenseModel> get theirLoans {
    final myId = ref.read(coupleProvider).valueOrNull?.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? [])
        .where((e) => e.isLoan && !e.isPaid && e.loanTo == myId)
        .toList();
  }

  List<ExpenseModel> get recentExpenses =>
      (state.valueOrNull ?? []).where((e) => !e.isLoan).take(10).toList();
}

final expenseProvider =
    AsyncNotifierProvider<ExpenseNotifier, List<ExpenseModel>>(
        () => ExpenseNotifier());
