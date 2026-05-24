import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../models/food_log_model.dart';
import 'couple_provider.dart';

class FoodNotifier extends AsyncNotifier<List<FoodLogModel>> {
  final _sb = Supabase.instance.client;

  @override
  Future<List<FoodLogModel>> build() async {
    final couple    = await ref.watch(coupleProvider.future);
    final myId      = couple.currentUser?.id;
    if (myId == null) return [];
    final partnerId = couple.partner?.id;
    final ids = [myId, if (partnerId != null) partnerId];
    return _fetchLogs(ids);
  }

  Future<List<FoodLogModel>> _fetchLogs(List<String> userIds) async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final data = await _sb
          .from('food_logs')
          .select()
          .inFilter('user_id', userIds)
          .gte('logged_at', since)
          .order('logged_at', ascending: false);
      return (data as List)
          .map((j) => FoodLogModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<FoodLogModel>> fetchLogs(String userId) =>
      _fetchLogs([userId]);

  Future<void> addLog(FoodLogModel log) async {
    await _sb.from('food_logs').insert(log.toJson());
    if (state.hasValue) {
      state = AsyncData([log, ...state.value!]);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> deleteLog(String id) async {
    await _sb.from('food_logs').delete().eq('id', id);
    ref.invalidateSelf();
  }

  Future<String> uploadFoodPhotoBytes(Uint8List bytes, String fileName) async {
    final userId = _sb.auth.currentUser?.id ?? 'unknown';
    final ext    = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final path   = '$userId/${const Uuid().v4()}.$ext';
    await _sb.storage.from('food-photos').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return _sb.storage.from('food-photos').getPublicUrl(path);
  }

  Future<List<String>> analyzeFoodPhoto(String imageUrl) async {
    try {
      final res = await Dio().post<Map<String, dynamic>>(
        'https://api.clarifai.com/v2/models/food-item-recognition/outputs',
        options: Options(headers: {
          'Authorization': 'Key ${Env.clarifaiKey}',
          'Content-Type': 'application/json',
        }),
        data: {
          'inputs': [
            {
              'data': {
                'image': {'url': imageUrl}
              }
            }
          ],
        },
      );
      final concepts =
          res.data!['outputs'][0]['data']['concepts'] as List<dynamic>;
      return concepts
          .take(3)
          .map((c) => (c['name'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Computed getters ────────────────────────────────────────────────────────

  List<FoodLogModel> get todayMyLogs {
    final myId  = ref.read(coupleProvider).valueOrNull?.currentUser?.id;
    final today = DateTime.now();
    return (state.valueOrNull ?? []).where((l) =>
        l.userId == myId &&
        l.loggedAt.year  == today.year &&
        l.loggedAt.month == today.month &&
        l.loggedAt.day   == today.day).toList();
  }

  List<FoodLogModel> get todayPartnerLogs {
    final partnerId = ref.read(coupleProvider).valueOrNull?.partner?.id;
    if (partnerId == null) return [];
    final today = DateTime.now();
    return (state.valueOrNull ?? []).where((l) =>
        l.userId == partnerId &&
        l.loggedAt.year  == today.year &&
        l.loggedAt.month == today.month &&
        l.loggedAt.day   == today.day).toList();
  }
}

final foodProvider =
    AsyncNotifierProvider<FoodNotifier, List<FoodLogModel>>(
        () => FoodNotifier());
