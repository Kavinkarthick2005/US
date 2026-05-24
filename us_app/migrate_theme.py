import re
import os

path = r'c:\Users\kavin\OneDrive\Desktop\US\us_app\lib\screens\planner\planner_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Add theme provider import if missing
if 'providers/theme_provider.dart' not in text:
    text = text.replace(
        "import '../../providers/timetable_provider.dart';",
        "import '../../providers/timetable_provider.dart';\nimport '../../providers/theme_provider.dart';"
    )

# Replace build signatures to get tc where possible
text = re.sub(
    r'Widget build\(BuildContext context\) {',
    r'Widget build(BuildContext context) {\n    final tc = ref.watch(themeProvider).colors;',
    text
)

text = re.sub(
    r'Widget build\(BuildContext context, WidgetRef ref\) {',
    r'Widget build(BuildContext context, WidgetRef ref) {\n    final tc = ref.watch(themeProvider).colors;',
    text
)

# For methods returning Widget, pass tc if needed (too complex for regex, doing simple replacements instead)

replacements = [
    ('AppColors.cream', 'tc.backgroundColor'),
    ('AppColors.deep', 'tc.textPrimary'),
    ('AppColors.mid', 'tc.textSecondary'),
    ('AppColors.muted', 'tc.textMuted'),
    ('AppColors.rose', 'tc.iconColor'),
    ('AppColors.mauve', 'tc.iconColor'),
    ('AppColors.blush', 'tc.borderColor'),
    ('AppColors.darkCard', 'tc.cardColor'),
    ('Colors.white', 'tc.cardColor') # This one is risky, might break text colors that should be white on rose background.
]

# Better approach: Just do it chunk by chunk or using flutter tools?
# No, let's just do it cleanly via file rewrite in flutter. 
# planner_screen is 1650 lines. Let's chunk rewrite it in 2 pieces using write_to_file? No, write_to_file overwrites. 
# We can use multi_replace_file_content for the widgets in planner_screen.dart, but there are too many.

print("Done")
