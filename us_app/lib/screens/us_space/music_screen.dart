import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_colors.dart';
import '../../models/song_model.dart';
import '../../models/memory_model.dart';
import '../../providers/music_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/v2/space_header.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/rose_button.dart';

Color _parseColor(String hexStr) {
  try {
    final hexCode = hexStr.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  } catch (e) {
    return AppColors.rose;
  }
}

Future<void> _launchUrl(String? url, String platform, String title, String artist) async {
  String targetUrl = url ?? '';
  
  if (targetUrl.isEmpty) {
    final query = Uri.encodeComponent('$title $artist');
    if (platform == 'spotify') {
      targetUrl = 'https://open.spotify.com/search/$query';
    } else if (platform == 'youtube') {
      targetUrl = 'https://www.youtube.com/results?search_query=$query';
    } else if (platform == 'apple') {
      targetUrl = 'https://music.apple.com/us/search?term=$query';
    }
  }

  final uri = Uri.tryParse(targetUrl);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});
  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  String _selectedCategory = 'our_songs';

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;
    final asyncSongs = ref.watch(musicProvider);

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Our Soundtrack 🎵',
              gradientColors: const [Color(0xFFE8607A), Color(0xFFC97B93)],
              onBack: () => context.pop(),
            ),
            
            Expanded(
              child: asyncSongs.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Failed to load music', style: TextStyle(color: tc.textPrimary))),
                data: (songs) {
                  final recentSong = songs.isNotEmpty ? songs.first : null;
                  final filteredSongs = songs.where((s) => s.category == _selectedCategory).toList();

                  return CustomScrollView(
                    slivers: [
                      if (recentSong != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _FeaturedSongCard(song: recentSong, tc: tc),
                          ),
                        ),
                      
                      SliverToBoxAdapter(
                        child: _CategorySelector(
                          selectedCategory: _selectedCategory,
                          onSelect: (cat) => setState(() => _selectedCategory = cat),
                          tc: tc,
                        ),
                      ),

                      if (filteredSongs.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 48.0),
                            child: Center(
                              child: Text('No songs in this category yet.', style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _SongListItem(song: filteredSongs[i], tc: tc),
                            childCount: filteredSongs.length,
                          ),
                        ),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 100)), // padding for FAB
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSongSheet(context),
        backgroundColor: AppColors.rose,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddSongSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddSongSheet(),
    );
  }
}

// ── FEATURED SONG CARD ──────────────────────────────────────────────────────

class _FeaturedSongCard extends StatelessWidget {
  final SongModel song;
  final ThemeColors tc;

  const _FeaturedSongCard({required this.song, required this.tc});

  @override
  Widget build(BuildContext context) {
    final catData = SongModel.predefinedCategories.firstWhere((c) => c['id'] == song.category, orElse: () => SongModel.predefinedCategories.first);
    final color = _parseColor(catData['color'] as String);

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.7), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Center(child: Icon(Icons.music_note, color: Colors.white, size: 36)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Now in our playlist', style: GoogleFonts.dmSans(fontSize: 11, color: tc.textMuted, fontStyle: FontStyle.normal)),
                  const SizedBox(height: 4),
                  Text(song.title, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deep, fontStyle: FontStyle.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song.artist, style: GoogleFonts.dmSans(fontSize: 14, color: tc.textMuted, fontStyle: FontStyle.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (song.album != null && song.album!.isNotEmpty)
                    Text(song.album!, style: GoogleFonts.dmSans(fontSize: 12, color: tc.textMuted, fontStyle: FontStyle.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      _PlatformPill(emoji: '🟢', label: 'Spotify', onTap: () => _launchUrl(song.spotifyUrl, 'spotify', song.title, song.artist)),
                      const SizedBox(width: 8),
                      _PlatformPill(emoji: '▶️', label: 'YouTube', onTap: () => _launchUrl(song.youtubeUrl, 'youtube', song.title, song.artist)),
                      const SizedBox(width: 8),
                      _PlatformPill(emoji: '🍎', label: 'Apple', onTap: () => _launchUrl(song.appleMusicUrl, 'apple', song.title, song.artist)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _PlatformPill({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.deep, fontStyle: FontStyle.normal)),
          ],
        ),
      ),
    );
  }
}

// ── CATEGORY SELECTOR ───────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onSelect;
  final ThemeColors tc;

