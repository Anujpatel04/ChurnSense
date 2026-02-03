#!/usr/bin/env python3
"""Remove emojis from all notebooks to make them look more professional."""

import os
import re

# Emoji patterns to remove
emoji_pattern = re.compile(
    "["
    "\U0001F300-\U0001F9FF"  # Symbols & Pictographs
    "\U00002600-\U000026FF"  # Misc symbols
    "\U00002700-\U000027BF"  # Dingbats
    "\U0001F600-\U0001F64F"  # Emoticons
    "\U0001F680-\U0001F6FF"  # Transport & Map
    "\U0001F1E0-\U0001F1FF"  # Flags
    "]+", 
    flags=re.UNICODE
)

# Specific replacements
replacements = {
    '\u2705': '[OK]',   # ✅
    '\u274c': '[X]',    # ❌
    '\u26a0': '[!]',    # ⚠
    '\u2713': '[x]',    # ✓
    '\u2714': '[x]',    # ✔
    '\u2717': '[ ]',    # ✗
    '\u2718': '[ ]',    # ✘
    '\u2606': '*',      # ☆
    '\u2605': '*',      # ★
    '\u2192': '-->',    # →
    '\ufe0f': '',       # Variation selector
}

notebooks_dir = os.path.join(os.path.dirname(__file__), '..', 'notebooks')

for filename in os.listdir(notebooks_dir):
    if filename.endswith('.ipynb'):
        filepath = os.path.join(notebooks_dir, filename)
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(filepath, 'r', encoding='latin-1') as f:
                content = f.read()
        
        # Remove emojis using regex
        new_content = emoji_pattern.sub('', content)
        
        # Apply specific replacements
        for old, new in replacements.items():
            new_content = new_content.replace(old, new)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f'Processed {filename}')

print('Done!')
