import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/groq_client.dart';
import '../models/memory_model.dart';
import 'couple_provider.dart';

class PartnerCareNotifier extends AsyncNotifier<List<MemoryModel>> {
  final _supabase = Supabase.instance.client;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Future<List<MemoryModel>> build() async {
    // Keep list updated when couple linking changes
    await ref.watch(coupleProvider.future);
    return _fetchMemories();
  }

  Future<List<MemoryModel>> _fetchMemories() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = coupleState?.currentUser?.id;
    final partnerId = coupleState?.partner?.id ?? myId;

    if (myId == null || partnerId == null) return [];

    try {
      final data = await _supabase
          .from('memories')
          .select()
          .eq('added_by', myId)
          .eq('owner_id', partnerId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) => MemoryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Add Memory ─────────────────────────────────────────────────────────────
  Future<void> addMemory(String content, String category) async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = _supabase.auth.currentUser?.id;
    final partnerId = coupleState?.partner?.id ?? myId;
    final coupleId = coupleState?.coupleId ?? myId;

    if (myId == null || partnerId == null) return;

    try {
      final payload = <String, dynamic>{
        'owner_id': partnerId,
        'added_by': myId,
        'category': category,
        'content': content,
        'visibility': 'private', // private by default
        'space': 'he',
        'is_partner_care': true,
        if (coupleId != null) 'couple_id': coupleId,
      };

      await _supabase.from('memories').insert(payload);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  // ── Delete Memory ──────────────────────────────────────────────────────────
  Future<void> deleteMemory(String id) async {
    try {
      await _supabase.from('memories').delete().eq('id', id);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  // ── AI Categorization ──────────────────────────────────────────────────────
  Future<String> autoCategorizeMemo(String text) async {
    try {
      final sysPrompt = """
Categorize this note about my partner: "$text".
Categories allowed: food, place, habit, gift_idea, dislike, dream, craving, trigger, song, joke.
Return ONLY the category name in lowercase and absolutely nothing else. No prefix, no punctuation.
""";
      final response = await GroqClient.prompt(sysPrompt, text, maxTokens: 15);
      final finalCat = response.trim().toLowerCase();
      
      const validCategories = {
        'food', 'place', 'habit', 'gift_idea', 'dislike', 'dream', 'craving', 'trigger', 'song', 'joke'
      };
      
      return validCategories.contains(finalCat) ? finalCat : 'observation';
    } catch (_) {
      return 'observation';
    }
  }

  // ── AI Insights ───────────────────────────────────────────────────────────
  Future<List<String>> generateInsights() async {
    final memories = state.valueOrNull ?? [];
    if (memories.isEmpty) {
      return [
        "Record some memories about what she mentions to unlock care insights! 💕",
      ];
    }

    final contextText = memories.map((m) => "- [${m.category}]: ${m.content}").join('\n');
    final systemPrompt = """
You are an emotionally intelligent relationship companion AI.
Analyze these private notes that the user recorded about their partner:
$contextText

Find recurring patterns, trigger warning buffers, comfort foods, or dates she dreamed of.
Generate exactly 3 concise, premium, relationship-coaching tips or caring suggestions.
Each bullet point must be under 15 words, highly actionable, warm, and contain absolutely no italicized text.
Return ONLY the 3 bulleted insights separated by newlines. No numbering or other text.
""";

    try {
      final response = await GroqClient.prompt(systemPrompt, "Analyze my partner's preferences.", maxTokens: 250);
      final lines = response
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'^\s*[-*•\d\.]\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .take(3)
          .toList();

      if (lines.isEmpty) {
        return ["You are doing great! Keep observing her sweet preferences 💕"];
      }
      return lines;
    } catch (_) {
      return ["Keep track of her favorite items to trigger AI comfort guidance! 💕"];
    }
  }

  // ── Set Search & Filter ────────────────────────────────────────────────────
  void searchMemories(String query) {
    _searchQuery = query.toLowerCase();
    ref.notifyListeners();
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    ref.notifyListeners();
  }

  // ── Computed Filtered List ─────────────────────────────────────────────────
  List<MemoryModel> get filteredMemories {
    final list = state.valueOrNull ?? [];
    return list.where((m) {
      final matchesSearch = m.content.toLowerCase().contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'All' || m.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }
}

final partnerCareProvider =
    AsyncNotifierProvider<PartnerCareNotifier, List<MemoryModel>>(
        () => PartnerCareNotifier());
