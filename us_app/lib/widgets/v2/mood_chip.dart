import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated mood/filter chip with smooth selection state.
class MoodChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color? selectedTextColor;

  const MoodChip({
    super.key,
    required this.label,
    this.emoji,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    this.selectedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : selectedColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : selectedColor.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (selectedTextColor ?? Colors.white)
                    : selectedColor,
                fontStyle: FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.04, 1.04),
          duration: 150.ms,
        );
  }
}

/// Horizontal scrollable row of MoodChips.
class MoodChipRow extends StatelessWidget {
  final List<({String label, String? emoji})> chips;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color selectedColor;

  const MoodChipRow({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelected,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: chips.map((chip) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MoodChip(
              label: chip.label,
              emoji: chip.emoji,
              isSelected: selected == chip.label,
              onTap: () => onSelected(chip.label),
              selectedColor: selectedColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Emoji mood selector used in the partner care / journal screens.
class EmojiMoodSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const EmojiMoodSelector({
    super.key,
    this.selected,
    required this.onSelected,
  });

  static const _moods = [
    ('😊', 'Happy'),
    ('😍', 'In love'),
    ('😔', 'Sad'),
    ('😤', 'Frustrated'),
    ('😴', 'Tired'),
    ('🥰', 'Cozy'),
    ('😂', 'Laughing'),
    ('😌', 'Calm'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _moods.map(((String emoji, String label) mood) {
        final isSelected = selected == mood.$1;
        return GestureDetector(
          onTap: () => onSelected(mood.$1),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE8607A).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE8607A)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Text(mood.$1,
                    style: TextStyle(fontSize: isSelected ? 28 : 24)),
                const SizedBox(height: 4),
                Text(
                  mood.$2,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: isSelected
                        ? const Color(0xFFE8607A)
                        : Colors.white.withValues(alpha: 0.5),
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
