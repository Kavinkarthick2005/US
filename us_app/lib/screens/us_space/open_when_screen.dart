import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_colors.dart';
import '../../models/open_when_model.dart';
import '../../providers/open_when_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/v2/space_header.dart';

Color _parseColor(String hexStr) {
  try {
    final hexCode = hexStr.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  } catch (e) {
    return AppColors.rose;
  }
}

class OpenWhenScreen extends ConsumerStatefulWidget {
  const OpenWhenScreen({super.key});
  @override
  ConsumerState<OpenWhenScreen> createState() => _OpenWhenScreenState();
}

class _OpenWhenScreenState extends ConsumerState<OpenWhenScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;
    final asyncLetters = ref.watch(openWhenProvider);

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: Column(
        children: [
          SpaceSubHeader(
            title: 'Open When... 💌',
            gradientColors: const [Color(0xFFE8607A), Color(0xFFC97B93)],
            onBack: () => context.pop(),
          ),
          TabBar(
            controller: _tab,
            labelColor: AppColors.rose,
            unselectedLabelColor: tc.textMuted,
            indicatorColor: AppColors.rose,
            labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'FOR YOU'),
              Tab(text: 'FROM YOU'),
            ],
          ),
          Expanded(
            child: asyncLetters.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Failed to load letters', style: TextStyle(color: tc.textPrimary))),
              data: (_) {
                final notifier = ref.read(openWhenProvider.notifier);
                final forMe = notifier.lettersForMe;
                final myLetters = notifier.myLetters;

                return TabBarView(
                  controller: _tab,
                  children: [
                    _ForYouTab(letters: forMe, tc: tc),
                    _FromYouTab(letters: myLetters, tc: tc),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/us-space/open-when/add'),
        backgroundColor: AppColors.rose,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: Text('Write Letter', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── FOR YOU TAB ─────────────────────────────────────────────────────────────

class _ForYouTab extends StatelessWidget {
  final List<OpenWhenModel> letters;
  final ThemeColors tc;
  const _ForYouTab({required this.letters, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💌', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No letters yet', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: tc.textPrimary)),
            const SizedBox(height: 8),
            Text('Your partner hasn\'t written any letters for you yet', style: GoogleFonts.dmSans(color: tc.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Maybe drop a hint 😊', style: GoogleFonts.dmSans(color: tc.textMuted.withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: letters.length,
      itemBuilder: (ctx, i) => _ForYouLetterCard(letter: letters[i], tc: tc),
    );
  }
}

class _ForYouLetterCard extends ConsumerStatefulWidget {
  final OpenWhenModel letter;
  final ThemeColors tc;
  const _ForYouLetterCard({required this.letter, required this.tc});
  @override
  ConsumerState<_ForYouLetterCard> createState() => _ForYouLetterCardState();
}

class _ForYouLetterCardState extends ConsumerState<_ForYouLetterCard> with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  bool _isRevealed = false;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.letter.isOpened;
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (!_isRevealed) {
      _glowCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _handleOpen() async {
    if (_isRevealed || _isOpening) return;
    setState(() => _isOpening = true);
    
    // Slight delay for spring scale up animation feeling
    await Future.delayed(const Duration(milliseconds: 200));
    
    ref.read(openWhenProvider.notifier).openLetter(widget.letter.id);
    
    setState(() {
      _isRevealed = true;
      _isOpening = false;
    });
    _glowCtrl.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRevealed && !widget.letter.isOpened) {
      // Optimistic update state while opening
    }
    
    final bool alreadyOpened = widget.letter.isOpened;

    if (alreadyOpened) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _LetterContent(letter: widget.letter),
      ).animate().fadeIn(duration: 400.ms);
    }

    if (_isRevealed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _LetterContent(letter: widget.letter),
      ).animate().fadeIn(duration: 400.ms);
    }

    final coverColor = _parseColor(widget.letter.coverColor);

    return GestureDetector(
      onTap: _handleOpen,
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (context, child) {
          final glowOpacity = 0.3 + (_glowCtrl.value * 0.3); // 0.3 to 0.6
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [coverColor.withValues(alpha: 0.7), coverColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: coverColor.withValues(alpha: glowOpacity),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💌', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  widget.letter.triggerLabel,
                  style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to open',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.7), fontStyle: FontStyle.normal),
                ),
              ],
            ),
          ],
        ),
      ).animate(target: _isOpening ? 1 : 0).scale(end: const Offset(1.05, 1.05), curve: Curves.easeOutBack, duration: 200.ms).fadeOut(duration: 300.ms),
    );
  }
}

class _LetterContent extends ConsumerWidget {
  final OpenWhenModel letter;
  const _LetterContent({required this.letter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final partnerName = coupleState?.partner?.name ?? 'your partner';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFAF9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Written for you 💕', style: GoogleFonts.dmSans(color: AppColors.rose, fontWeight: FontWeight.bold, fontSize: 13, fontStyle: FontStyle.normal)),
              if (letter.openedAt != null)
                Text('Opened ${timeago.format(letter.openedAt!)}', style: GoogleFonts.dmSans(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.normal)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            letter.content,
            style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.deep, height: 1.8, fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: 24),
          Text('Written by $partnerName with love 💕', style: GoogleFonts.dmSans(color: AppColors.rose.withValues(alpha: 0.8), fontSize: 12, fontStyle: FontStyle.normal)),
        ],
      ),
    );
  }
}

// ── FROM YOU TAB ────────────────────────────────────────────────────────────

class _FromYouTab extends ConsumerWidget {
  final List<OpenWhenModel> letters;
  final ThemeColors tc;
  const _FromYouTab({required this.letters, required this.tc});

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        title: Text('Delete Letter?', style: GoogleFonts.dmSans(color: tc.textPrimary, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
        content: Text('Are you sure? She hasn\'t read this yet.', style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal))),
          TextButton(
            onPressed: () {
              ref.read(openWhenProvider.notifier).deleteLetter(id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (letters.isEmpty) {
      return Center(
        child: Text('You haven\'t written any letters yet.', style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: letters.length,
      itemBuilder: (ctx, i) {
        final letter = letters[i];
        final preview = letter.content.length > 30 ? '${letter.content.substring(0, 30)}...' : letter.content;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tc.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tc.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      letter.triggerLabel,
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: tc.textPrimary, fontStyle: FontStyle.normal),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: letter.isOpened ? tc.backgroundColor : AppColors.rose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      letter.isOpened ? 'Opened' : 'Sealed 💌',
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: letter.isOpened ? tc.textMuted : AppColors.rose, fontStyle: FontStyle.normal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(preview, style: GoogleFonts.dmSans(color: tc.textMuted, fontSize: 13, fontStyle: FontStyle.normal)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!letter.isOpened)
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref, letter.id),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      label: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontSize: 12, fontStyle: FontStyle.normal)),
                    )
                  else
                    Text('She\'s already read this 💌', style: GoogleFonts.dmSans(color: AppColors.rose, fontSize: 12, fontStyle: FontStyle.normal)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
