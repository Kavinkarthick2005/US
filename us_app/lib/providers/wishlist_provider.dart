import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wishlist_model.dart';
import 'couple_provider.dart';

class WishlistNotifier extends AsyncNotifier<List<WishlistModel>> {
  final _sb = Supabase.instance.client;

  @override
  Future<List<WishlistModel>> build() async {
    final coupleState = await ref.watch(coupleProvider.future);
    final myId = _sb.auth.currentUser?.id;
    if (myId == null) return [];
    
    final coupleId = coupleState.coupleId ?? myId;
    return _fetch(coupleId: coupleId, myId: myId);
  }

  Future<List<WishlistModel>> _fetch({required String coupleId, required String myId}) async {
    try {
      final query = _sb.from('wishlist').select();
      final data = await query
          .or('couple_id.eq.$coupleId,added_by.eq.$myId')
          .order('created_at', ascending: false);
          
      return (data as List)
          .map((j) => WishlistModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addItem(WishlistModel item) async {
    await _sb.from('wishlist').insert(item.toJson());
    ref.invalidateSelf();
  }

  Future<void> updateItem(WishlistModel item) async {
    await _sb.from('wishlist').update(item.toJson()).eq('id', item.id);
    ref.invalidateSelf();
  }

  Future<void> markDone(String id) async {
    await _sb.from('wishlist').update({'is_done': true}).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> hideItem(String id) async {
    await _sb.from('wishlist').update({'is_hidden': true}).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteItem(String id) async {
    await _sb.from('wishlist').delete().eq('id', id);
    ref.invalidateSelf();
  }

  List<WishlistModel> get buyItems =>
      (state.valueOrNull ?? [])
          .where((i) => i.type == WishlistModel.typeBuy && !i.isDone && !i.isHidden)
          .toList();

  List<WishlistModel> get experienceItems =>
      (state.valueOrNull ?? [])
          .where((i) => i.type == WishlistModel.typeExperience && !i.isDone && !i.isHidden)
          .toList();

  List<WishlistModel> get doneItems =>
      (state.valueOrNull ?? []).where((i) => i.isDone && !i.isHidden).toList();

  List<WishlistModel> get hiddenItems =>
      (state.valueOrNull ?? []).where((i) => i.isHidden).toList();

  double get totalBuyBudget =>
      (state.valueOrNull ?? [])
          .where((i) =>
              i.type == WishlistModel.typeBuy && !i.isDone && !i.isHidden && i.price != null)
          .fold(0.0, (s, i) => s + (i.price ?? 0));
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<WishlistModel>>(
        () => WishlistNotifier());
