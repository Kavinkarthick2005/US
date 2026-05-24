import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/timetable_model.dart';
import 'couple_provider.dart';

class TimetableState {
  final List<TimetableModel> mySlots;
  final List<TimetableModel> partnerSlots;

  const TimetableState({
    required this.mySlots,
    required this.partnerSlots,
  });
}

class TimetableNotifier extends AsyncNotifier<TimetableState> {
  final _sb = Supabase.instance.client;

  @override
  Future<TimetableState> build() async {
    final couple    = await ref.watch(coupleProvider.future);
    final myId      = couple.currentUser?.id;
    final partnerId = couple.partner?.id;
    if (myId == null) {
      return const TimetableState(mySlots: [], partnerSlots: []);
    }
    return _fetchBoth(myId, partnerId);
  }

  Future<TimetableState> _fetchBoth(
      String myId, String? partnerId) async {
    try {
      final ids  = [myId, if (partnerId != null) partnerId];
      final data = await _sb
          .from('timetable')
          .select()
          .inFilter('user_id', ids);
      final all = (data as List)
          .map((j) => TimetableModel.fromJson(j as Map<String, dynamic>))
          .toList();
      return TimetableState(
        mySlots:      all.where((s) => s.userId == myId).toList(),
        partnerSlots: partnerId == null
            ? []
            : all.where((s) => s.userId == partnerId).toList(),
      );
    } catch (_) {
      return const TimetableState(mySlots: [], partnerSlots: []);
    }
  }

  Future<void> addSlot(TimetableModel slot) async {
    await _sb.from('timetable').insert(slot.toJson());
    if (state.hasValue) {
      final current = state.value!;
      final myId = _sb.auth.currentUser?.id;
      if (slot.userId == myId) {
        state = AsyncData(TimetableState(
          mySlots: [slot, ...current.mySlots],
          partnerSlots: current.partnerSlots,
        ));
      } else {
        state = AsyncData(TimetableState(
          mySlots: current.mySlots,
          partnerSlots: [slot, ...current.partnerSlots],
        ));
      }
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> deleteSlot(String id) async {
    await _sb.from('timetable').delete().eq('id', id);
    ref.invalidateSelf();
  }

  List<TimetableModel> getSlotsForDay(int day, String userId) {
    final all = <TimetableModel>[
      ...(state.valueOrNull?.mySlots      ?? []),
      ...(state.valueOrNull?.partnerSlots ?? []),
    ];
    return all.where((s) => s.dayOfWeek == day && s.userId == userId).toList();
  }

  List<String> getFreeOverlapForDay(int day) {
    final couple    = ref.read(coupleProvider).valueOrNull;
    final myId      = couple?.currentUser?.id;
    final partnerId = couple?.partner?.id;
    if (myId == null || partnerId == null) return [];

    final myFree = (state.valueOrNull?.mySlots ?? [])
        .where((s) => s.dayOfWeek == day && s.isFree)
        .toList();
    final partnerFree = (state.valueOrNull?.partnerSlots ?? [])
        .where((s) => s.dayOfWeek == day && s.isFree)
        .toList();

    final overlaps = <String>[];
    for (final m in myFree) {
      final mS = m.startHour * 60 + m.startMin;
      final mE = m.endHour   * 60 + m.endMin;
      for (final p in partnerFree) {
        final pS = p.startHour * 60 + p.startMin;
        final pE = p.endHour   * 60 + p.endMin;
        final oS = mS > pS ? mS : pS;
        final oE = mE < pE ? mE : pE;
        if (oE > oS) {
          overlaps.add('${_fmt(oS)} – ${_fmt(oE)}');
        }
      }
    }
    return overlaps;
  }

  static String _fmt(int minutes) {
    final h    = minutes ~/ 60;
    final m    = minutes % 60;
    final ampm = h < 12 ? 'AM' : 'PM';
    final hh   = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return m == 0
        ? '$hh $ampm'
        : '$hh:${m.toString().padLeft(2, '0')} $ampm';
  }
}

final timetableProvider =
    AsyncNotifierProvider<TimetableNotifier, TimetableState>(
        () => TimetableNotifier());
