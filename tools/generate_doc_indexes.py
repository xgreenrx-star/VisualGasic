#!/usr/bin/env python3
"""
Generate Table of Contents and Alphabetical Indexes for VisualGasic documentation.

For each doc file:
1. If it lacks a TOC, insert one after the title (## Table of Contents)
2. Append an alphabetical index at the end with anchor links

Run from the project root:
    python3 tools/generate_doc_indexes.py
"""

import re
import os
from pathlib import Path
from collections import defaultdict

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Config: (file_path, has_toc_already, index_title)
DOC_FILES = [
    ("docs/VisualGasic_Language_Reference.md", True, "Alphabetical Index"),
    ("docs/ADVANCED_FEATURES_MANUAL.md", True, "Alphabetical Index"),
    ("docs/reference/GODOT_FUNCTIONS_REFERENCE.md", True, "Alphabetical Index"),
    ("docs/reference/CONTROLS_REFERENCE.md", False, "Alphabetical Index"),
    ("docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md", False, "Alphabetical Index"),
    ("docs/WINFORMS_FORM_GUIDE.md", False, "Alphabetical Index"),
    ("docs/AUTO_WIRING_GUIDE.md", False, "Alphabetical Index"),
    ("docs/reference/VB6_FEATURES_IMPLEMENTATION.md", False, "Alphabetical Index"),
    ("docs/reference/MODERN_SYNTAX_QUICK_REF.md", False, "Alphabetical Index"),
    ("docs/reference/GODOT_QUICK_REF.md", False, "Alphabetical Index"),
]


