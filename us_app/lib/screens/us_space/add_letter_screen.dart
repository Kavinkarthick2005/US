import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../providers/open_when_provider.dart';
import '../../models/open_when_model.dart';
import '../../widgets/rose_button.dart';
import '../../config/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/v2/space_header.dart';

class AddLetterScreen extends ConsumerStatefulWidget {
  const AddLetterScreen({super.key});

  @override
  ConsumerState<AddLetterScreen> createState() => _AddLetterScreenState();
}

class _AddLetterScreenState extends ConsumerState<AddLetterScreen> {
  String _selectedTrigger = '';
  final TextEditingController _customTriggerController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final List<Color> _swatchColors = [
    const Color(0xFFE8607A), // Rose
    const Color(0xFFC97B93), // Mauve
    const Color(0xFFC0392B), // Deep Rose
    const Color(0xFFD4AF37), // Gold
    const Color(0xFF2C3E6B), // Midnight
    const Color(0xFF7A9E7E), // Sage
  ];

  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    if (OpenWhenModel.triggerPresets.isNotEmpty) {
      _selectedTrigger = OpenWhenModel.triggerPresets.first;
    }
    _selectedColor = _swatchColors.first;
  }

  @override
  void dispose() {
    _customTriggerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveLetter() {
    final triggerLabel = _selectedTrigger == 'Custom'
        ? _customTriggerController.text.trim()
        : _selectedTrigger;

    final content = _contentController.text.trim();

    if (triggerLabel.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }

    final hexColor = '#${_selectedColor.value.toRadixString(16).substring(2, 8).toUpperCase()}';

    ref.read(openWhenProvider.notifier).addLetter(
          triggerLabel: triggerLabel,
          content: content,
          coverColor: hexColor,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your letter is sealed...')),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;
    
    return Scaffold(
      backgroundColor: tc.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Write a Letter 💌',
              gradientColors: const [Color(0xFFE8607A), Color(0xFFC97B93)],
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open when...',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...OpenWhenModel.triggerPresets.map((trigger) {
                            final isSelected = _selectedTrigger == trigger;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  trigger,
                                  style: GoogleFonts.dmSans(
                                    color: isSelected
                                        ? Colors.white
                                        : tc.textMuted,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.rose,
                                backgroundColor: tc.cardColor,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedTrigger = trigger;
                                    });
                                  }
                                },
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                'Custom',
                                style: GoogleFonts.dmSans(
                                  color: _selectedTrigger == 'Custom'
                                      ? Colors.white
                                      : tc.textMuted,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                              selected: _selectedTrigger == 'Custom',
                              selectedColor: AppColors.rose,
                              backgroundColor: tc.cardColor,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTrigger = 'Custom';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedTrigger == 'Custom') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _customTriggerController,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: tc.textPrimary,
                          fontStyle: FontStyle.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter custom trigger...',
                          hintStyle: GoogleFonts.dmSans(
                            color: tc.textMuted,
                            fontStyle: FontStyle.normal,
                          ),
                          filled: true,
                          fillColor: tc.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Cover Color',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _swatchColors.map((color) {
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: tc.textPrimary, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Letter Content',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEFAF9), // Cream paper
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: 12,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          color: AppColors.deep,
                          height: 1.8,
                          fontStyle: FontStyle.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write what your heart wants them to know...',
                          hintStyle: GoogleFonts.dmSans(
                            color: Colors.grey[500],
                            fontStyle: FontStyle.normal,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: RoseButton(
                        label: 'Seal it 💌',
                        onTap: _saveLetter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
