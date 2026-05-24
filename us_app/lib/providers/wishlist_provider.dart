import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wishlist_model.dart';
import 'couple_provider.dart';

class WishlistNotifier extends AsyncNotifier<List<WishlistModel>> {
  final _sb = Supabase.instance.client;

  @override
  Future<List<WishlistModel>> build() async {
    final coupleState = await ref.watch(coupleProvider.future);
    final coupleId = coupleState.coupleId;
    final myId = coupleState.currentUser?.id;
    if (myId == null) return [];
    
    if (coupleId != null) {
      return _fetch(coupleId: coupleId);
    } else {
      return _fetch(myId: myId);
    }
  }

  Future<List<WishlistModel>> _fetch({String? coupleId, String? myId}) async {
    try {
      final query = _sb.from('wishlists').select();
      final data = await (coupleId != null 
          ? query.eq('couple_id', coupleId).order('created_at', ascending: false)
          : query.eq('added_by', myId!).order('created_at', ascending: false));
          
      return (data as List)
          .map((j) => WishlistModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addItem(WishlistModel item) async {
    await _sb.from('wishlists').insert(item.toJson());
    if (state.hasValue) {
      state = AsyncData([item, ...state.value!]);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> markDone(String id) async {
    await _sb.from('wishlists').update({'is_done': true}).eq('id', id);
    if (state.hasValue) {
      final updated = state.value!.map((i) {
        if (i.id == id) {
          return WishlistModel(
            id: i.id,
            coupleId: i.coupleId,
            addedBy: i.addedBy,
            title: i.title,
            type: i.type,
            price: i.price,
            link: i.link,
            notes: i.notes,
            isDone: true,
            createdAt: i.createdAt,
          );
        }
        return i;
      }).toList();
      state = AsyncData(updated);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> deleteItem(String id) async {
    await _sb.from('wishlists').delete().eq('id', id);
    ref.invalidateSelf();
  }

  List<WishlistModel> get buyItems =>
      (state.valueOrNull ?? [])
          .where((i) => i.type == WishlistModel.typeBuy && !i.isDone)
          .toList();

  List<WishlistModel> get experienceItems =>
      (state.valueOrNull ?? [])
          .where((i) => i.type == WishlistModel.typeExperience && !i.isDone)
          .toList();

  List<WishlistModel> get doneItems =>
      (state.valueOrNull ?? []).where((i) => i.isDone).toList();

  double get totalBuyBudget =>
      (state.valueOrNull ?? [])
          .where((i) =>
              i.type == WishlistModel.typeBuy && !i.isDone && i.price != null)
          .fold(0.0, (s, i) => s + (i.price ?? 0));
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<WishlistModel>>(
        () => WishlistNotifier());
