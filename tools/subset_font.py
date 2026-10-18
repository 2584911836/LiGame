"""Rebuild the bundled UI font after adding Chinese strings (development only).
Usage: python tools/subset_font.py /path/to/NotoSansCJK-Regular.ttc
Requires fonttools; the Godot project itself has no Python dependency.
"""
from pathlib import Path
import sys
from fontTools import subset

root = Path(__file__).resolve().parents[1]
text = ''.join(p.read_text() for p in root.rglob('*.gd') if '.godot' not in p.parts)
text += ''.join(chr(i) for i in range(32, 127))
font = subset.load_font(sys.argv[1], subset.Options(font_number=0))
worker = subset.Subsetter()
worker.populate(text=text)
worker.subset(font)
subset.save_font(font, str(root / 'assets/ui-font.otf'), subset.Options())
