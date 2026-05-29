import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry_model.dart';
import 'couple_provider.dart';

class JournalNotifier extends AsyncNotifier<List<JournalEntryModel>> {
  final _sb = Supabase.instance.client;

  @override
  Future<List<JournalEntryModel>> build() async {
    final coupleState = await ref.watch(coupleProvider.future);
    final myId = coupleState.currentUser?.id;
    final partnerId = coupleState.partner?.id;
    if (myId == null) return [];

    try {
      var query = _sb.from('journal_entries').select();
      if (partnerId != null) {
        query = query.or('user_id.eq.$myId,user_id.eq.$partnerId');
      } else {
        query = query.eq('user_id', myId);
      }

      final data = await query.order('created_at', ascending: false);
      final list = (data as List).map((json) => JournalEntryModel.fromJson(json as Map<String, dynamic>)).toList();

      // Load pinned IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final pinnedIds = prefs.getStringList('pinned_journals') ?? [];

      // Map pinned states and filter partner visibility
      final filteredList = list.map((item) {
        final isPinned = pinnedIds.contains(item.id);
        return item.copyWith(isPinned: isPinned);
      }).where((item) {
        if (item.userId == myId) return true; // Always see my own private thoughts
        // Only see partner's thoughts if they are shared or partner visible
        return item.visibility == 'partner_visible' || item.visibility == 'shared';
      }).toList();

      // Sort: pinned first, then by date descending
      filteredList.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return filteredList;
    } catch (e) {
      print('Fetch journal error: $e');
      return [];
    }
  }

  Future<void> addEntry({
    required String title,
    required String content,
    required String mood,
    required String visibility,
  }) async {
    final myId = _sb.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final inserted = await _sb.from('journal_entries').insert({
        'user_id': myId,
        'title': title.isEmpty ? null : title,
        'content': content,
        'mood': mood.isEmpty ? null : mood,
        'visibility': visibility,
      }).select().single();

      final newModel = JournalEntryModel.fromJson(inserted);
      
      final currentList = state.valueOrNull ?? [];
      state = AsyncData([newModel, ...currentList]);
      ref.invalidateSelf();
    } catch (e) {
      print('Add journal entry error: $e');
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _sb.from('journal_entries').delete().eq('id', id);
      
      // Also remove from pinned list if present
      final prefs = await SharedPreferences.getInstance();
      final pinned = prefs.getStringList('pinned_journals') ?? [];
      if (pinned.contains(id)) {
        pinned.remove(id);
        await prefs.setStringList('pinned_journals', pinned);
      }

      ref.invalidateSelf();
    } catch (e) {
      print('Delete journal error: $e');
    }
  }

  Future<void> togglePin(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinned = prefs.getStringList('pinned_journals') ?? [];
      
      if (pinned.contains(id)) {
        pinned.remove(id);
      } else {
        pinned.add(id);
      }
      
      await prefs.setStringList('pinned_journals', pinned);
      ref.invalidateSelf();
    } catch (e) {
      print('Toggle pin journal error: $e');
    }
  }
}

final journalProvider = AsyncNotifierProvider<JournalNotifier, List<JournalEntryModel>>(() => JournalNotifier());
