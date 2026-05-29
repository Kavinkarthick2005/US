import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  Future<void> unhideItem(String id) async {
    await _sb.from('wishlist').update({'is_hidden': false}).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteItem(String id) async {
    await _sb.from('wishlist').delete().eq('id', id);
    ref.invalidateSelf();
  }

  // --- GETTERS ---
  List<WishlistModel> get myItems {
    final myId = _sb.auth.currentUser?.id;
    return (state.valueOrNull ?? [])
        .where((i) => i.addedBy == myId && i.visibility == 'mine' && !i.isHidden)
        .toList();
  }

  List<WishlistModel> get theirItems {
    final myId = _sb.auth.currentUser?.id;
    return (state.valueOrNull ?? [])
        .where((i) => i.addedBy == myId && i.visibility == 'theirs' && !i.isHidden)
        .toList();
  }

  List<WishlistModel> get oursItems {
    return (state.valueOrNull ?? [])
        .where((i) => i.visibility == 'shared' && !i.isHidden)
        .toList();
  }

  List<WishlistModel> get hiddenItems {
    final myId = _sb.auth.currentUser?.id;
    return (state.valueOrNull ?? [])
        .where((i) => i.isHidden && i.addedBy == myId)
        .toList();
  }

  double get totalBuyBudget =>
      (state.valueOrNull ?? [])
          .where((i) => !i.isDone && !i.isHidden && i.price != null)
          .fold(0.0, (s, i) => s + (i.price ?? 0));
          
  // --- PIN SYSTEM ---
  Future<void> savePIN(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wishlist_pin', pin);
  }

  Future<bool> verifyPIN(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('wishlist_pin');
    return saved != null && saved == pin;
  }

  Future<bool> get isPINSet async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('wishlist_pin');
  }
}

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<WishlistModel>>(
        () => WishlistNotifier());
