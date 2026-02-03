import json
import os
import re

def clean_code_cell(source_lines):
    """Remove comments from Python code while keeping essential code"""
    cleaned_lines = []
    
    for line in source_lines:
        stripped = line.strip()
        
        # Skip lines that are only comments
        if stripped.startswith('#') and not stripped.startswith('#!'):
            # Keep shebang and special markers, skip regular comments
            continue
        
        # Remove inline comments but keep the code
        if '#' in line and not line.strip().startswith('#'):
            # Find the position of # that's not inside a string
            in_string = False
            string_char = None
            for i, char in enumerate(line):
                if char in ['"', "'"] and (i == 0 or line[i-1] != '\\'):
                    if not in_string:
                        in_string = True
                        string_char = char
                    elif char == string_char:
                        in_string = False
                elif char == '#' and not in_string:
                    # Found a comment - keep only the code part
                    code_part = line[:i].rstrip()
                    if code_part:
                        cleaned_lines.append(code_part + '\n' if not code_part.endswith('\n') else code_part)
                    break
            else:
                # No comment found (# was inside string)
                cleaned_lines.append(line)
        else:
            cleaned_lines.append(line)
    
    # Remove consecutive blank lines (keep at most 1)
    final_lines = []
    prev_blank = False
    for line in cleaned_lines:
        is_blank = line.strip() == ''
        if is_blank and prev_blank:
            continue
        final_lines.append(line)
        prev_blank = is_blank
    
    return final_lines

def clean_markdown_cell(source_lines):
    """Clean markdown cells - remove excessive formatting"""
    cleaned_lines = []
    
    for line in source_lines:
        # Remove emoji characters
        line = re.sub(r'[\U0001F300-\U0001F9FF\U00002600-\U000026FF\U00002700-\U000027BF]', '', line)
        # Remove check marks and other symbols
        line = line.replace('✅', '').replace('❌', '').replace('⚠️', '')
        line = line.replace('📊', '').replace('📌', '').replace('🎯', '')
        line = line.replace('💡', '').replace('🔧', '').replace('🤖', '')
        line = line.replace('🏷️', '').replace('💰', '').replace('📅', '')
        line = line.replace('🎉', '').replace('🚨', '').replace('→', '->')
        cleaned_lines.append(line)
    
    return cleaned_lines

def process_notebook(filepath):
    """Process a single notebook file"""
    print(f"Processing: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    for cell in notebook.get('cells', []):
        source = cell.get('source', [])
        
        if isinstance(source, str):
            source = source.split('\n')
            source = [line + '\n' for line in source[:-1]] + [source[-1]] if source else []
        
        if cell.get('cell_type') == 'code':
            cell['source'] = clean_code_cell(source)
        elif cell.get('cell_type') == 'markdown':
            cell['source'] = clean_markdown_cell(source)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(notebook, f, indent=1, ensure_ascii=False)
    
    print(f"  Cleaned: {filepath}")

def main():
    notebooks_dir = '/Users/anuj/Desktop/Churn_Retension/churn-prediction-bigtech/notebooks'
    
    for filename in sorted(os.listdir(notebooks_dir)):
        if filename.endswith('.ipynb'):
            filepath = os.path.join(notebooks_dir, filename)
            process_notebook(filepath)
    
    print("\nAll notebooks cleaned!")

if __name__ == '__main__':
    main()
