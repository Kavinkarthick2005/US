import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../core/groq_client.dart';
import 'couple_provider.dart';

class RecapData {
  final int month;
  final int year;
  final int daysInMonth;
  final int memoriesCount;
  final int dropsCount;
  final double totalExpenses;
  final String topCategory;
  final String topFood;
  final int periodDays;
  final int openWhenOpened;
  final int coupleSongs;
  final int wishlistDone;
  final String insightText;
  final String moodLabel;
  final List<String> topMoments;

  RecapData({
    required this.month,
    required this.year,
    required this.daysInMonth,
    required this.memoriesCount,
    required this.dropsCount,
    required this.totalExpenses,
    required this.topCategory,
    required this.topFood,
    required this.periodDays,
    required this.openWhenOpened,
    required this.coupleSongs,
    required this.wishlistDone,
    required this.insightText,
    required this.moodLabel,
    required this.topMoments,
  });

  factory RecapData.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    return RecapData(
      month: json['month'],
      year: json['year'],
      daysInMonth: stats['daysInMonth'] ?? 30,
      memoriesCount: stats['memoriesCount'] ?? 0,
      dropsCount: stats['dropsCount'] ?? 0,
      totalExpenses: (stats['totalExpenses'] ?? 0).toDouble(),
      topCategory: stats['topCategory'] ?? 'Miscellaneous',
      topFood: stats['topFood'] ?? 'Nothing special',
      periodDays: stats['periodDays'] ?? 0,
      openWhenOpened: stats['openWhenOpened'] ?? 0,
      coupleSongs: stats['coupleSongs'] ?? 0,
      wishlistDone: stats['wishlistDone'] ?? 0,
      insightText: json['insight_text'] ?? '',
      moodLabel: json['mood_label'] ?? 'Cozy Month ☕',
      topMoments: List<String>.from(json['top_moments'] ?? []),
    );
  }

  Map<String, dynamic> toJsonStats() {
    return {
      'daysInMonth': daysInMonth,
      'memoriesCount': memoriesCount,
      'dropsCount': dropsCount,
      'totalExpenses': totalExpenses,
      'topCategory': topCategory,
      'topFood': topFood,
      'periodDays': periodDays,
      'openWhenOpened': openWhenOpened,
      'coupleSongs': coupleSongs,
      'wishlistDone': wishlistDone,
    };
  }
}

class RecapNotifier extends AsyncNotifier<RecapData?> {
  @override
  Future<RecapData?> build() async {
    return null;
  }

