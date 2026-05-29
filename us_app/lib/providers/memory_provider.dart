import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/memory_model.dart';
import 'couple_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// V2 MemoryNotifier — supports space filtering, partner care, full CRUD
// ─────────────────────────────────────────────────────────────────────────────

class MemoryNotifier extends AsyncNotifier<List<MemoryModel>> {
  final _supabase = Supabase.instance.client;

  String _searchQuery     = '';
  String _selectedCategory = 'All';
  String? _spaceFilter;          // null = all spaces
  bool _partnerCareOnly = false;

  @override
  Future<List<MemoryModel>> build() async {
    await ref.watch(coupleProvider.future);
    return _fetchMemories();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<List<MemoryModel>> _fetchMemories() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id;
    final partnerId   = coupleState?.partner?.id;

    if (myId == null) return [];

    try {
      var query = _supabase.from('memories').select();

      if (partnerId != null) {
        query = query.or('owner_id.eq.$myId,owner_id.eq.$partnerId');
      } else {
        query = query.eq('owner_id', myId);
      }

      final data = await query.order('created_at', ascending: false);

      return (data as List)
          .map((json) => MemoryModel.fromJson(json as Map<String, dynamic>))
          .where((m) {
            // Filter out partner's private memories
            if (m.ownerId != myId && m.visibility == MemoryModel.visPrivate) {
              return false;
            }
            return true;
          })
          .toList();
    } catch (e) {
      try {
        var fallback = _supabase.from('memories').select();
        final cs2       = ref.read(coupleProvider).valueOrNull;
        final myId2     = cs2?.currentUser?.id;
        final partnerId2 = cs2?.partner?.id;
        if (myId2 == null) return [];
        if (partnerId2 != null) {
          fallback = fallback.or('owner_id.eq.$myId2,owner_id.eq.$partnerId2');
        } else {
          fallback = fallback.eq('owner_id', myId2);
        }
        final data = await fallback.order('created_at', ascending: false);
        return (data as List)
            .map((json) => MemoryModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  Future<void> addMemory({
    required String content,
    required String category,
    required String ownerId,
    String space = MemoryModel.spaceUs,
    String visibility = MemoryModel.visShared,
    bool isPartnerCare = false,
    String? imageUrl,
    String? songTitle,
    String? songArtist,
    String? coupleId,
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final payload = <String, dynamic>{
        'owner_id':       ownerId,
        'added_by':       myId,
        'category':       category,
        'content':        content,
        'space':          space,
        'visibility':     visibility,
        'is_partner_care': isPartnerCare,
        if (imageUrl != null)   'image_url':   imageUrl,
        if (songTitle != null)  'song_title':  songTitle,
        if (songArtist != null) 'song_artist': songArtist,
        if (coupleId != null)   'couple_id':   coupleId,
      };

      final inserted = await _supabase
          .from('memories')
          .insert(payload)
          .select()
          .single();

      final newMemory = MemoryModel.fromJson(inserted);
      if (state.hasValue) {
        state = AsyncData([newMemory, ...state.value!]);
      } else {
        ref.invalidateSelf();
      }
    } catch (e) {
      rethrow;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteMemory(String id) async {
    try {
      await _supabase.from('memories').delete().eq('id', id);
      if (state.hasValue) {
        state = AsyncData(state.value!.where((m) => m.id != id).toList());
      }
    } catch (e) {
      rethrow;
    }
  }

  // ── Hide (soft-delete) ────────────────────────────────────────────────────

  Future<void> hideMemory(String id) async {
    try {
      await _supabase
          .from('memories')
          .update({'visibility': MemoryModel.visPrivate})
          .eq('id', id);
      if (state.hasValue) {
        state = AsyncData(state.value!.where((m) => m.id != id).toList());
      }
    } catch (_) {
      if (state.hasValue) {
        state = AsyncData(state.value!.where((m) => m.id != id).toList());
      }
    }
  }

  // ── Local filters ─────────────────────────────────────────────────────────

  void searchMemories(String query) {
    _searchQuery = query.toLowerCase();
    if (state.hasValue) state = AsyncData(state.value!);
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    if (state.hasValue) state = AsyncData(state.value!);
  }

  void setSpaceFilter(String? space) {
    _spaceFilter = space;
    if (state.hasValue) state = AsyncData(state.value!);
  }

  void setPartnerCareOnly(bool value) {
    _partnerCareOnly = value;
    if (state.hasValue) state = AsyncData(state.value!);
  }

  // ── Computed filtered views ───────────────────────────────────────────────

  List<MemoryModel> get filteredMemories {
    final list = state.valueOrNull ?? [];
    return list.where((m) {
      final matchesSearch   = m.content.toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'All' || m.category == _selectedCategory;
      final matchesSpace    = _spaceFilter == null || m.space == _spaceFilter;
      final matchesCare     = !_partnerCareOnly || m.isPartnerCare;
      return matchesSearch && matchesCategory && matchesSpace && matchesCare;
    }).toList();
  }

  List<MemoryModel> memoriesForSpace(String space) {
    return (state.valueOrNull ?? [])
        .where((m) => m.space == space)
        .toList();
  }

  List<MemoryModel> get partnerCareMemories {
    return (state.valueOrNull ?? [])
        .where((m) => m.isPartnerCare)
        .toList();
  }

  List<MemoryModel> get partnerMemories {
    final partnerId = ref.read(coupleProvider).valueOrNull?.partner?.id;
    if (partnerId == null) return [];
    return (state.valueOrNull ?? [])
        .where((m) => m.ownerId == partnerId)
        .toList();
  }

  List<MemoryModel> get myMemories {
    final myId = ref.read(coupleProvider).valueOrNull?.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? []).where((m) => m.ownerId == myId).toList();
  }

  Map<String, List<MemoryModel>> get memoriesByCategory {
    final map  = <String, List<MemoryModel>>{};
    final list = state.valueOrNull ?? [];
    for (var m in list) {
      map.putIfAbsent(m.category, () => []).add(m);
    }
    return map;
  }

  int get totalCount => state.valueOrNull?.length ?? 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final memoryProvider =
    AsyncNotifierProvider<MemoryNotifier, List<MemoryModel>>(
        () => MemoryNotifier());

/// Lightweight FutureProvider for dashboard recent memories.
final recentMemoriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final sb = Supabase.instance.client;
  final myId = sb.auth.currentUser?.id;
  if (myId == null) return [];
  try {
    final data = await sb
        .from('memories')
        .select()
        .order('created_at', ascending: false)
        .limit(5);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});
