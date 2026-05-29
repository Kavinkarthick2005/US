import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/open_when_model.dart';
import 'couple_provider.dart';

class OpenWhenNotifier extends AsyncNotifier<List<OpenWhenModel>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<OpenWhenModel>> build() async {
    await ref.watch(coupleProvider.future);
    return _fetchLetters();
  }

  Future<List<OpenWhenModel>> _fetchLetters() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id;
    final coupleId    = coupleState?.coupleId ?? myId;

    if (myId == null) return [];

    try {
      final query = _supabase.from('open_when_letters').select();
      final data = await query
          .or('couple_id.eq.$coupleId,written_by.eq.$myId,for_partner.eq.$myId')
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => OpenWhenModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addLetter({
    required String triggerLabel,
    required String content,
    required String coverColor,
  }) async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId     = _supabase.auth.currentUser?.id;
    final coupleId = coupleState?.coupleId ?? myId;
    final partnerId = coupleState?.partner?.id;

    if (myId == null || coupleId == null || partnerId == null) return;

    try {
      final payload = {
        'couple_id':     coupleId,
        'written_by':    myId,
        'for_partner':   partnerId,
        'trigger_label': triggerLabel,
        'content':       content,
        'cover_color':   coverColor,
        'is_opened':     false,
      };

      await _supabase.from('open_when_letters').insert(payload);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> openLetter(String id) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('open_when_letters')
          .update({'is_opened': true, 'opened_at': now})
          .eq('id', id);

      final letter = state.valueOrNull?.firstWhere((l) => l.id == id);
      if (letter != null) {
        final coupleState = ref.read(coupleProvider).valueOrNull;
        final partnerName = coupleState?.partner?.name.split(' ').first ?? 'your partner';

        await _supabase.from('memories').insert({
          'id': Uuid().v4(),
          'couple_id': letter.coupleId,
          'owner_id': myId,
          'added_by': myId,
          'category': 'letter',
          'content': 'Opened letter: ${letter.triggerLabel} — written by $partnerName',
          'visibility': 'shared',
          'date': now,
        });
      }

      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLetter(String id) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Check if it's eligible to delete (written by me and unopened)
      final letter = state.valueOrNull?.firstWhere((l) => l.id == id);
      if (letter != null && letter.writtenBy == myId && !letter.isOpened) {
        await _supabase.from('open_when_letters').delete().eq('id', id);
        ref.invalidateSelf();
      }
    } catch (e) {
      rethrow;
    }
  }

  List<OpenWhenModel> get myLetters {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? [])
        .where((l) => l.writtenBy == myId)
        .toList();
  }

  List<OpenWhenModel> get lettersForMe {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    return (state.valueOrNull ?? [])
        .where((l) => l.forPartner == myId)
        .toList();
  }

  List<OpenWhenModel> get unopenedForMe {
    return lettersForMe.where((l) => !l.isOpened).toList();
  }
}

final openWhenProvider =
    AsyncNotifierProvider<OpenWhenNotifier, List<OpenWhenModel>>(
        () => OpenWhenNotifier());
