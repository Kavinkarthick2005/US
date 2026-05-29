import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../providers/couple_provider.dart';
import '../../widgets/v2/glass_container.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Page 1: Who are you
  String _selectedGender = 'male'; // 'male' or 'female'
  final TextEditingController _nameController = TextEditingController();
  File? _avatarFile;

  // Page 2: Partner
  String _selectedPronoun = 'she'; // 'she', 'he', or 'they'

  // Page 3: Connect
  final TextEditingController _partnerCodeController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Default name from Supabase user metadata
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final defaultName = (meta['full_name'] as String?) ??
          (meta['name'] as String?) ??
          user.email?.split('@').first ??
          '';
      _nameController.text = defaultName;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _partnerCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    } catch (_) {}
  }

  Future<String?> _uploadAvatar() async {
    if (_avatarFile == null) return null;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      final bytes = await _avatarFile!.readAsBytes();
      final ext = _avatarFile!.path.split('.').last;
      final fileName = '${user.id}_avatar.$ext';

      // Upload to avatars bucket
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      return Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _completeAndGo(bool skipLinking, {String? partnerCode}) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please tell us your name 💖',
            style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Upload avatar if selected
      final avatarUrl = await _uploadAvatar();

      // 2. Complete onboarding metadata in DB
      await ref.read(coupleProvider.notifier).completeOnboarding(
            name: _nameController.text.trim(),
            gender: _selectedGender,
            pronoun: _selectedPronoun,
            avatarUrl: avatarUrl,
          );

      // 3. Link partner if code is provided
      if (!skipLinking && partnerCode != null && partnerCode.trim().isNotEmpty) {
        await ref.read(coupleProvider.notifier).linkPartner(partnerCode.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully linked! Welcome to Us 💕',
                style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              ),
              backgroundColor: const Color(0xFFE8607A),
            ),
          );
        }
      }

      if (mounted) {
        context.go('/us-space');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              partnerCode != null
                  ? 'Failed to link partner code: ${e.toString().replaceAll('Exception: ', '')}'
                  : 'Onboarding failed. Please try again.',
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please tell us your name 🌸',
            style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final myCode = coupleState?.currentUser?.coupleCode ?? '------';

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F0509),
                  Color(0xFF1E0D14),
                  Color(0xFF2E1020),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Glowing ambient lights
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8607A).withValues(alpha: 0.12),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: List.generate(3, (index) {
                      final active = index <= _currentPage;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 4,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFE8607A)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Main sliding pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPageOne(),
                      _buildPageTwo(),
                      _buildPageThree(myCode),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE8607A),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── PAGE 1: Who Are You ────────────────────────────────────────────────────
  Widget _buildPageOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Who are you? 🌸',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            'Let us personalize your Us Space dashboard.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 450.ms, delay: 100.ms),
          const SizedBox(height: 36),

          // Large gender toggle
          Center(
            child: Column(
              children: [
                Text(
                  'I AM...',
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE8607A),
                    fontStyle: FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // His Toggle Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'male'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _selectedGender == 'male'
                                ? const LinearGradient(
                                    colors: [Color(0xFFE8607A), Color(0xFF9B2647)],
                                  )
                                : null,
                            color: _selectedGender == 'male'
                                ? null
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedGender == 'male'
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('♂', style: TextStyle(fontSize: 18, color: Colors.white)),
                              const SizedBox(width: 8),
                              Text(
                                'Him',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hers Toggle Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'female'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _selectedGender == 'female'
                                ? const LinearGradient(
                                    colors: [Color(0xFFC97B93), Color(0xFFE8A0B4)],
                                  )
                                : null,
                            color: _selectedGender == 'female'
                                ? null
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedGender == 'female'
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('♀', style: TextStyle(fontSize: 18, color: Colors.white)),
                              const SizedBox(width: 8),
                              Text(
                                'Her',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 36),

          // Name field
          Text(
            'WHAT SHOULD WE CALL YOU?',
            style: GoogleFonts.dmMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE8607A),
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.normal,
            ),
            decoration: InputDecoration(
              hintText: 'Your name',
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.3),
                fontStyle: FontStyle.normal,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE8607A), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 36),

          // Avatar upload
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: const Color(0xFFE8607A).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      image: _avatarFile != null
                          ? DecorationImage(
                              image: FileImage(_avatarFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _avatarFile == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            color: Color(0xFFE8607A),
                            size: 28,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _avatarFile == null ? 'Upload Profile Photo' : 'Change Photo',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

          const SizedBox(height: 48),

          // Continue button
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8607A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Center(
              child: Text(
                'Next Step ➔',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
        ],
      ),
    );
  }

  // ── PAGE 2: Your Partner ───────────────────────────────────────────────────
  Widget _buildPageTwo() {
    final chips = [
      ('She/Her ♀', 'she'),
      ('He/Him ♂', 'he'),
      ('They/Them 🌟', 'they'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Your Partner 💖',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Tell us what pronouns your partner uses.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 450.ms, delay: 100.ms),
          const SizedBox(height: 40),

          Text(
            'MY PARTNER USES...',
            style: GoogleFonts.dmMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE8607A),
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 16),

          // Pronoun chips
          Column(
            children: chips.map((c) {
              final selected = _selectedPronoun == c.$2;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPronoun = c.$2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE8607A).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE8607A)
                            : Colors.white.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.$1,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFE8607A),
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 28),

          // Scrapbook tip card
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why this matters',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 14,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This helps customize the spaces (e.g. cycle tracker placement, specific stickers, and personal reminders).',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                          fontStyle: FontStyle.normal,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 350.ms),

          const SizedBox(height: 48),

          // Actions row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8607A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Next Step ➔',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
        ],
      ),
    );
  }

  // ── PAGE 3: Connect ────────────────────────────────────────────────────────
  Widget _buildPageThree(String myCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Connect Together 💕',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Link your accounts to start sharing memories.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(duration: 450.ms, delay: 100.ms),
          const SizedBox(height: 32),

          // Your Code Card
          Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              width: double.infinity,
              child: Column(
                children: [
                  Text(
                    'YOUR COUPLE CODE',
                    style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE8607A),
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Styled Code Paper
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFAF6), // Cream polaroid-style paper
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEADBCE)),
                    ),
                    child: Text(
                      myCode.split('').join(' '),
                      style: GoogleFonts.dmMono(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3E2D2F),
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'Connect with me on Us! Here is my couple code: $myCode 💕',
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      'Share Code',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8607A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 32),

          // Enter Partner Code Section
          Text(
            'ENTER THEIR CODE',
            style: GoogleFonts.dmMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE8607A),
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _partnerCodeController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: GoogleFonts.dmMono(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              fontStyle: FontStyle.normal,
            ),
            decoration: InputDecoration(
              hintText: 'PARTNER CODE',
              hintStyle: GoogleFonts.dmMono(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 16,
                letterSpacing: 2,
                fontStyle: FontStyle.normal,
              ),
              counterText: '',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE8607A), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

          const SizedBox(height: 24),

          // Link Up button
          ElevatedButton(
            onPressed: () {
              final code = _partnerCodeController.text.trim();
              if (code.isEmpty || code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a valid 6-character partner code 💕',
                      style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              _completeAndGo(false, partnerCode: code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8607A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Center(
              child: Text(
                'Link Up 💕',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

          const SizedBox(height: 20),

          // Skip Option
          Center(
            child: TextButton(
              onPressed: () => _completeAndGo(true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                "I'll do this later",
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
        ],
      ),
    );
  }
}
