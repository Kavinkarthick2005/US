import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory_model.dart';
import 'dart:convert';

class CategoryNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CategoryNotifier() : super([]) {
    _loadCustomCategories();
  }

  static const _defaultCategories = [
    {'label': '🍕 Food', 'id': MemoryModel.catFood, 'sug': ['She loves', 'She hates', 'Her comfort food is']},
    {'label': '🏕️ Places', 'id': MemoryModel.catPlace, 'sug': ['Her favourite spot is', 'She wants to visit', 'We had our first date at']},
    {'label': '🧘 Habits', 'id': MemoryModel.catHabit, 'sug': ['Every morning she', 'She always', 'Before bed she']},
    {'label': '👎 Dislikes', 'id': MemoryModel.catDislike, 'sug': ['She really dislikes', 'Never buy her', 'She gets annoyed by']},
    {'label': '😂 Jokes', 'id': MemoryModel.catJoke, 'sug': ['Inside joke:', 'She always laughs at', 'Funny moment:']},
    {'label': '🥘 Recipes', 'id': MemoryModel.catRecipe, 'sug': ['Her secret ingredient is', 'She makes the best', 'Recipe for']},
  ];

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final customCatsStr = prefs.getString('custom_categories');
    List<Map<String, dynamic>> customCats = [];
    if (customCatsStr != null) {
      final List<dynamic> decoded = jsonDecode(customCatsStr);
      customCats = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    state = [..._defaultCategories, ...customCats];
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
    
    state = [..._defaultCategories, ...customCats];
  }
}

final categoryProvider = StateNotifierProvider<CategoryNotifier, List<Map<String, dynamic>>>((ref) {
  return CategoryNotifier();
});