def slugify(text: str) -> str:
    """Convert a header to a GitHub-style anchor slug."""
    # Remove markdown formatting
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)  # bold
    text = re.sub(r'\*([^*]+)\*', r'\1', text)      # italic
    text = re.sub(r'`([^`]+)`', r'\1', text)        # code
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)  # links
    # Remove emojis and special chars, keep alphanumeric, spaces, hyphens
    text = re.sub(r'[^\w\s-]', '', text)
    # Custom anchor overrides via {#anchor}
    text = re.sub(r'\{#[^}]+\}', '', text)
    text = text.strip().lower()
    text = re.sub(r'\s+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text


def extract_custom_anchor(header_text: str) -> str | None:
    """Extract {#custom-anchor} from header if present."""
    m = re.search(r'\{#([^}]+)\}', header_text)
    if m:
        return m.group(1)
    return None


def parse_headers(lines: list[str]) -> list[tuple[int, int, str, str]]:
    """
    Parse markdown headers from lines.
    Returns list of (line_number, level, raw_text, anchor).
    """
    headers = []
    in_code_block = False
    for i, line in enumerate(lines):
        stripped = line.rstrip()
        if stripped.startswith('```'):
            in_code_block = not in_code_block
            continue
        if in_code_block:
            continue
        m = re.match(r'^(#{1,6})\s+(.+)$', stripped)
        if m:
            level = len(m.group(1))
            raw_text = m.group(2).strip()
            custom = extract_custom_anchor(raw_text)
            # Clean text for display (remove {#anchor})
            display = re.sub(r'\s*\{#[^}]+\}', '', raw_text).strip()
            anchor = custom if custom else slugify(raw_text)
            headers.append((i, level, display, anchor))
    return headers


def generate_toc(headers: list[tuple[int, int, str, str]], min_level=2, max_level=3) -> str:
    """Generate a Table of Contents from headers."""
    toc_lines = ["## Table of Contents\n"]
    for _, level, display, anchor in headers:
        if level < min_level or level > max_level:
            continue
        # Skip the "Table of Contents" header itself and "Alphabetical Index"
        if display.lower() in ("table of contents", "alphabetical index"):
            continue
        indent = "  " * (level - min_level)
        # Clean display text of markdown bold/italic for cleaner TOC
        clean_display = re.sub(r'\*\*([^*]+)\*\*', r'\1', display)
        clean_display = re.sub(r'\*([^*]+)\*', r'\1', clean_display)
        toc_lines.append(f"{indent}- [{clean_display}](#{anchor})")
    toc_lines.append("")  # trailing newline
    return "\n".join(toc_lines)


def extract_index_terms(headers: list[tuple[int, int, str, str]]) -> dict[str, list[tuple[str, str]]]:
    """
    Extract indexable terms from headers.
    Returns dict: term -> [(section_display, anchor), ...]
    
    Strategy:
    - Each header contributes its full section name as an index entry
    - Function names like "GetNode(path)" become "GetNode"
    - "Sub / Function definitions" extracts "Sub" and "Function"
    - Parenthetical terms like "TextBox (LineEdit)" extract both
    - Dash-separated terms like "Pmt — Periodic Payment" use the key term
    - NO individual word extraction (avoids noise like "Scope", "Started")
    """
    index = defaultdict(list)
    
    # Collect the document title (# header) to exclude from index
    doc_title = ""
    for _, level, display, anchor in headers:
        if level == 1:
            doc_title = display.lower()
            break
    
    skip_terms = {
        "overview", "example", "examples", "summary", "introduction",
        "next steps", "key points", "benefits", "tips",
        "see also", "usage tips", "best practices",
        "status legend", "compilation status",
        "files modified", "test files created",
        "implementation date: january 24, 2026",
        "feature completeness", "examples in one place",
        "putting it all together", "putting it together",
    }
    
    for _, level, display, anchor in headers:
        if display.lower() in ("table of contents", "alphabetical index"):
            continue
        
        # Clean display for index entry references
        clean = re.sub(r'\*\*([^*]+)\*\*', r'\1', display)
        clean = re.sub(r'\*([^*]+)\*', r'\1', clean)
        clean = re.sub(r'`([^`]+)`', r'\1', clean)
        clean = re.sub(r'[✅⚙️📋🎮📋🎯🔑🎨⚙️💡🚀❌]', '', clean).strip()
        
        # Skip very generic headers and the document title itself
        if clean.lower() in skip_terms or clean.lower() == doc_title:
            continue
        
        # Strategy 1: Remove numbering like "1." or "## 1. CLASS MODULES"
        main_term = re.sub(r'^\d+\.\s*', '', clean).strip()
        
        # Strategy 2: Extract function/method names: "GetNode(path As String)"
        func_match = re.match(r'^(\w+)\s*\(', main_term)
        if func_match:
            fname = func_match.group(1)
            index[fname].append((clean, anchor))
            continue
        
        # Strategy 3: Handle "Name (AlternateName)" patterns
        paren_match = re.match(r'^(.+?)\s*\(([^)]+)\)\s*$', main_term)
        if paren_match:
            primary = paren_match.group(1).strip()
            alt = paren_match.group(2).strip()
            index[primary].append((clean, anchor))
            if not alt.lower().startswith(('v2.', 'v3.', 'v4.', 'new ', 'fully', 'additional')):
                index[alt].append((clean, anchor))
            continue
        
        # Strategy 4: Handle "A / B" splitting
        if ' / ' in main_term and len(main_term) < 80:
            parts = main_term.split(' / ')
            for part in parts:
                part = part.strip()
                if part and len(part) > 1:
                    index[part].append((clean, anchor))
            continue
        
        # Strategy 5: Handle " — " descriptions: "Pmt — Periodic Payment"
        dash_match = re.match(r'^(\w[\w\s]*?)\s*[—–-]\s+(.+)$', main_term)
        if dash_match:
            term = dash_match.group(1).strip()
            index[term].append((clean, anchor))
            continue
        
        # Strategy 6: Use the full header text as-is (no individual word split)
        if main_term and len(main_term) < 100:
            index[main_term].append((clean, anchor))
    
    return dict(index)


def generate_index(index_terms: dict[str, list[tuple[str, str]]]) -> str:
    """Generate an alphabetical index with anchor links."""
    if not index_terms:
        return ""
    
    lines = [
        "---\n",
        "## Alphabetical Index\n",
        "*Quick-jump: ",
    ]
    
    # Group by first letter
    by_letter = defaultdict(list)
    for term in sorted(index_terms.keys(), key=lambda t: t.lower()):
        first = term[0].upper()
        if not first.isalpha():
            first = '#'
        by_letter[first].append(term)
    
    # Letter jump links
    letters = sorted(by_letter.keys())
    letter_links = []
    for letter in letters:
        letter_links.append(f"[{letter}](#index-{letter.lower() if letter != '#' else 'symbols'})")
    lines[2] += " · ".join(letter_links) + "*\n"
    
    # Generate entries by letter
    for letter in letters:
        anchor = f"index-{letter.lower() if letter != '#' else 'symbols'}"
        lines.append(f"\n### {letter} {{#{anchor}}}\n")
        
        for term in sorted(by_letter[letter], key=lambda t: t.lower()):
            refs = index_terms[term]
            # Deduplicate
            seen = set()
            unique_refs = []
            for display, anchor in refs:
                if anchor not in seen:
                    seen.add(anchor)
                    unique_refs.append((display, anchor))
            
            if len(unique_refs) == 1:
                display, anchor = unique_refs[0]
                lines.append(f"- **{term}** — [{display}](#{anchor})")
            else:
                ref_links = []
                for display, anchor in unique_refs:
                    # Shorten display for multi-ref entries
                    short = display if len(display) < 50 else display[:47] + "..."
                    ref_links.append(f"[{short}](#{anchor})")
                lines.append(f"- **{term}** — {' · '.join(ref_links)}")
    
    lines.append("")  # trailing newline
    return "\n".join(lines)


def process_file(rel_path: str, has_toc: bool):
    """Process a single documentation file: add TOC and/or index."""
    filepath = PROJECT_ROOT / rel_path
    if not filepath.exists():
        print(f"  SKIP (not found): {rel_path}")
        return
    
    text = filepath.read_text(encoding='utf-8')
    lines = text.split('\n')
    
    headers = parse_headers(lines)
    
    # --- Remove existing index if present ---
    # Look for the FIRST "## Alphabetical Index" in the file
    # (in case a prior buggy run left duplicates)
    idx_start = None
    for i in range(len(lines)):
        if lines[i].strip() == '## Alphabetical Index':
            # Check for preceding --- separator
            if i > 0 and lines[i-1].strip() == '---':
                idx_start = i - 1
            else:
                idx_start = i
            break
    
    if idx_start is not None:
        lines = lines[:idx_start]
        # Remove trailing blank lines
        while lines and lines[-1].strip() == '':
            lines.pop()
        headers = parse_headers(lines)  # re-parse without old index
    
    # --- Generate index ---
    index_terms = extract_index_terms(headers)
    index_text = generate_index(index_terms)
    
    # --- Handle TOC ---
    if not has_toc:
        toc_text = generate_toc(headers)
        # Find insertion point: after the first # header and any immediately following text
        insert_after = 0
        for i, line in enumerate(lines):
            if line.startswith('# ') and not line.startswith('## '):
                insert_after = i + 1
                # Skip any blank lines or subtitle text right after the title
                while insert_after < len(lines) and lines[insert_after].strip() == '':
                    insert_after += 1
                # If next line is descriptive text (not a header), skip it too
                while (insert_after < len(lines) and 
                       lines[insert_after].strip() != '' and 
                       not lines[insert_after].startswith('#')):
                    insert_after += 1
                # Skip trailing blanks
                while insert_after < len(lines) and lines[insert_after].strip() == '':
                    insert_after += 1
                break
        
        # Insert TOC
        toc_lines = toc_text.split('\n')
        lines = lines[:insert_after] + [''] + toc_lines + [''] + lines[insert_after:]
        # Re-parse after insertion
        headers = parse_headers(lines)
        index_terms = extract_index_terms(headers)
        index_text = generate_index(index_terms)
    
    # --- Append index at end ---
    # Make sure there's a blank line before the index
    while lines and lines[-1].strip() == '':
        lines.pop()
    lines.append('')
    lines.append(index_text)
    
    # Write back
    output = '\n'.join(lines)
    # Clean up excessive blank lines
    output = re.sub(r'\n{4,}', '\n\n\n', output)
    filepath.write_text(output, encoding='utf-8')
    
    term_count = len(index_terms)
    print(f"  ✅ {rel_path}: {term_count} index entries" + 
          (" + TOC added" if not has_toc else ""))


def main():
    print("VisualGasic Documentation Index Generator")
    print("=" * 50)
    
    for rel_path, has_toc, _ in DOC_FILES:
        process_file(rel_path, has_toc)
    
    print("\nDone! All files updated.")


if __name__ == '__main__':
    main()
