import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_colors.dart';
import '../../models/memory_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/category_provider.dart';
import '../../utils/pronoun_helper.dart';
import '../../widgets/couple_avatar.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/empty_state.dart';
import 'package:flutter/services.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  String _selectedCategoryId = 'All';

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end:   const Offset(0, 0.1),
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(memoryProvider.notifier).searchMemories(query);
  }

  void _onCategorySelected(String id) {
    setState(() => _selectedCategoryId = id);
    ref.read(memoryProvider.notifier).setCategoryFilter(id);
  }

  void _confirmDelete(String id, ThemeColors tc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Memory?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold, color: tc.textPrimary)),
        content: Text(
            'Are you sure you want to permanently remove this memory?',
            style: GoogleFonts.dmSans(color: tc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              ref.read(memoryProvider.notifier).deleteMemory(id);
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmHide(String id, ThemeColors tc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hide Memory?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold, color: tc.textPrimary)),
        content: Text(
            'This memory will be hidden from your list. You can unhide it later from settings.',
            style: GoogleFonts.dmSans(color: tc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose.withValues(alpha: 0.8)),
            onPressed: () {
              ref.read(memoryProvider.notifier).hideMemory(id);
              Navigator.pop(ctx);
            },
            child: Text('Hide',
                style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(ThemeColors tc) {
    final emojiCtrl = TextEditingController(text: '✨');
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        title: Text('New Category', style: GoogleFonts.dmSans(color: tc.textPrimary, fontWeight: FontWeight.bold)),
        content: Row(
          children: [
            SizedBox(
              width: 50,
              child: TextField(
                controller: emojiCtrl,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  hintText: '😊',
                  filled: true,
                  fillColor: tc.inputFillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                style: GoogleFonts.dmSans(color: tc.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Category Name',
                  hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                  filled: true,
                  fillColor: tc.inputFillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tc.iconColor),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(categoryProvider.notifier).addCustomCategory(nameCtrl.text.trim(), emojiCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc               = ref.watch(themeProvider).colors;
    final memoryState      = ref.watch(memoryProvider);
    final filteredMemories = ref.read(memoryProvider.notifier).filteredMemories;
    final coupleState      = ref.watch(coupleProvider).valueOrNull;
    final pronoun          = coupleState?.currentUser?.partnerPronoun ?? 'she';

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.rose,
        onPressed: () => context.go('/memory/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: tc.textPrimary, size: 20),
                        onPressed: () => context.go('/home'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        PronounHelper.world(pronoun),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  CoupleAvatar(
                    myAvatarUrl:      coupleState?.currentUser?.avatarUrl,
                    partnerAvatarUrl: coupleState?.partner?.avatarUrl,
                    size: 40,
                  ),
                ],
              ),
            ),

            // ── SEARCH BAR ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged:  _onSearchChanged,
                style: GoogleFonts.dmSans(color: tc.textPrimary),
                decoration: InputDecoration(
                  hintText:  'Search memories...',
                  hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                  prefixIcon: Icon(Icons.search, color: tc.iconColor),
                  filled:     true,
                  fillColor:  tc.inputFillColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide:
                        BorderSide(color: tc.borderColor, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide:
                        BorderSide(color: tc.iconColor, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── CATEGORY CHIPS ───────────────────────────────────────────────
            SizedBox(
              height: 40,
              child: Consumer(
                builder: (context, ref, child) {
                  final categories = [{'label': 'All', 'id': 'All', 'sug': []}, ...ref.watch(categoryProvider)];
                  return ListView.separated(
                    padding:            const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection:    Axis.horizontal,
                    itemCount:          categories.length + 1,
                    separatorBuilder:   (ctx, i) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      if (i == categories.length) {
                        return GestureDetector(
                          onTap: () => _showAddCategoryDialog(tc),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: tc.iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+ New',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: tc.iconColor,
                              ),
                            ),
                          ),
                        );
                      }

                      final cat        = categories[i];
                      final isSelected = _selectedCategoryId == cat['id'];
                      return GestureDetector(
                        onTap: () => _onCategorySelected(cat['id'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tc.iconColor
                                : tc.iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat['label'] as String,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : tc.iconColor,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
            ),
            const SizedBox(height: 16),

            // ── MEMORY LIST ──────────────────────────────────────────────────
            Expanded(
              child: memoryState.when(
                data: (_) {
                  if (filteredMemories.isEmpty) {
                    return EmptyState(
                      emoji: '🧠',
                      title: 'Nothing saved yet',
                      subtitle: 'Start saving what makes ${PronounHelper.object(pronoun).toLowerCase()}, ${PronounHelper.object(pronoun).toLowerCase()}. 💕',
                      textColor: tc.textPrimary,
                      subtitleColor: tc.textMuted,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    itemCount: filteredMemories.length,
                    itemBuilder: (context, index) {
                      final m = filteredMemories[index];
                      final categories = ref.read(categoryProvider);
                      final catObj = categories.firstWhere(
                        (c) => c['id'] == m.category,
                        orElse: () => {'label': '💬 General', 'id': 'general', 'sug': []},
                      );
                      final emoji = (catObj['label'] as String).split(' ').first;

                      return GestureDetector(
                        onLongPress: () => _confirmDelete(m.id, tc),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tc.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tc.borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: tc.iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: tc.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        timeago.format(m.createdAt),
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: tc.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Action buttons: hide + delete
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.start,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.visibility_off_rounded,
                                        size: 18),
                                    color: tc.textMuted,
                                    tooltip: 'Hide',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () =>
                                        _confirmHide(m.id, tc),
                                  ),
                                  const SizedBox(height: 4),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_rounded,
                                        size: 18),
                                    color: AppColors.rose,
                                    tooltip: 'Delete',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () =>
                                        _confirmDelete(m.id, tc),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: ShimmerList(itemCount: 4, itemHeight: 120),
                ),
                error: (e, st) => GenericErrorState(
                  message: 'Failed to load memories.',
                  onRetry: () => ref.invalidate(memoryProvider),
                  textColor: tc.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
