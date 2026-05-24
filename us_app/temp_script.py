import re

path = r'c:\Users\kavin\OneDrive\Desktop\US\us_app\lib\screens\planner\planner_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# First, ensure we import theme_provider if not already imported
if 'import \'../../providers/theme_provider.dart\';' not in content:
    content = content.replace('import \'../../providers/timetable_provider.dart\';', 'import \'../../providers/timetable_provider.dart\';\nimport \'../../providers/theme_provider.dart\';')

# Now add `final tc = ref.watch(themeProvider).colors;` in specific build methods or just pass it around.
# Actually, it's safer to just regex replace AppColors if we can find where to inject tc.
# But passing tc everywhere in 1600 lines using regex is error prone.
# Let's do it by doing specific replaces, or just let me do multi_replace_file_content for the major build methods to inject `tc` and then replace AppColors inside those widgets.

print("Use multi_replace_file_content or a robust parser instead.")
