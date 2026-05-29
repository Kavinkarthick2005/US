import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';

class HePrivateNote {
  final String id;
  final String title;
  final String content;
  bool isPinned;
  final DateTime createdAt;

  HePrivateNote({
    required this.id,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.createdAt,
  });

  factory HePrivateNote.fromJson(Map<String, dynamic> json) => HePrivateNote(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
      };
}

class HeNotesScreen extends ConsumerStatefulWidget {
  const HeNotesScreen({super.key});

  @override
  ConsumerState<HeNotesScreen> createState() => _HeNotesScreenState();
}

class _HeNotesScreenState extends ConsumerState<HeNotesScreen> {
  static const String _prefsKey = 'he_private_notes';
  static const List<Color> _heGradient = [
    Color(0xFFE8607A),
    Color(0xFF9B2647),
  ];

  List<HePrivateNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final List<dynamic> jsonList = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _notes = jsonList
                .map((e) => HePrivateNote.fromJson(e as Map<String, dynamic>))
                .toList();
            _sortNotes();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned == b.isPinned) {
        return b.createdAt.compareTo(a.createdAt);
      }
      return a.isPinned ? -1 : 1;
    });
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_notes.map((n) => n.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _addNote(String title, String content) {
    final note = HePrivateNote(
      id: const Uuid().v4(),
      title: title,
      content: content,
      isPinned: false,
      createdAt: DateTime.now(),
    );
    setState(() {
      _notes.insert(0, note);
      _sortNotes();
    });
    _saveNotes();
  }

  void _togglePin(String id) {
    setState(() {
      final note = _notes.firstWhere((n) => n.id == id);
      note.isPinned = !note.isPinned;
      _sortNotes();
    });
    _saveNotes();
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
    });
    _saveNotes();
  }

  void _showAddBottomSheet() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF160A0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFFE8607A), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Private Note 🔒',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  Text(
                    'He Space Only',
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: const Color(0xFFE8607A),
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
                decoration: InputDecoration(
                  hintText: 'Note Title',
                  hintStyle: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontStyle: FontStyle.normal,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 5,
                style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
                decoration: InputDecoration(
                  hintText: 'Type your private thoughts here...',
                  hintStyle: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontStyle: FontStyle.normal,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();
                        if (content.isEmpty) return;
                        _addNote(
                          title.isEmpty ? 'Untitled Note' : title,
                          content,
                        );
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8607A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Save Note',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final tc = themeState.colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBottomSheet,
        backgroundColor: const Color(0xFFE8607A),
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.edit_note_rounded, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Private Notes',
              gradientColors: _heGradient,
              onBack: () => Navigator.of(context).pop(),
              action: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🔒 Private',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 350.ms),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8607A),
                      ),
                    )
                  : _notes.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _notes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final note = _notes[index];
                            return _NoteTile(
                              note: note,
                              colors: tc,
                              onTogglePin: () => _togglePin(note.id),
                              onDismissed: () => _deleteNote(note.id),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            'Keep your private notes',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'A completely private notepad. Only accessible on your device in your He Space.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddBottomSheet,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Add Note',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.normal,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8607A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.colors,
    required this.onTogglePin,
    required this.onDismissed,
  });

  final HePrivateNote note;
  final ThemeColors colors;
  final VoidCallback onTogglePin;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(note.createdAt);

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: note.isPinned
                ? const Color(0xFFE8607A).withValues(alpha: 0.35)
                : colors.borderColor,
            width: note.isPinned ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onTogglePin,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: note.isPinned ? const Color(0xFFE8607A) : Colors.white24,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.45,
                fontStyle: FontStyle.normal,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.25),
                    fontStyle: FontStyle.normal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 10, color: Color(0xFFE8607A)),
                      const SizedBox(width: 4),
                      Text(
                        'Private',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE8607A),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
