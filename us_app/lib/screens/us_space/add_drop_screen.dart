import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/groq_client.dart';
import '../../providers/drops_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/music_provider.dart';
import '../../models/song_model.dart';
import '../../widgets/v2/space_header.dart';

class AddDropScreen extends ConsumerStatefulWidget {
  const AddDropScreen({super.key});

  @override
  ConsumerState<AddDropScreen> createState() => _AddDropScreenState();
}

class _AddDropScreenState extends ConsumerState<AddDropScreen> {
  final _captionController = TextEditingController();
  final _songTitleController = TextEditingController();
  final _songArtistController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String _visibility = 'shared';
  bool _isUploading = false;

  String _songMode = 'new'; // 'new' or 'playlist'
  SongModel? _selectedPlaylistSong;

  final List<String> _visibilities = ['private', 'just us', 'shared'];

  @override
  void dispose() {
    _captionController.dispose();
    _songTitleController.dispose();
    _songArtistController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1080,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _saveDrop() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please pick a photo first.',
            style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final ext = _selectedImage!.path.split('.').last.toLowerCase();
      final fileName = 'drop_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('drops')
          .uploadBinary(fileName, _imageBytes!);

      final publicUrl = Supabase.instance.client.storage
          .from('drops')
          .getPublicUrl(fileName);

      int importance = 0;
      List<String> contextChips = [];
      final caption = _captionController.text.trim();
      
      if (caption.isNotEmpty) {
        final prompt = '''
Given this drop caption: '$caption'
Return JSON only: 
{
  "importance_score": [1-10 integer],
  "moment_context": [array of 1-3 short tags like 'date night', 'lazy sunday', 'missing you']
}
Score 1-3: casual moment. 4-6: meaningful. 7-10: special/milestone.
Only return JSON. Nothing else.
''';
        final aiResponse = await GroqClient.prompt('You are a JSON API. Return ONLY raw JSON.', prompt);
        try {
          final cleanJsonStr = aiResponse.replaceAll('```json', '').replaceAll('```', '').trim();
          final parsed = jsonDecode(cleanJsonStr);
          importance = parsed['importance_score'] ?? 0;
          final ctxList = parsed['moment_context'];
          if (ctxList is List) {
            contextChips = ctxList.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      String? finalSongInfo;
      if (_songMode == 'playlist' && _selectedPlaylistSong != null) {
        finalSongInfo = '🎵 ${_selectedPlaylistSong!.title} · ${_selectedPlaylistSong!.artist}';
      } else if (_songMode == 'new') {
        final st = _songTitleController.text.trim();
        final sa = _songArtistController.text.trim();
        if (st.isNotEmpty) {
          finalSongInfo = sa.isNotEmpty ? '🎵 $st · $sa' : '🎵 $st';
        }
      }

      final newDrop = await ref.read(dropsProvider.notifier).addDrop(
            photoUrl: publicUrl,
            caption: caption,
            songInfo: finalSongInfo,
            visibility: _visibility,
            importanceScore: importance,
            momentContext: contextChips,
          );

      if (mounted) {
        if (importance >= 7) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This feels special. Save to memories? 💕',
                style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              ),
              backgroundColor: const Color(0xFFE91E8C),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Save',
                textColor: Colors.white,
                onPressed: () {
                  ref.read(memoryProvider.notifier).addMemory(
                    content: caption.isNotEmpty ? caption : 'Shared a special drop',
                    category: 'moment',
                    ownerId: Supabase.instance.client.auth.currentUser?.id ?? '',
                    visibility: 'shared',
                    imageUrl: publicUrl,
                  );
                },
              ),
            ),
          );
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save drop: ${e.toString()}',
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        color: Colors.white30,
        fontStyle: FontStyle.normal,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE91E8C), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _showPlaylistPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1020),
      builder: (ctx) {
        final asyncSongs = ref.watch(musicProvider);
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Select a Song', style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20, fontStyle: FontStyle.normal)),
              ),
              Expanded(
                child: asyncSongs.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C))),
                  error: (_, __) => const Center(child: Text('Error loading songs', style: TextStyle(color: Colors.white))),
                  data: (songs) {
                    if (songs.isEmpty) {
                      return const Center(child: Text('No songs in your playlist yet.', style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return ListTile(
                          leading: const Text('🎵'),
                          title: Text(song.title, style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal)),
                          subtitle: Text(song.artist, style: GoogleFonts.dmSans(color: Colors.white54, fontStyle: FontStyle.normal)),
                          onTap: () {
                            setState(() => _selectedPlaylistSong = song);
                            Navigator.pop(ctx);
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: Stack(
        children: [
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
                  title: 'New Drop',
                  gradientColors: const [Color(0xFF1A0A0F), Color(0xFF3D1525)],
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImagePicker(),
                        const SizedBox(height: 24),

                        _buildSectionLabel('Caption'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _captionController,
                          maxLines: 3,
                          style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
                          decoration: _inputDecoration('What\'s this moment about...'),
                        ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
                        const SizedBox(height: 24),

                        _buildSectionLabel('Add a song to this moment 🎵'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _songMode = 'playlist'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _songMode == 'playlist' ? const Color(0xFFE91E8C).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _songMode == 'playlist' ? const Color(0xFFE91E8C) : Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Center(child: Text('From playlist', style: GoogleFonts.dmSans(color: _songMode == 'playlist' ? Colors.white : Colors.white54, fontStyle: FontStyle.normal))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _songMode = 'new'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _songMode == 'new' ? const Color(0xFFE91E8C).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _songMode == 'new' ? const Color(0xFFE91E8C) : Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Center(child: Text('Add new song', style: GoogleFonts.dmSans(color: _songMode == 'new' ? Colors.white : Colors.white54, fontStyle: FontStyle.normal))),
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                        
                        const SizedBox(height: 12),
                        
                        if (_songMode == 'playlist') ...[
                          GestureDetector(
                            onTap: _showPlaylistPicker,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Text(
                                _selectedPlaylistSong != null ? '🎵 ${_selectedPlaylistSong!.title} · ${_selectedPlaylistSong!.artist}' : 'Tap to select from Our Soundtrack...',
                                style: GoogleFonts.dmSans(color: _selectedPlaylistSong != null ? Colors.white : Colors.white54, fontStyle: FontStyle.normal),
                              ),
                            ),
                          )
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _songTitleController,
                                  style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
                                  decoration: _inputDecoration('Song name'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _songArtistController,
                                  style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
                                  decoration: _inputDecoration('Artist'),
                                ),
                              ),
                            ],
                          )
                        ],
                        
                        const SizedBox(height: 24),
                        _buildSectionLabel('Visibility'),
                        const SizedBox(height: 12),
                        _buildVisibilitySelector(),
                        const SizedBox(height: 40),

                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isUploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1020),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFE91E8C)),
                      const SizedBox(height: 20),
                      Text('Saving your drop...', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontStyle: FontStyle.normal)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        fontStyle: FontStyle.normal,
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: _selectedImage != null
                ? const Color(0xFFE91E8C).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE91E8C).withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFE91E8C), size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Pick a photo', style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontStyle: FontStyle.normal)),
                  const SizedBox(height: 6),
                  Text('Tap to choose from gallery', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.normal)),
                ],
              ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400)).slideY(begin: 0.1, end: 0, duration: const Duration(milliseconds: 400));
  }

  Widget _buildVisibilitySelector() {
    return Row(
      children: _visibilities.map((v) {
        final isSelected = _visibility == v;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _visibility = v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: v != _visibilities.last ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? const Color(0xFFE91E8C).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected ? const Color(0xFFE91E8C) : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Text(
                v.substring(0, 1).toUpperCase() + v.substring(1),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: const Duration(milliseconds: 400));
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _saveDrop,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E8C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 10,
          shadowColor: const Color(0xFFE91E8C).withValues(alpha: 0.5),
        ),
        child: Text('Save Drop', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, fontStyle: FontStyle.normal)),
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 500)).slideY(begin: 0.2, end: 0, delay: const Duration(milliseconds: 500));
  }
}
