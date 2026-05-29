import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_colors.dart';
import '../../models/memory_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/partner_care_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';

class PartnerCareScreen extends ConsumerStatefulWidget {
  const PartnerCareScreen({super.key});

  @override
  ConsumerState<PartnerCareScreen> createState() => _PartnerCareScreenState();
}

class _PartnerCareScreenState extends ConsumerState<PartnerCareScreen> {
  final TextEditingController _captureController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSaving = false;
  bool _loadingInsights = false;
  List<String> _insights = [];
  List<Map<String, String>> _customCategories = [];

  final List<Map<String, String>> _defaultCategories = [
    {'id': 'All', 'label': '✨ All', 'emoji': '✨'},
    {'id': 'food', 'label': '🍕 Food', 'emoji': '🍕'},
    {'id': 'place', 'label': '📍 Places', 'emoji': '📍'},
    {'id': 'gift_idea', 'label': '🎁 Gift Ideas', 'emoji': '🎁'},
    {'id': 'habit', 'label': '😊 Habits', 'emoji': '😊'},
    {'id': 'dislike', 'label': '👎 Dislikes', 'emoji': '👎'},
    {'id': 'dream', 'label': '🌸 Dreams', 'emoji': '🌸'},
    {'id': 'song', 'label': '🎵 Songs', 'emoji': '🎵'},
    {'id': 'joke', 'label': '😂 Jokes', 'emoji': '😂'},
    {'id': 'trigger', 'label': '⚡ Triggers', 'emoji': '⚡'},
  ];

  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    _fetchInsights(silent: true);
  }

  @override
  void dispose() {
    _captureController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('partner_care_custom_cats');
      if (saved != null) {
        final List<dynamic> list = jsonDecode(saved);
        setState(() {
          _customCategories = list.map((e) => Map<String, String>.from(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _addCustomCategoryDialog() async {
    final labelCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '✨');
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E0C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Custom Category',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji Icon',
                labelStyle: TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                labelStyle: TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () async {
              final label = labelCtrl.text.trim();
              final emoji = emojiCtrl.text.trim();
              if (label.isNotEmpty) {
                final newCat = {
                  'id': label.toLowerCase().replaceAll(' ', '_'),
                  'label': '$emoji $label',
                  'emoji': emoji,
                };
                setState(() {
                  _customCategories.add(newCat);
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('partner_care_custom_cats', jsonEncode(_customCategories));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchInsights({bool silent = false}) async {
    if (!silent) setState(() => _loadingInsights = true);
    try {
      final res = await ref.read(partnerCareProvider.notifier).generateInsights();
      if (mounted) {
        setState(() {
          _insights = res;
          _loadingInsights = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInsights = false);
    }
  }

  Future<void> _saveCapture() async {
    final text = _captureController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      // AI auto-categorize note about partner
      final category = await ref.read(partnerCareProvider.notifier).autoCategorizeMemo(text);
      await ref.read(partnerCareProvider.notifier).addMemory(text, category);
      
      _captureController.clear();
      _fetchInsights(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Observed & Saved 💕 (Auto-Category: $category)',
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
            ),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDelete(BuildContext context, String memoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Memory?',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This private partner observation will be permanently deleted.',
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontStyle: FontStyle.normal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: Colors.white54,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFE57373),
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(partnerCareProvider.notifier).deleteMemory(memoryId);
        _fetchInsights(silent: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Memory deleted 💕',
                style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              ),
              backgroundColor: AppColors.rose,
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _showVisibilityDialog(BuildContext context, MemoryModel memory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Change Visibility',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVisibilityOption(ctx, memory, MemoryModel.visPrivate, '🔒 Private (Only Me)'),
            _buildVisibilityOption(ctx, memory, MemoryModel.visPartnerVisible, '👀 Partner can see'),
            _buildVisibilityOption(ctx, memory, MemoryModel.visShared, '🤝 Shared (Scrapbook)'),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(BuildContext context, MemoryModel memory, String val, String title) {
    final isSelected = memory.visibility == val;
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          color: isSelected ? AppColors.rose : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontStyle: FontStyle.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.rose) : null,
      onTap: () async {
        Navigator.pop(context);
        try {
          final sb = Supabase.instance.client;
          await sb.from('memories').update({'visibility': val}).eq('id', memory.id);
          ref.invalidate(partnerCareProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Visibility updated 💕',
                  style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
                ),
                backgroundColor: AppColors.rose,
              ),
            );
          }
        } catch (_) {}
      },
    );
  }

  String _emojiForCat(String cat) {
    switch (cat) {
      case 'food':      return '🍕';
      case 'place':     return '📍';
      case 'gift_idea': return '🎁';
      case 'habit':     return '😊';
      case 'dislike':   return '👎';
      case 'dream':     return '🌸';
      case 'song':      return '🎵';
      case 'joke':      return '😂';
      case 'trigger':   return '⚡';
      case 'craving':   return '🍰';
      default:
        // Try searching in custom categories
        final custom = _customCategories.firstWhere((c) => c['id'] == cat, orElse: () => {});
        return custom['emoji'] ?? '💭';
    }
  }

  @override
  Widget build(BuildContext context) {
    final memoriesState = ref.watch(partnerCareProvider);
    final themeState = ref.watch(themeProvider);
    final tc = themeState.colors;
    final partnerName = ref.watch(coupleProvider).valueOrNull?.partner?.name.split(' ').first ?? 'Her';

    final categories = [..._defaultCategories, ..._customCategories];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0308),
      body: Stack(
        children: [
          // Elegant rose-masculine background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2E0C1C), Color(0xFF13030A), Color(0xFF0A0308)],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Sub Header ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SpaceSubHeader(
                    title: 'Partner Care',
                    gradientColors: const [Color(0xFFE8607A), Color(0xFF9B2647)],
                    onBack: () => context.pop(),
                  ),
                ),

                // ── AI INSIGHTS PANEL (SPOTIFY-WRAPPED STYLE) ────────────────
                if (_insights.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: GlassContainer(
                        blur: 15,
                        tint: Colors.white,
                        tintOpacity: 0.04,
                        borderRadius: 24,
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('🧠', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Partner Care AI Insights',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontStyle: FontStyle.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => _fetchInsights(),
                                    child: _loadingInsights
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose),
                                          )
                                        : const Icon(Icons.refresh, size: 18, color: AppColors.rose),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ..._insights.map((ins) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('🌸', style: TextStyle(fontSize: 12, color: AppColors.rose)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            ins,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontStyle: FontStyle.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),

                // ── QUICK CAPTURE SYSTEM ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: GlassContainer(
                      blur: 15,
                      tint: Colors.white,
                      tintOpacity: 0.05,
                      borderRadius: 24,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QUICK CAPTURE',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white38,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _captureController,
                                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Something she mentioned (e.g. coffee preferences)...',
                                      hintStyle: GoogleFonts.dmSans(color: Colors.white30, fontSize: 13),
                                      border: InputBorder.none,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _isSaving ? null : _saveCapture,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFE8607A), Color(0xFF9B2647)],
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── LIVE FILTER SEARCH BAR ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.dmSans(color: Colors.white),
                        onChanged: (val) {
                          ref.read(partnerCareProvider.notifier).searchMemories(val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search $partnerName\'s profile...',
                          hintStyle: GoogleFonts.dmSans(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── CATEGORIES SLIDER ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == categories.length) {
                          // Plus chip to add custom category
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Icon(Icons.add, color: AppColors.rose, size: 18),
                              selected: false,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) => _addCustomCategoryDialog(),
                            ),
                          );
                        }

                        final cat = categories[index];
                        final isSelected = _selectedCategory == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              cat['label']!,
                              style: GoogleFonts.dmSans(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.rose,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppColors.rose : Colors.white12,
                              ),
                            ),
                            onSelected: (val) {
                              setState(() {
                                _selectedCategory = cat['id']!;
                              });
                              ref.read(partnerCareProvider.notifier).setCategoryFilter(cat['id']!);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── MEMORIES SCRAPBOOK LIST ──────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  sliver: memoriesState.when(
                    loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70)))),
                    data: (_) {
                      final filtered = ref.watch(partnerCareProvider.notifier).filteredMemories;

                      if (filtered.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('💝', style: TextStyle(fontSize: 48)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No observations recorded yet',
                                    style: GoogleFonts.playfairDisplay(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Record what makes her smile in the Quick Capture!',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white30,
                                      fontSize: 12,
                                      fontStyle: FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final m = filtered[index];
                            final emoji = _emojiForCat(m.category);

                            // Detect if AI has an active insight containing keywords from this memory to show badge
                            final hasInsightBadge = _insights.any(
                                (ins) => ins.toLowerCase().contains(m.category.toLowerCase()) || 
                                         ins.toLowerCase().contains(m.content.toLowerCase().split(' ').first));

                            return GestureDetector(
                              onLongPress: () => _showVisibilityDialog(context, m),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: GlassContainer(
                                  blur: 15,
                                  tint: Colors.white,
                                  tintOpacity: 0.04,
                                  borderRadius: 20,
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Emoji bubble
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.06),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(fontSize: 22),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.content,
                                                style: GoogleFonts.dmSans(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w400,
                                                  fontStyle: FontStyle.normal,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    timeago.format(m.createdAt),
                                                    style: GoogleFonts.dmMono(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                      fontStyle: FontStyle.normal,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      if (hasInsightBadge)
                                                        Container(
                                                          margin: const EdgeInsets.only(right: 6),
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.rose.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'AI INSIGHT ✨',
                                                            style: GoogleFonts.dmSans(
                                                              color: AppColors.rose,
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.bold,
                                                              fontStyle: FontStyle.normal,
                                                            ),
                                                          ),
                                                        ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.08),
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Text(
                                                          m.visibility,
                                                          style: GoogleFonts.dmSans(
                                                            color: Colors.white54,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            fontStyle: FontStyle.normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete button on the right
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFC97B93), size: 20),
                                          onPressed: () => _confirmDelete(context, m.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(delay: Duration(milliseconds: index * 40))
                                  .slideY(begin: 0.1, end: 0, delay: Duration(milliseconds: index * 40)),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      );
                    },
                  ),
                ),

                // ── SURPRISE PLANNING SHORTCUT CARD ─────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    child: GestureDetector(
                      onTap: () => context.go('/he-space/surprise'),
                      child: GlassContainer(
                        blur: 15,
                        tint: Colors.white,
                        tintOpacity: 0.05,
                        borderRadius: 24,
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 32)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Planning something special?',
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Draft romantic ideas in your Surprise Planner',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: Colors.white38,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
