import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/app_colors.dart';
import '../../providers/gift_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/v2/space_header.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/rose_button.dart';

class GiftSearchScreen extends ConsumerStatefulWidget {
  const GiftSearchScreen({super.key});

  @override
  ConsumerState<GiftSearchScreen> createState() => _GiftSearchScreenState();
}

class _GiftSearchScreenState extends ConsumerState<GiftSearchScreen> {
  final _searchController = TextEditingController();
  double _budget = 1000;
  
  final List<String> _suggestions = [
    "Silver pendant under ₹500",
    "Cute hoodie for her",
    "Minimalist bracelet",
    "Coffee lover gifts",
    "Something cozy under ₹1000"
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    // Unfocus keyboard
    FocusScope.of(context).unfocus();
    
    ref.read(giftProvider.notifier).searchGifts(query, _budget.toInt());
  }

  Future<void> _launchURL(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;
    final giftState = ref.watch(giftProvider);
    final hasSearched = giftState.query.isNotEmpty || giftState.results.isNotEmpty || giftState.isLoading;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Gift Intelligence 🎁',
              gradientColors: const [Color(0xFFE8607A), Color(0xFFC97B93)],
              onBack: () => context.pop(),
            ),
            
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                            decoration: InputDecoration(
                              hintText: "Describe what you're looking for...",
                              hintStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal),
                              filled: true,
                              fillColor: tc.cardColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.search, color: AppColors.rose),
                            ),
                            onSubmitted: (_) => _search(),
                          ),
                          const SizedBox(height: 16),
                          
                          if (!hasSearched)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _suggestions.map((s) => ActionChip(
                                label: Text(s, style: GoogleFonts.dmSans(fontSize: 12, color: tc.textPrimary, fontStyle: FontStyle.normal)),
                                backgroundColor: tc.cardColor,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onPressed: () {
                                  _searchController.text = s;
                                  _search();
                                },
                              )).toList(),
                            ),
                            
                          const SizedBox(height: 24),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Budget', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: tc.textPrimary, fontStyle: FontStyle.normal)),
                              Text('₹${_budget.toInt()}', style: GoogleFonts.dmMono(fontWeight: FontWeight.bold, color: AppColors.rose, fontStyle: FontStyle.normal)),
                            ],
                          ),
                          Slider(
                            value: _budget,
                            min: 100,
                            max: 10000,
                            divisions: 99,
                            activeColor: AppColors.rose,
                            inactiveColor: tc.cardColor,
                            onChanged: (val) => setState(() => _budget = val),
                          ),
                          
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: RoseButton(
                              label: giftState.isLoading ? 'Searching...' : 'Find Gifts 🎁',
                              onTap: giftState.isLoading ? () {} : _search,
                            ),
                          ),
                          
                          if (giftState.error.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(giftState.error, style: GoogleFonts.dmSans(color: Colors.red, fontStyle: FontStyle.normal)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  if (!hasSearched)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.card_giftcard, size: 80, color: AppColors.rose.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'Tell me what kind of gift\nyou have in mind 🎁',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(fontSize: 16, color: tc.textMuted, fontStyle: FontStyle.normal),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (giftState.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: AppColors.rose),
                            const SizedBox(height: 16),
                            Text(
                              'Searching for the perfect gift...',
                              style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (giftState.results.isEmpty && giftState.error.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "Couldn't find exact matches. Try different keywords.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal),
                          ),
                        ),
                      ),
                    )
                  else if (giftState.results.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == 0) {
                            return _buildPartnerContextBanner(tc);
                          }
                          final product = giftState.results[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
                            child: _buildProductCard(product, tc),
                          );
                        },
                        childCount: giftState.results.length + 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerContextBanner(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Text('💕', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Using her preferences from Partner Care',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.rose, fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(GiftProduct product, ThemeColors tc) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.thumbnail.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: CachedNetworkImage(
                imageUrl: product.thumbnail,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  height: 160,
                  color: tc.cardColor,
                  child: Icon(Icons.image_not_supported, color: tc.textMuted),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: tc.textPrimary, fontStyle: FontStyle.normal),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      product.price.startsWith('₹') ? product.price : '₹${product.price}',
                      style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.rose, fontStyle: FontStyle.normal),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (product.source.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tc.cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.source,
                      style: GoogleFonts.dmSans(fontSize: 10, color: tc.textMuted, fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
                    ),
                  ),
                if (product.emotionalNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    product.emotionalNote,
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.rose, fontStyle: FontStyle.normal),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchURL(product.link),
                        icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.rose),
                        label: Text('View 🔗', style: GoogleFonts.dmSans(color: AppColors.rose, fontStyle: FontStyle.normal)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.rose),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(giftProvider.notifier).saveToWishlist(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved to Theirs wishlist! 💝', style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
                              backgroundColor: AppColors.rose,
                            ),
                          );
                        },
                        icon: const Icon(Icons.favorite, size: 16, color: Colors.white),
                        label: Text('Save 💝', style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rose,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
