import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory_model.dart';
import 'dart:convert';
import '../utils/pronoun_helper.dart';
import 'couple_provider.dart';

class CategoryNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CategoryNotifier(this.ref) : super([]) {
    _loadCustomCategories();
  }

  final Ref ref;

  List<Map<String, dynamic>> _getDefaultCategories(String p) {
    return [
      {'label': '🍕 Food', 'id': MemoryModel.catFood, 'sug': ['${PronounHelper.subject(p)} loves', '${PronounHelper.subject(p)} craves', '${PronounHelper.possessive(p)} comfort food is']},
      {'label': '🏕️ Places', 'id': MemoryModel.catPlace, 'sug': ['${PronounHelper.possessive(p)} favourite spot is', '${PronounHelper.subject(p)} wants to visit', 'We had our first date at']},
      {'label': '🧘 Habits', 'id': MemoryModel.catHabit, 'sug': ['Every morning ${PronounHelper.subject(p).toLowerCase()}', '${PronounHelper.subject(p)} always', 'Before bed ${PronounHelper.subject(p).toLowerCase()}']},
      {'label': '🎁 Gifts', 'id': MemoryModel.catGift, 'sug': ['${PronounHelper.subject(p)} wants to buy', 'Dream gift for ${PronounHelper.object(p).toLowerCase()}', 'Perfect surprise would be']},
      {'label': '😂 Jokes', 'id': MemoryModel.catJoke, 'sug': ['Inside joke:', '${PronounHelper.subject(p)} always laughs at', 'Funny moment:']},
      {'label': '🥘 Recipes', 'id': MemoryModel.catRecipe, 'sug': ['${PronounHelper.possessive(p)} secret ingredient is', '${PronounHelper.subject(p)} makes the best', 'Recipe for']},
    ];
  }

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final customCatsStr = prefs.getString('custom_categories');
    List<Map<String, dynamic>> customCats = [];
    if (customCatsStr != null) {
      final List<dynamic> decoded = jsonDecode(customCatsStr);
      customCats = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final coupleState = ref.read(coupleProvider);
    final pronoun = coupleState.valueOrNull?.currentUser?.partnerPronoun ?? 'she';
    state = [..._getDefaultCategories(pronoun), ...customCats];
  }

  Future<void> addCustomCategory(String label, String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    final id = label.toLowerCase().replaceAll(' ', '_');
    
    final newCat = {
      'label': '$emoji $label',
      'id': id,
      'sug': <String>[], // Custom categories have no suggestions initially
    };

    final customCatsStr = prefs.getString('custom_categories');
    List<Map<String, dynamic>> customCats = [];
    if (customCatsStr != null) {
      final List<dynamic> decoded = jsonDecode(customCatsStr);
      customCats = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    
    customCats.add(newCat);
    await prefs.setString('custom_categories', jsonEncode(customCats));
    
    final coupleState = ref.read(coupleProvider);
    final pronoun = coupleState.valueOrNull?.currentUser?.partnerPronoun ?? 'she';
    state = [..._getDefaultCategories(pronoun), ...customCats];
  }
}

final categoryProvider = StateNotifierProvider<CategoryNotifier, List<Map<String, dynamic>>>((ref) {
  // Watch coupleProvider to re-evaluate when pronoun changes
  ref.watch(coupleProvider);
  return CategoryNotifier(ref);
});
