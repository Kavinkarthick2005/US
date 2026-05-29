import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/env.dart';
import '../models/wishlist_model.dart';
import 'couple_provider.dart';
import 'memory_provider.dart';
import 'wishlist_provider.dart';

class GiftProduct {
  final String title;
  final String price;
  final String link;
  final String thumbnail;
  final String source;
  final String emotionalNote;

  GiftProduct({
    required this.title,
    required this.price,
    required this.link,
    required this.thumbnail,
    required this.source,
    required this.emotionalNote,
  });

  factory GiftProduct.fromJson(Map<String, dynamic> json) {
    return GiftProduct(
      title: json['title'] ?? '',
      price: json['price'] ?? '',
      link: json['link'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      source: json['source'] ?? '',
      emotionalNote: json['emotional_note'] ?? '',
    );
  }
}

class GiftState {
  final List<GiftProduct> results;
  final bool isLoading;
  final String query;
  final String error;

  GiftState({
    this.results = const [],
    this.isLoading = false,
    this.query = '',
    this.error = '',
  });

  GiftState copyWith({
    List<GiftProduct>? results,
    bool? isLoading,
    String? query,
    String? error,
  }) {
    return GiftState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }
}

class GiftNotifier extends StateNotifier<GiftState> {
  final Ref ref;

  GiftNotifier(this.ref) : super(GiftState());

  Future<void> searchGifts(String query, int budget) async {
    if (Env.giftApiUrl == 'YOUR_RENDER_URL' || Env.giftApiUrl.isEmpty) {
      state = state.copyWith(error: 'API URL not configured. Please deploy to Render and update env.dart.', isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, query: query, error: '');

    try {
      // Gather partner context
      final memoriesState = ref.read(memoryProvider);
      String partnerContext = '';
      if (memoriesState is AsyncData) {
        final memories = memoriesState.value ?? [];
        final partnerCareMemories = memories.where((m) => m.isPartnerCare).take(5).toList();
        partnerContext = partnerCareMemories.map((m) => '- ${m.content}').join('\n');
      }

      final uri = Uri.parse('${Env.giftApiUrl}/search-gifts');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'budget': budget,
          'currency': 'INR',
          'partner_context': partnerContext,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> productsJson = data['products'] ?? [];
        final products = productsJson.map((p) => GiftProduct.fromJson(p)).toList();
        
        state = state.copyWith(
          results: products,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          error: 'Failed to find gifts. Server returned ${response.statusCode}.',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: 'An error occurred while searching: $e',
        isLoading: false,
      );
    }
  }

  void saveToWishlist(GiftProduct product) {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final coupleId = coupleState?.coupleId ?? myId;

    final item = WishlistModel(
      id: const Uuid().v4(),
      coupleId: coupleId,
      addedBy: myId,
      title: product.title,
      type: WishlistModel.typeBuy,
      price: double.tryParse(product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
      link: product.link,
      visibility: 'theirs',
      emotionalTag: 'surprise',
      imageUrl: product.thumbnail,
      isDone: false,
      createdAt: DateTime.now(),
    );

    ref.read(wishlistProvider.notifier).addItem(item);
  }
}

final giftProvider = StateNotifierProvider<GiftNotifier, GiftState>((ref) {
  return GiftNotifier(ref);
});