  const _CategorySelector({required this.selectedCategory, required this.onSelect, required this.tc});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: SongModel.predefinedCategories.map((cat) {
          final isSelected = cat['id'] == selectedCategory;
          final color = _parseColor(cat['color'] as String);
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                cat['label'] as String,
                style: GoogleFonts.dmSans(color: isSelected ? Colors.white : tc.textMuted, fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
              ),
              selected: isSelected,
              selectedColor: color,
              backgroundColor: tc.cardColor,
              onSelected: (val) { if (val) onSelect(cat['id'] as String); },
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── SONG LIST ITEM ──────────────────────────────────────────────────────────

class _SongListItem extends ConsumerWidget {
  final SongModel song;
  final ThemeColors tc;

  const _SongListItem({required this.song, required this.tc});

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: Text('Share song info', style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share('Listening to ${song.title} by ${song.artist} 🎵');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.rose),
              title: Text('Attach to memory', style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
              onTap: () {
                Navigator.pop(ctx);
                _showMemoryPicker(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
              onTap: () {
                ref.read(musicProvider.notifier).deleteSong(song.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMemoryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemoryPickerSheet(songId: song.id, currentMemoryId: song.memoryId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catData = SongModel.predefinedCategories.firstWhere((c) => c['id'] == song.category, orElse: () => SongModel.predefinedCategories.first);
    final color = _parseColor(catData['color'] as String);

    return InkWell(
      onLongPress: () => _showMenu(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                  ),
                  child: const Center(child: Icon(Icons.music_note, color: Colors.white, size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: tc.textPrimary, fontSize: 16, fontStyle: FontStyle.normal)),
                      Text(song.artist, style: GoogleFonts.dmSans(color: tc.textMuted, fontSize: 13, fontStyle: FontStyle.normal)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Text('🟢', style: TextStyle(fontSize: 16)),
                  onPressed: () => _launchUrl(song.spotifyUrl, 'spotify', song.title, song.artist),
                  constraints: const BoxConstraints(), padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Text('▶️', style: TextStyle(fontSize: 16)),
                  onPressed: () => _launchUrl(song.youtubeUrl, 'youtube', song.title, song.artist),
                  constraints: const BoxConstraints(), padding: const EdgeInsets.all(4),
                ),
              ],
            ),
            if (song.memoryId != null) ...[
              const SizedBox(height: 8),
              _MemoryAttachmentChip(memoryId: song.memoryId!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryAttachmentChip extends ConsumerWidget {
  final String memoryId;
  const _MemoryAttachmentChip({required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMemories = ref.watch(memoryProvider);
    return asyncMemories.maybeWhen(
      data: (memories) {
        final mem = memories.firstWhere((m) => m.id == memoryId, orElse: () => memories.first); // Mock fallback if not found
        if (mem.id != memoryId) return const SizedBox.shrink(); // Truly not found
        final preview = mem.content.length > 30 ? '${mem.content.substring(0, 30)}...' : mem.content;
        return Container(
          margin: const EdgeInsets.only(left: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Text('💭 $preview', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.rose, fontStyle: FontStyle.normal)),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ── MEMORY PICKER SHEET ─────────────────────────────────────────────────────

class _MemoryPickerSheet extends ConsumerStatefulWidget {
  final String songId;
  final String? currentMemoryId;

  const _MemoryPickerSheet({required this.songId, this.currentMemoryId});

  @override
  ConsumerState<_MemoryPickerSheet> createState() => _MemoryPickerSheetState();
}

class _MemoryPickerSheetState extends ConsumerState<_MemoryPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;
    final asyncMemories = ref.watch(memoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: tc.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
              decoration: InputDecoration(
                hintText: 'Search memories...',
                hintStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal),
                prefixIcon: Icon(Icons.search, color: tc.textMuted),
                filled: true,
                fillColor: tc.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (widget.currentMemoryId != null)
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: Text('Remove attachment', style: GoogleFonts.dmSans(color: Colors.red, fontStyle: FontStyle.normal)),
              onTap: () {
                ref.read(musicProvider.notifier).removeMemoryAttachment(widget.songId);
                Navigator.pop(context);
              },
            ),
          const Divider(),
          Expanded(
            child: asyncMemories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(child: Text('Failed to load memories')),
              data: (memories) {
                final sharedMemories = memories.where((m) => m.visibility == 'shared' && m.content.toLowerCase().contains(_searchQuery.toLowerCase())).take(20).toList();
                
                if (sharedMemories.isEmpty) {
                  return Center(child: Text('No memories found.', style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)));
                }

                return ListView.builder(
                  itemCount: sharedMemories.length,
                  itemBuilder: (ctx, i) {
                    final mem = sharedMemories[i];
                    return ListTile(
                      leading: Text(MemoryModel.categoryEmoji(mem.category), style: const TextStyle(fontSize: 24)),
                      title: Text(mem.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal)),
                      subtitle: Text(mem.createdAt.toLocal().toString().split(' ')[0], style: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
                      onTap: () {
                        ref.read(musicProvider.notifier).attachToMemory(widget.songId, mem.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── ADD SONG SHEET ──────────────────────────────────────────────────────────

class _AddSongSheet extends ConsumerStatefulWidget {
  const _AddSongSheet();
  @override
  ConsumerState<_AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends ConsumerState<_AddSongSheet> {
  String _selectedCategory = 'our_songs';
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _spotifyCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _appleCtrl = TextEditingController();

  bool _showUrls = false;

  void _save() {
    if (_titleCtrl.text.trim().isEmpty || _artistCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and artist are required')));
      return;
    }
    
    ref.read(musicProvider.notifier).addSong(
      title: _titleCtrl.text.trim(),
      artist: _artistCtrl.text.trim(),
      category: _selectedCategory,
      notes: _notesCtrl.text.trim(),
      spotifyUrl: _spotifyCtrl.text.trim(),
      youtubeUrl: _youtubeCtrl.text.trim(),
      appleMusicUrl: _appleCtrl.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: tc.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Song 🎵', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: tc.textPrimary, fontStyle: FontStyle.normal)),
              const SizedBox(height: 16),
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SongModel.predefinedCategories.map((cat) {
                    final isSelected = cat['id'] == _selectedCategory;
                    final color = _parseColor(cat['color'] as String);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat['label'] as String, style: GoogleFonts.dmSans(color: isSelected ? Colors.white : tc.textMuted, fontStyle: FontStyle.normal)),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: tc.cardColor,
                        onSelected: (val) { if (val) setState(() => _selectedCategory = cat['id'] as String); },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                decoration: InputDecoration(labelText: 'Title', labelStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _artistCtrl,
                style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                decoration: InputDecoration(labelText: 'Artist', labelStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _notesCtrl,
                style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                maxLines: 2,
                decoration: InputDecoration(labelText: 'Why does this song feel like us? (optional)', labelStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
              ),
              const SizedBox(height: 16),

              ListTile(
                title: Text('Add streaming links', style: GoogleFonts.dmSans(color: AppColors.rose, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
                trailing: Icon(_showUrls ? Icons.expand_less : Icons.expand_more, color: AppColors.rose),
                onTap: () => setState(() => _showUrls = !_showUrls),
                contentPadding: EdgeInsets.zero,
              ),

              if (_showUrls) ...[
                TextField(
                  controller: _spotifyCtrl,
                  style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                  decoration: InputDecoration(labelText: 'Spotify URL', labelStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _youtubeCtrl,
                  style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                  decoration: InputDecoration(labelText: 'YouTube URL', labelStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _appleCtrl,
                  style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                  decoration: InputDecoration(labelText: 'Apple Music URL', labelStyle: GoogleFonts.dmSans(color: tc.textMuted, fontStyle: FontStyle.normal)),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: RoseButton(
                  label: 'Add to Our Soundtrack 🎵',
                  onTap: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
