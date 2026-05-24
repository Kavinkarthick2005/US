import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_colors.dart';
import '../../models/note_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/rose_button.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddNoteSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final tc = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: tc.textPrimary,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Notes 📝',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: tc.iconColor,
            onPressed: () => _openAddSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: Text('Failed to load notes',
                style: TextStyle(color: tc.textPrimary))),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('No notes yet',
                      style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first note',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: tc.textMuted)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final note = notes[index];
              return Dismissible(
                key: Key(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                onDismissed: (_) {
                  ref.read(notesProvider.notifier).deleteNote(note.id);
                },
                child: _NoteCard(note: note, tc: tc),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        backgroundColor: tc.iconColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.tc});
  final NoteModel note;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: tc.cardColor,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                      note.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      color: tc.iconColor),
                  title: Text(note.isPinned ? 'Unpin Note' : 'Pin Note',
                      style: GoogleFonts.dmSans(color: tc.textPrimary)),
                  onTap: () {
                    ref.read(notesProvider.notifier).togglePin(note);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: Text('Delete Note',
                      style: GoogleFonts.dmSans(color: Colors.redAccent)),
                  onTap: () {
                    ref.read(notesProvider.notifier).deleteNote(note.id);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: note.isPinned ? tc.iconColor : tc.borderColor,
              width: note.isPinned ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                if (note.isPinned)
                  Icon(Icons.push_pin_rounded, size: 16, color: tc.iconColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: tc.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat.yMMMd().add_jm().format(note.createdAt),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet();

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(ThemeColors tc) async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final coupleState = ref.read(coupleProvider).valueOrNull;
      final myId = coupleState?.currentUser?.id;
      if (myId == null) throw Exception('Not authenticated');
      final coupleId = coupleState?.coupleId ?? myId;

      final note = NoteModel(
        id: const Uuid().v4(),
        coupleId: coupleId,
        addedBy: myId,
        title: title,
        content: content,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      await ref.read(notesProvider.notifier).addNote(note);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;

    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'New Note',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.dmSans(color: tc.textPrimary),
              decoration: InputDecoration(
                hintText: 'Title...',
                hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                filled: true,
                fillColor: tc.inputFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentCtrl,
              style: GoogleFonts.dmSans(color: tc.textPrimary),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Note content...',
                hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                filled: true,
                fillColor: tc.inputFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            RoseButton(
              label: 'Save Note',
              isLoading: _isSaving,
              onTap: () => _save(tc),
            ),
          ],
        ),
      ),
    );
  }
}
