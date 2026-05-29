import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/journal_entry_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';
import '../../widgets/v2/visibility_badge.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  static const List<Color> _sheGradient = [
    Color(0xFFC97B93),
    Color(0xFFE8A0B4),
  ];

  static const List<String> _emotions = ['😊', '😔', '😤', '😴', '🥰'];

  void _showAddEntrySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEntrySheet(
        sheGradient: _sheGradient,
        emotions: _emotions,
        onSave: (title, content, emotion, visibility) async {
          try {
            await ref.read(journalProvider.notifier).addEntry(
                  title: title,
                  content: content,
                  mood: emotion,
                  visibility: visibility,
                );
          } catch (_) {}
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    final journalAsync = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEntrySheet,
        backgroundColor: const Color(0xFFC97B93),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.edit_note_rounded, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Journal & Reflections',
              gradientColors: _sheGradient,
              onBack: () => Navigator.of(context).pop(),
            ).animate().fadeIn(duration: 350.ms),
            Expanded(
              child: journalAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return _EmptyState(
                      onAdd: _showAddEntrySheet,
                      colors: colors,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      return _JournalCard(
                        entry: item,
                        colors: colors,
                        onPin: () => ref.read(journalProvider.notifier).togglePin(item.id),
                        onDelete: () => _confirmDelete(item.id),
                        delay: Duration(milliseconds: 60 * index),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC97B93)),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load journal reflections 😔',
                    style: GoogleFonts.dmSans(
                      color: colors.textMuted,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160A0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete entry?',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.dmSans(color: Colors.white54, fontStyle: FontStyle.normal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(journalProvider.notifier).deleteEntry(id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8607A)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.entry,
    required this.colors,
    required this.onPin,
    required this.onDelete,
    required this.delay,
  });

  final JournalEntryModel entry;
  final ThemeColors colors;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy • h:mm a').format(entry.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isPinned
              ? const Color(0xFFC97B93).withValues(alpha: 0.5)
              : const Color(0xFFC97B93).withValues(alpha: 0.15),
          width: entry.isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC97B93).withValues(alpha: entry.isPinned ? 0.12 : 0.04),
            blurRadius: entry.isPinned ? 16 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (entry.mood != null && entry.mood!.isNotEmpty) ...[
                Text(entry.mood!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.title ?? 'Untitled Reflection',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onPin,
                icon: Icon(
                  entry.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 16,
                  color: entry.isPinned ? const Color(0xFFC97B93) : Colors.white30,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.content,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: colors.textMuted,
              height: 1.4,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: Colors.white24,
                  fontStyle: FontStyle.normal,
                ),
              ),
              VisibilityBadge(visibility: entry.visibility, compact: true),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.12, end: 0);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.colors});

  final VoidCallback onAdd;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📓', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 16),
          Text(
            'Your private emotional space 📓',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              fontStyle: FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Keep it completely private or share logs with him.',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: colors.textMuted,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(
              'Write Entry',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.normal,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC97B93),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({
    required this.sheGradient,
    required this.emotions,
    required this.onSave,
  });

  final List<Color> sheGradient;
  final List<String> emotions;
  final Future<void> Function(String title, String content, String emotion, String visibility) onSave;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _selectedEmotion = '😊';
  String _selectedVisibility = 'private';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF160A0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'New Journal Entry',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 16),
          // Emotion row
          Row(
            children: widget.emotions.map((e) {
              final selected = _selectedEmotion == e;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmotion = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFC97B93).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? const Color(0xFFC97B93) : Colors.white10,
                      width: 1.5,
                    ),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
            decoration: InputDecoration(
              hintText: 'Title (optional)',
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white30,
                fontStyle: FontStyle.normal,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentCtrl,
            maxLines: 5,
            style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
            decoration: InputDecoration(
              hintText: 'Write your heart out...',
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white30,
                fontStyle: FontStyle.normal,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          // Visibility selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👁️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    dropdownColor: const Color(0xFF160A0D),
                    value: _selectedVisibility,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white30, size: 16),
                    style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                    items: const [
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                      DropdownMenuItem(value: 'partner_visible', child: Text('For Him')),
                      DropdownMenuItem(value: 'shared', child: Text('Shared')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedVisibility = v);
                      }
                    },
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final title = _titleCtrl.text.trim();
                        final content = _contentCtrl.text.trim();
                        if (content.isEmpty) return;
                        setState(() => _saving = true);
                        await widget.onSave(title, content, _selectedEmotion, _selectedVisibility);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC97B93),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Save Entry',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
