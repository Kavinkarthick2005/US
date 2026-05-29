import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../models/memory_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/category_provider.dart';
import '../../utils/pronoun_helper.dart';
import '../../widgets/rose_button.dart';

class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key});

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final TextEditingController _contentController = TextEditingController();

  String? _selectedCategory;
  bool _aboutHer = true; // true = partnerId, false = myId
  bool _isSaving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _onSave() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedCategory == null) return;

    setState(() => _isSaving = true);

    try {
      final coupleState = ref.read(coupleProvider).valueOrNull;
      final myId = coupleState?.currentUser?.id;
      final partnerId = coupleState?.partner?.id;

      if (myId == null) throw Exception('Not authenticated');

      final ownerId = _aboutHer ? (partnerId ?? myId) : myId;

      await ref.read(memoryProvider.notifier).addMemory(
            content:  content,
            category: _selectedCategory!,
            ownerId:  ownerId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Memory saved 💕"),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving memory: $e"),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _contentController.text.trim().isNotEmpty;
    final canSave = hasContent && _selectedCategory != null;
    final tc = ref.watch(themeProvider).colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final pronoun = coupleState?.currentUser?.partnerPronoun ?? 'she';

    final categories = ref.watch(categoryProvider);
    
    List<String> currentSuggestions = [];
    if (_selectedCategory != null) {
      final cat = categories.firstWhere((c) => c['id'] == _selectedCategory, orElse: () => {'label': '💬 General', 'id': 'general', 'sug': []});
      currentSuggestions = List<String>.from(cat['sug']);
      if (!_aboutHer) {
        // Adjust pronouns if it's about "Me"
        currentSuggestions = currentSuggestions.map((s) {
          return s
              .replaceAll('${PronounHelper.subject(pronoun)} ', 'I ')
              .replaceAll('${PronounHelper.possessive(pronoun)} ', 'My ')
              .replaceAll('${PronounHelper.subject(pronoun).toLowerCase()} ', 'I ')
              .replaceAll('${PronounHelper.possessive(pronoun).toLowerCase()} ', 'my ')
              .replaceAll('${PronounHelper.object(pronoun).toLowerCase()} ', 'me ');
        }).toList();
      }
    }

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: tc.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add a Memory',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CATEGORY ──────────────────────────────────────────────────
              Text(
                'Category',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat['id'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? tc.iconColor : tc.cardColor,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? tc.iconColor : tc.borderColor,
                        ),
                      ),
                      child: Text(
                        cat['label'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: isSelected ? Colors.white : tc.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // ── WHO IS THIS ABOUT ──────────────────────────────────────────
              Text(
                'Who is this about?',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: tc.cardColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: tc.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _aboutHer = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                _aboutHer ? tc.iconColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'About ${PronounHelper.object(pronoun).substring(0,1).toUpperCase()}${PronounHelper.object(pronoun).substring(1)}',
                            style: GoogleFonts.dmSans(
                              fontWeight:
                                  _aboutHer ? FontWeight.w600 : FontWeight.w500,
                              color: _aboutHer ? Colors.white : tc.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _aboutHer = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_aboutHer
                                ? tc.iconColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'About Me',
                            style: GoogleFonts.dmSans(
                              fontWeight: !_aboutHer
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color:
                                  !_aboutHer ? Colors.white : tc.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── TEXT FIELD ─────────────────────────────────────────────────
              TextField(
                controller: _contentController,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: tc.textPrimary,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'What do you want to remember?',
                  hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                  fillColor: tc.inputFillColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: tc.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: tc.iconColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: tc.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── QUICK SUGGESTIONS ──────────────────────────────────────────
              if (currentSuggestions.isNotEmpty) ...[
                Text(
                  'Quick suggestions:',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: tc.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: currentSuggestions.map((sug) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _contentController.text = sug +
                              (_contentController.text.isNotEmpty
                                  ? ' ${_contentController.text}'
                                  : '');
                          _contentController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                                offset: _contentController.text.length),
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: tc.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: tc.iconColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          sug,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: tc.iconColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
 
              const SizedBox(height: 48),

              // ── SAVE BUTTON ────────────────────────────────────────────────
              RoseButton(
                label: 'Save Memory',
                isLoading: _isSaving,
                onTap: canSave ? _onSave : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
