import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/timeline_event_model.dart';
import 'couple_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TimelineProvider — aggregates memories + drops + open-when letters
// sorted chronologically for the Relationship Timeline screen
// ─────────────────────────────────────────────────────────────────────────────

final timelineProvider =
    FutureProvider.autoDispose<List<TimelineEvent>>((ref) async {
  await ref.watch(coupleProvider.future);
  final coupleState = ref.read(coupleProvider).valueOrNull;
  final myId        = coupleState?.currentUser?.id;
  final partnerId   = coupleState?.partner?.id;
  final coupleId    = coupleState?.coupleId ?? myId;

  if (myId == null) return [];

  final sb     = Supabase.instance.client;
  final events = <TimelineEvent>[];

  // ── Memories ──────────────────────────────────────────────────────────────
  try {
    var query = sb.from('memories').select();
    if (partnerId != null) {
      query = query.or('owner_id.eq.$myId,owner_id.eq.$partnerId');
    } else {
      query = query.eq('owner_id', myId);
    }
    final memories = await query.order('created_at', ascending: false);
    for (final json in memories as List) {
      events.add(TimelineEvent.fromMemory(json as Map<String, dynamic>));
    }
  } catch (_) {}

  // ── Drops ─────────────────────────────────────────────────────────────────
  if (coupleId != null) {
    try {
      final drops = await sb
          .from('drops')
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);
      for (final json in drops as List) {
        events.add(TimelineEvent.fromDrop(json as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  // ── Open When Letters ─────────────────────────────────────────────────────
  if (coupleId != null) {
    try {
      final letters = await sb
          .from('open_when_letters')
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false);
      for (final json in letters as List) {
        events.add(TimelineEvent.fromOpenWhen(json as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  // Sort all events newest first
  events.sort((a, b) => b.eventDate.compareTo(a.eventDate));
  return events;
});

// ─────────────────────────────────────────────────────────────────────────────
// Grouped timeline — events grouped by year-month for section headers
// ─────────────────────────────────────────────────────────────────────────────

final groupedTimelineProvider = FutureProvider.autoDispose<
    List<({String label, List<TimelineEvent> events})>>((ref) async {
  final events = await ref.watch(timelineProvider.future);

  final grouped = <String, List<TimelineEvent>>{};
  for (final event in events) {
    final key = '${event.eventDate.year}-${event.eventDate.month.toString().padLeft(2, '0')}';
    grouped.putIfAbsent(key, () => []).add(event);
  }

  return grouped.entries.map((e) {
    final parts = e.key.split('-');
    final year  = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return (label: '${monthNames[month]} $year', events: e.value);
  }).toList();
});
