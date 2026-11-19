import os, sys
from PIL import Image
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
M = os.path.join(ROOT, 'assets', 'menu')
sys.path.insert(0, os.path.dirname(__file__))
import re
txt = open(os.path.join(ROOT, 'scripts', 'ui', 'menu_art_layout.gd')).read()
rects = {k: tuple(float(v) for v in re.findall(r'[-\d.]+', r)) for k, r in re.findall(r'"(\w+)": Rect2\(([^)]*)\)', txt)}
order = ['sky', 'cloud_1', 'cloud_2', 'cloud_3', 'cloud_4', 'mountains', 'midground', 'river', 'scenery', 'fg_br', 'fg_bl', 'fg_tl']
canvas = Image.new('RGBA', (1200, 2400))
for n in order:
    im = Image.open(os.path.join(M, n + '.png')).convert('RGBA')
    x, y = rects[n][0], rects[n][1]
    canvas.alpha_composite(im, dest=(int(x), int(y)))
canvas.save('/home/claude/menu_art_full.png')
canvas.convert('RGB').resize((600, 1200), Image.LANCZOS).save('/home/claude/preview_b.png')
print('composed')