  Future<void> generateRecap(int month, int year) async {
    state = const AsyncValue.loading();
    try {
      final couple = ref.read(coupleProvider).valueOrNull;
      final coupleId = couple?.coupleId;
      if (coupleId == null) throw Exception('No couple ID');

      // 1. Check Cache
      final cached = await Supabase.instance.client
          .from('monthly_recaps')
          .select()
          .eq('couple_id', coupleId)
          .eq('month', month)
          .eq('year', year)
          .maybeSingle();

      if (cached != null) {
        state = AsyncValue.data(RecapData.fromJson(cached));
        return;
      }

      // 2. Fetch Data if not cached
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      // Memories
      final memoriesResp = await Supabase.instance.client
          .from('memories')
          .select('id, content, importance_score, created_at')
          .eq('couple_id', coupleId)
          .gte('created_at', startStr)
          .lt('created_at', endStr);
      final memoriesCount = memoriesResp.length;
      
      // Sort memories by importance
      final sortedMemories = List<Map<String, dynamic>>.from(memoriesResp)
        ..sort((a, b) => ((b['importance_score'] ?? 0) as int).compareTo((a['importance_score'] ?? 0) as int));
      
      final topMemoryContent = sortedMemories.isNotEmpty ? sortedMemories.first['content'].toString() : '';

      // Drops
      final dropsResp = await Supabase.instance.client
          .from('drops')
          .select('id, created_at')
          .eq('couple_id', coupleId)
          .gte('created_at', startStr)
          .lt('created_at', endStr);
      final dropsCount = dropsResp.length;

      // Expenses
      final expensesResp = await Supabase.instance.client
          .from('expenses')
          .select('amount, category')
          .eq('couple_id', coupleId)
          .gte('spent_at', startStr)
          .lt('spent_at', endStr);
      
      double totalExpenses = 0;
      final categoryCounts = <String, double>{};
      for (final e in expensesResp) {
        final amt = (e['amount'] as num).toDouble();
        totalExpenses += amt;
        final cat = e['category'] as String? ?? 'Misc';
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + amt;
      }
      String topCategory = 'Miscellaneous';
      if (categoryCounts.isNotEmpty) {
        topCategory = categoryCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      // Food
      final foodResp = await Supabase.instance.client
          .from('food_logs')
          .select('description')
          .eq('couple_id', coupleId)
          .gte('logged_at', startStr)
          .lt('logged_at', endStr);
      final foodCounts = <String, int>{};
      for (final f in foodResp) {
        final desc = f['description'] as String;
        foodCounts[desc] = (foodCounts[desc] ?? 0) + 1;
      }
      String topFood = 'Nothing specific';
      if (foodCounts.isNotEmpty) {
        topFood = foodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      // 3. Generate AI Insights via Groq
      final monthName = DateFormat('MMMM').format(start);
      final promptText = """
Analyze this couple's month of $monthName:
- Memories created: $memoriesCount
- Most meaningful memory: $topMemoryContent
- Shared photo drops: $dropsCount
- Money spent together: ₹${totalExpenses.toInt()} (Mostly on $topCategory)
- Most common food shared: $topFood

Tasks:
1. Provide a 'mood_label' (e.g., Cozy Month ☕, Adventure Month ✈️, Growth Month 🌱). Max 3 words.
2. Provide an 'insight_text' which is ONE warm, encouraging, specific sentence about their month (max 20 words).
3. Provide 'top_moments', a list of exactly 3 strings representing the 3 biggest highlights of the month (e.g., "Saved 18 memories", "Ate a lot of Pizza", "Meaningful memory about X"). Keep them short and use an emoji at the start of each.

Return ONLY valid JSON:
{
  "mood_label": "String",
  "insight_text": "String",
  "top_moments": ["String", "String", "String"]
}
""";

      final groqResponse = await GroqClient.prompt(
        "You are an expert relationship AI. Return raw JSON only.",
        promptText,
      );

      // Parse JSON
      String moodLabel = 'Our Month 💕';
      String insightText = 'Another beautiful month spent together.';
      List<String> topMoments = ['Shared $memoriesCount memories', 'Dropped $dropsCount moments', 'Spent time together'];
      
      try {
        // Extract JSON block if it's wrapped in markdown
        var jsonStr = groqResponse;
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        
        // Custom lightweight JSON parsing since dart:convert is imported in screen usually
        // Actually dart:convert is available
        final parsed = jsonDecode(jsonStr);
        moodLabel = parsed['mood_label'] ?? moodLabel;
        insightText = parsed['insight_text'] ?? insightText;
        if (parsed['top_moments'] != null) {
          topMoments = List<String>.from(parsed['top_moments']);
        }
      } catch (e) {
        // Fallback
      }

      final data = RecapData(
        month: month,
        year: year,
        daysInMonth: DateTime(year, month + 1, 0).day,
        memoriesCount: memoriesCount,
        dropsCount: dropsCount,
        totalExpenses: totalExpenses,
        topCategory: topCategory,
        topFood: topFood,
        periodDays: 5, // Mocked for now, would query period_logs
        openWhenOpened: 0,
        coupleSongs: 0,
        wishlistDone: 0,
        insightText: insightText,
        moodLabel: moodLabel,
        topMoments: topMoments,
      );

      // 4. Save to Cache
      await Supabase.instance.client.from('monthly_recaps').insert({
        'couple_id': coupleId,
        'month': month,
        'year': year,
        'insight_text': data.insightText,
        'mood_label': data.moodLabel,
        'top_moments': data.topMoments,
        'stats': data.toJsonStats(),
      });

      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final recapProvider = AsyncNotifierProvider<RecapNotifier, RecapData?>(() {
  return RecapNotifier();
});
