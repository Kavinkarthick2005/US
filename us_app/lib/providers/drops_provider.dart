import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drop_model.dart';
import 'couple_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DropsNotifier — CRUD for the drops table
// ─────────────────────────────────────────────────────────────────────────────

class DropsNotifier extends AsyncNotifier<List<DropModel>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<DropModel>> build() async {
    await ref.watch(coupleProvider.future);
    return _fetchDrops();
  }

  Future<List<DropModel>> _fetchDrops() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id;
    final coupleId    = coupleState?.coupleId ?? myId;

    if (myId == null) return [];

    try {
      final data = await _supabase
          .from('drops')
          .select()
          .eq('couple_id', coupleId!)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => DropModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Add drop ──────────────────────────────────────────────────────────────

  Future<DropModel> addDrop({
    required String photoUrl,
    String? caption,
    String? songTitle,
    String? songArtist,
    String? songInfo,
    String visibility = 'shared',
    int importanceScore = 0,
    List<String> momentContext = const [],
  }) async {
    final myId     = _supabase.auth.currentUser?.id;
    final coupleId = ref.read(coupleProvider).valueOrNull?.coupleId ?? myId;

    if (myId == null || coupleId == null) throw Exception('No user found');

    try {
      final payload = <String, dynamic>{
        'couple_id':  coupleId,
        'added_by':   myId,
        'photo_url':  photoUrl,
        'visibility': visibility,
        'importance_score': importanceScore,
        'moment_context': momentContext,
        if (caption != null)    'caption':     caption,
        if (songTitle != null)  'song_title':  songTitle,
        if (songArtist != null) 'song_artist': songArtist,
        if (songInfo != null)   'song_info':   songInfo,
      };

      final inserted = await _supabase
          .from('drops')
          .insert(payload)
          .select()
          .single();

      final newDrop = DropModel.fromJson(inserted);
      if (state.hasValue) {
        state = AsyncData([newDrop, ...state.value!]);
      } else {
        ref.invalidateSelf();
      }
      return newDrop;
    } catch (e) {
      rethrow;
    }
  }

  // ── Delete drop ───────────────────────────────────────────────────────────

  Future<void> deleteDrop(String id) async {
    try {
      await _supabase.from('drops').delete().eq('id', id);
      if (state.hasValue) {
        state = AsyncData(state.value!.where((d) => d.id != id).toList());
      }
    } catch (e) {
      rethrow;
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  int get totalCount => state.valueOrNull?.length ?? 0;

  List<DropModel> get myDrops {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? [])
        .where((d) => d.addedBy == myId)
        .toList();
  }

  List<DropModel> get partnerDrops {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? [])
        .where((d) => d.addedBy != myId)
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final dropsProvider =
    AsyncNotifierProvider<DropsNotifier, List<DropModel>>(
        () => DropsNotifier());

/// Recent drops for the Us Space dashboard strip.
final recentDropsProvider =
    FutureProvider.autoDispose<List<DropModel>>((ref) async {
  final sb      = Supabase.instance.client;
  final myId    = sb.auth.currentUser?.id;
  if (myId == null) return [];

  try {
    final cs       = Supabase.instance.client;
    final coupleId = myId;

    final data = await cs
        .from('drops')
        .select()
        .order('created_at', ascending: false)
        .limit(6);

    return (data as List)
        .map((json) => DropModel.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});
