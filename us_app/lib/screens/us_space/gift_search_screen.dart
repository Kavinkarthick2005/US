import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/app_colors.dart';
import '../../config/env.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';

class GiftSearchScreen extends ConsumerStatefulWidget {
  const GiftSearchScreen({super.key});

  @override
  ConsumerState<GiftSearchScreen> createState() => _GiftSearchScreenState();
}

class _GiftSearchScreenState extends ConsumerState<GiftSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _interestsCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _occasionCtrl = TextEditingController();

  bool _isLoading = false;
  List<_GiftIdea> _results = [];

  @override
  void dispose() {
    _interestsCtrl.dispose();
    _budgetCtrl.dispose();
    _occasionCtrl.dispose();
    super.dispose();
  }

  Future<void> _findGifts() async {
    if (!_formKey.currentState!.validate()) return;

    final interests = _interestsCtrl.text.trim();
    final budget = _budgetCtrl.text.trim();
    final occasion = _occasionCtrl.text.trim();

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final occasionPart =
          occasion.isNotEmpty ? 'Occasion: $occasion.' : '';
      final prompt =
          'Suggest 8 thoughtful gift ideas for someone who likes $interests. '
          'Budget: ₹$budget. $occasionPart '
          'Format each as: emoji | Gift name | Why she\'d love it | Approximate ₹ price. '
          'Keep it warm and personal.';

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${Env.groqApiKey}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a warm, thoughtful gift advisor. You suggest creative, personal gift ideas. Always respond in the exact format requested.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 1000,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['choices'][0]['message']['content']?.trim() ?? '';
        final parsed = _parseGiftIdeas(text);
        setState(() {
          _results = parsed;
          _isLoading = false;
        });
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not get gift ideas. Please try again.',
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<_GiftIdea> _parseGiftIdeas(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains('|'))
        .toList();

    final ideas = <_GiftIdea>[];
    for (final line in lines) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.length >= 4) {
        ideas.add(_GiftIdea(
          emoji: parts[0].isEmpty ? '🎁' : parts[0],
          name: parts[1],
          reason: parts[2],
          price: parts[3],
        ));
      }
    }
    return ideas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: Column(
        children: [
          SpaceSubHeader(
            title: 'Gift Ideas',
            gradientColors: const [Color(0xFF1A0A0F), Color(0xFF3D1525)],
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find the perfect gift 🎁',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let AI suggest thoughtful ideas',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildForm(),
                        const SizedBox(height: 32),
                        if (_isLoading) _buildLoadingState(),
                        if (_results.isNotEmpty && !_isLoading)
                          _buildResultsHeader(),
                      ],
                    ),
                  ),
                ),
                if (_results.isNotEmpty && !_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _GiftCard(
                          idea: _results[i],
                          index: i,
                        ),
                        childCount: _results.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _DarkTextField(
            controller: _interestsCtrl,
            hint: 'Her interests (e.g., skincare, books, music)',
            icon: Icons.favorite_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please enter interests' : null,
          ),
          const SizedBox(height: 14),
          _DarkTextField(
            controller: _budgetCtrl,
            hint: 'Budget (₹)',
            icon: Icons.currency_rupee_rounded,
            keyboardType: TextInputType.number,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please enter a budget' : null,
          ),
          const SizedBox(height: 14),
          _DarkTextField(
            controller: _occasionCtrl,
            hint: 'Occasion (optional, e.g., birthday, anniversary)',
            icon: Icons.celebration_rounded,
            validator: null,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _isLoading ? null : _findGifts,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.rose, AppColors.mauve],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rose.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Find Gifts ✨',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: AppColors.rose,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Finding perfect gifts...',
          style: GoogleFonts.dmSans(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        '${_results.length} gift ideas 💝',
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gift card
// ─────────────────────────────────────────────────────────────────────────────
class _GiftCard extends StatefulWidget {
  final _GiftIdea idea;
  final int index;

  const _GiftCard({required this.idea, required this.index});

  @override
  State<_GiftCard> createState() => _GiftCardState();
}

class _GiftCardState extends State<_GiftCard> {
  bool _hearted = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DarkGlassCard(
        borderColor: AppColors.rose.withValues(alpha: 0.15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.idea.emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.idea.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.idea.reason,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontStyle: FontStyle.normal,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.idea.price,
                    style: GoogleFonts.dmMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.rose,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _hearted = !_hearted),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hearted
                      ? AppColors.rose.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hearted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _hearted ? AppColors.rose : Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (widget.index * 80).ms)
        .slideY(begin: 0.15, end: 0, delay: (widget.index * 80).ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark text field
// ─────────────────────────────────────────────────────────────────────────────
class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DarkTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.dmSans(
        color: Colors.white,
        fontSize: 14,
        fontStyle: FontStyle.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 14,
          fontStyle: FontStyle.normal,
        ),
        prefixIcon: Icon(icon,
            color: Colors.white.withValues(alpha: 0.4), size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gift idea data class
// ─────────────────────────────────────────────────────────────────────────────
class _GiftIdea {
  final String emoji;
  final String name;
  final String reason;
  final String price;

  const _GiftIdea({
    required this.emoji,
    required this.name,
    required this.reason,
    required this.price,
  });
}
