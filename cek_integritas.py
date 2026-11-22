#!/usr/bin/env python3
"""Validasi sederhana struktur buku gabungan. Tidak melakukan render Quarto.
Memerlukan PyYAML (`pip install pyyaml`).
"""
from pathlib import Path
from urllib.parse import unquote
from collections import Counter
import re, sys
import yaml
root = Path(__file__).resolve().parent
cfg = yaml.safe_load((root / '_quarto.yml').read_text(encoding='utf-8'))
assert cfg['project']['type'] == 'book'
chapters = []
for entry in cfg['book']['chapters']:
    if isinstance(entry, str): chapters.append(entry)
    elif isinstance(entry, dict):
        chapters += entry.get('chapters', [])
chapters += cfg['book'].get('appendices', [])
err=[]
for name in chapters:
    if not (root / name).is_file(): err.append('Bab/lampiran hilang: '+name)
for f in [root/'index.qmd'] + [root/x for x in chapters]:
    if not f.is_file(): continue
    content=f.read_text(encoding='utf-8')
    for raw in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', content):
        link=raw.split(' "')[0].split('#', 1)[0].strip()
        if not link or re.match(r'^(https?://|mailto:|data:)',link): continue
        link=unquote(link)
        if not (f.parent/link).exists(): err.append(f'{f.relative_to(root)}: tautan hilang {link}')
for p in [root/'images', root/'tise-six-themes/images']:
    for f in p.glob('*.png'):
        if f.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
            err.append('Bukan PNG valid: '+str(f.relative_to(root)))
if len(chapters) != len(set(chapters)): err.append('Daftar bab duplikat')
print('Bab/lampiran:',len(chapters))
print('Bagian:',sum(isinstance(e,dict) for e in cfg['book']['chapters']))
print('Gambar PNG:',len(list(root.rglob('*.png'))))
if err:
    print('\n'.join(err)); sys.exit(1)
print('OK: struktur Quarto, tautan lokal, dan header gambar PNG lolos pemeriksaan.')
