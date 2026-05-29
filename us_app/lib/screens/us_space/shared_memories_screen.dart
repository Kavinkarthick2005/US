import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../models/memory_model.dart';
import '../../providers/memory_provider.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';

class SharedMemoriesScreen extends ConsumerStatefulWidget {
  const SharedMemoriesScreen({super.key});

  @override
  ConsumerState<SharedMemoriesScreen> createState() => _SharedMemoriesScreenState();
}

class _SharedMemoriesScreenState extends ConsumerState<SharedMemoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<Map<String, String>> _categories = [
    {'id': 'All', 'label': '✨ All'},
    {'id': MemoryModel.catFood, 'label': '🍕 Food'},
    {'id': MemoryModel.catPlace, 'label': '📍 Places'},
    {'id': MemoryModel.catHabit, 'label': '😊 Habits'},
    {'id': MemoryModel.catDislike, 'label': '👎 Dislikes'},
    {'id': MemoryModel.catJoke, 'label': '😂 Jokes'},
    {'id': MemoryModel.catRecipe, 'label': '🍳 Recipes'},
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          'This memory will be removed from your shared scrapbook.',
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
        await ref.read(memoryProvider.notifier).deleteMemory(memoryId);
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
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not delete memory. Try again.',
                style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              ),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
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
            _buildVisibilityOption(ctx, memory, MemoryModel.visPrivate, 'Private (Only Me)'),
            _buildVisibilityOption(ctx, memory, MemoryModel.visPartnerVisible, 'Partner Visible'),
            _buildVisibilityOption(ctx, memory, MemoryModel.visShared, 'Shared (Scrapbook)'),
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
          ref.invalidate(memoryProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Visibility updated to $title 💕',
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

  @override
  Widget build(BuildContext context) {
    final memoriesState = ref.watch(memoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/he-space/partner-care/add'),
        backgroundColor: AppColors.rose,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Rose-Mauve gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A0A0F), Color(0xFF3D1525)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SpaceSubHeader(
                  title: 'Shared Memories',
                  gradientColors: const [Color(0xFF1A0A0F), Color(0xFF3D1525)],
                  onBack: () => context.pop(),
                ),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.dmSans(color: Colors.white),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search shared memories...',
                        hintStyle: GoogleFonts.dmSans(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                // Category Filter Chips
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
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
                          backgroundColor: Colors.white.withOpacity(0.08),
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
                          },
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: memoriesState.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'Error loading memories: $e',
                        style: GoogleFonts.dmSans(color: Colors.white70),
                      ),
                    ),
                    data: (memories) {
                      // Filter shared only
                      final sharedList = memories.where((m) => m.visibility == 'shared').toList();

                      // Apply search query and category filters
                      final filtered = sharedList.where((m) {
                        final matchesSearch = m.content.toLowerCase().contains(_searchQuery);
                        final matchesCat = _selectedCategory == 'All' || m.category == _selectedCategory;
                        return matchesSearch && matchesCat;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('💭', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 16),
                              Text(
                                'No shared memories found',
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to save your first memory!',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          final emoji = MemoryModel.categoryEmoji(m.category);
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
                                      // Emoji block
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
                                                  DateFormat('MMM d, yyyy').format(m.createdAt),
                                                  style: GoogleFonts.dmMono(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.normal,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.rose.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    'shared',
                                                    style: GoogleFonts.dmSans(
                                                      color: AppColors.rose,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      fontStyle: FontStyle.normal,
                                                    ),
                                                  ),
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
                                .fadeIn(delay: Duration(milliseconds: index * 60))
                                .slideY(begin: 0.1, end: 0, delay: Duration(milliseconds: index * 60)),
                          );
                        },
                      );
                    },
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
