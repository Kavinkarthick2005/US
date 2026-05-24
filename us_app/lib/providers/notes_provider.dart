import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note_model.dart';
import 'couple_provider.dart';

class NotesNotifier extends AsyncNotifier<List<NoteModel>> {
  final _sb = Supabase.instance.client;

  @override
  Future<List<NoteModel>> build() async {
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

  Future<List<NoteModel>> _fetch({String? coupleId, String? myId}) async {
    try {
      final query = _sb.from('notes').select();
      final data = await (coupleId != null 
          ? query.eq('couple_id', coupleId).order('pinned', ascending: false).order('created_at', ascending: false)
          : query.eq('added_by', myId!).order('pinned', ascending: false).order('created_at', ascending: false));
          
      return (data as List)
          .map((j) => NoteModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Notes fetch error: $e');
      return [];
    }
  }

  Future<void> addNote(NoteModel note) async {
    await _sb.from('notes').insert(note.toJson());
    if (state.hasValue) {
      state = AsyncData([note, ...state.value!]
        ..sort((a, b) {
          if (a.isPinned == b.isPinned) {
            return b.createdAt.compareTo(a.createdAt);
          }
          return a.isPinned ? -1 : 1;
        }));
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> togglePin(NoteModel note) async {
    final newPinned = !note.isPinned;
    await _sb.from('notes').update({'pinned': newPinned}).eq('id', note.id);
    if (state.hasValue) {
      final updated = state.value!.map((n) {
        if (n.id == note.id) {
          return NoteModel(
            id: n.id,
            coupleId: n.coupleId,
            addedBy: n.addedBy,
            title: n.title,
            content: n.content,
            isPinned: newPinned,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      updated.sort((a, b) {
        if (a.isPinned == b.isPinned) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return a.isPinned ? -1 : 1;
      });
      state = AsyncData(updated);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> deleteNote(String id) async {
    await _sb.from('notes').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<NoteModel>>(
        () => NotesNotifier());
