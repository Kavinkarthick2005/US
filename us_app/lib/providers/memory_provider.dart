import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/memory_model.dart';
import 'couple_provider.dart';

class MemoryNotifier extends AsyncNotifier<List<MemoryModel>> {
  final _supabase = Supabase.instance.client;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Future<List<MemoryModel>> build() async {
    await ref.watch(coupleProvider.future);
    return _fetchMemories();
  }

  Future<List<MemoryModel>> _fetchMemories() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = coupleState?.currentUser?.id;
    final partnerId = coupleState?.partner?.id;

    if (myId == null) return [];

    try {
      var query = _supabase.from('memories').select().eq('hidden', false);
      
      if (partnerId != null) {
        query = query.or('owner_id.eq.$myId,owner_id.eq.$partnerId');
      } else {
        query = query.eq('owner_id', myId);
      }

      final data = await query.order('created_at', ascending: false);

      return (data as List)
          .map((json) => MemoryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback: if 'hidden' column doesn't exist yet, fetch without filter
      try {
        var query = _supabase.from('memories').select();
        final coupleState2 = ref.read(coupleProvider).valueOrNull;
        final myId2 = coupleState2?.currentUser?.id;
        final partnerId2 = coupleState2?.partner?.id;
        if (myId2 == null) return [];
        if (partnerId2 != null) {
          query = query.or('owner_id.eq.$myId2,owner_id.eq.$partnerId2');
        } else {
          query = query.eq('owner_id', myId2);
        }
        final data = await query.order('created_at', ascending: false);
        return (data as List)
            .map((json) => MemoryModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> addMemory(String content, String category, String ownerId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final inserted = await _supabase.from('memories').insert({
        'owner_id': ownerId,
        'added_by': myId,
        'category': category,
        'content': content,
      }).select().single();
      
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

  Future<void> deleteMemory(String id) async {
    try {
      await _supabase.from('memories').delete().eq('id', id);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> hideMemory(String id) async {
    try {
      await _supabase.from('memories').update({'hidden': true}).eq('id', id);
      if (state.hasValue) {
        state = AsyncData(state.value!.where((m) => m.id != id).toList());
      } else {
        ref.invalidateSelf();
      }
    } catch (e) {
      // If hidden column doesn't exist yet, fall back to just removing from UI
      if (state.hasValue) {
        state = AsyncData(state.value!.where((m) => m.id != id).toList());
      }
    }
  }

  void searchMemories(String query) {
    _searchQuery = query.toLowerCase();
    // We don't invalidate the provider, we just rebuild dependent widgets by 
    // updating the state with the same data if we want to trigger a rebuild, 
    // or we can handle search purely in the UI. 
    // To properly notify listeners of a local change, we can re-emit the state:
    if (state.hasValue) {
      state = AsyncData(state.value!);
    }
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    if (state.hasValue) {
      state = AsyncData(state.value!);
    }
  }

  // ── Getters for filtered data ─────────────────────────────────────────────

  List<MemoryModel> get filteredMemories {
    final list = state.valueOrNull ?? [];
    return list.where((m) {
      final matchesSearch = m.content.toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'All' || m.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Map<String, List<MemoryModel>> get memoriesByCategory {
    final map = <String, List<MemoryModel>>{};
    final list = state.valueOrNull ?? [];
    for (var m in list) {
      map.putIfAbsent(m.category, () => []).add(m);
    }
    return map;
  }

  List<MemoryModel> get partnerMemories {
    final partnerId = ref.read(coupleProvider).valueOrNull?.partner?.id;
    if (partnerId == null) return [];
    return (state.valueOrNull ?? []).where((m) => m.ownerId == partnerId).toList();
  }

  List<MemoryModel> get myMemories {
    final myId = ref.read(coupleProvider).valueOrNull?.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? []).where((m) => m.ownerId == myId).toList();
  }
}

final memoryProvider = AsyncNotifierProvider<MemoryNotifier, List<MemoryModel>>(() {
  return MemoryNotifier();
});
