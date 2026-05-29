import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_model.dart';
import 'couple_provider.dart';

class MusicNotifier extends AsyncNotifier<List<SongModel>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<SongModel>> build() async {
    await ref.watch(coupleProvider.future);
    return _fetchSongs();
  }

  Future<List<SongModel>> _fetchSongs() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id;
    final coupleId    = coupleState?.coupleId ?? myId;

    if (myId == null) return [];

    try {
      final query = _supabase.from('couple_songs').select();
      final data = await query
          .or('couple_id.eq.$coupleId,added_by.eq.$myId')
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => SongModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addSong({
    required String title,
    required String artist,
    String? album,
    String? spotifyUrl,
    String? appleMusicUrl,
    String? youtubeUrl,
    required String category,
    String? notes,
  }) async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId     = _supabase.auth.currentUser?.id;
    final coupleId = coupleState?.coupleId ?? myId;

    if (myId == null || coupleId == null) return;

    try {
      final payload = {
        'couple_id':       coupleId,
        'added_by':        myId,
        'title':           title,
        'artist':          artist,
        'album':           album,
        'spotify_url':     spotifyUrl,
        'apple_music_url': appleMusicUrl,
        'youtube_url':     youtubeUrl,
        'category':        category,
        'notes':           notes,
      };

      await _supabase.from('couple_songs').insert(payload);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSong(String id) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await _supabase.from('couple_songs').delete().eq('id', id);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> attachToMemory(String songId, String memoryId) async {
    try {
      await _supabase
          .from('couple_songs')
          .update({'memory_id': memoryId})
          .eq('id', songId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeMemoryAttachment(String songId) async {
    try {
      await _supabase
          .from('couple_songs')
          .update({'memory_id': null})
          .eq('id', songId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Map<String, List<SongModel>> get songsByCategory {
    final Map<String, List<SongModel>> map = {};
    for (final cat in SongModel.predefinedCategories) {
      map[cat['id'] as String] = [];
    }
    
    for (final song in state.valueOrNull ?? <SongModel>[]) {
      if (!map.containsKey(song.category)) {
        map[song.category] = [];
      }
      map[song.category]!.add(song);
    }
    return map;
  }
}

final musicProvider = AsyncNotifierProvider<MusicNotifier, List<SongModel>>(
  () => MusicNotifier(),
);
