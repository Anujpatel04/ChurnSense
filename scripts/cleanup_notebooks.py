#!/usr/bin/env python3
"""Clean up notebooks after emoji removal."""

import os
import re

notebooks_dir = '/Users/anuj/Desktop/Churn_Retension/churn-prediction-bigtech/notebooks'

# Simple string replacements
simple_replacements = [
    ('print(" Libraries', 'print("Libraries'),
    ('print("Libraries imported successfully")', 'print("Libraries loaded")'),
    ('print(" Data', 'print("Data'),
    ('print(" Loaded', 'print("Loaded'),
    ('print(" Model', 'print("Model'),
    ('print(" Optimal', 'print("Optimal'),
    ('print(" Timestamp', 'print("Timestamp'),
    ('print(f" ', 'print(f"'),
    ('[OK] Libraries', 'Libraries'),
    ('[OK] Data', 'Data'),
    ('[OK] Loaded', 'Loaded'),
    ('[OK] Model', 'Model'),
    ('Note: KEY', 'KEY'),
    ('COMPLETE [OK]', 'COMPLETE'),
    ('Status: COMPLETE *', 'Status: COMPLETE'),
    ('#  PHASE', '# PHASE'),
    ('##  ', '## '),
]

for filename in os.listdir(notebooks_dir):
    if filename.endswith('.ipynb'):
        filepath = os.path.join(notebooks_dir, filename)
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        for old, new in simple_replacements:
            content = content.replace(old, new)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f'Cleaned {filename}')

print('Done!')
