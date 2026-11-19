"""Python mock of the main menu (NOT a Godot screenshot): cover-scaled art + logo + 9-slice buttons.
Used only to sanity-check composition and safe areas before running the game."""
import re, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = __import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__), '..', '..'))
M, U = ROOT + '/assets/menu', ROOT + '/assets/ui'
txt = open(ROOT + '/scripts/ui/menu_art_layout.gd').read()
rects = {k: tuple(float(v) for v in re.findall(r'[-\d.]+', r)) for k, r in re.findall(r'"(\w+)": Rect2\(([^)]*)\)', txt)}
art = Image.new('RGBA', (1200, 2400))
for n in ['sky', 'cloud_1', 'cloud_2', 'cloud_3', 'cloud_4', 'mountains', 'midground', 'river', 'scenery', 'fg_br', 'fg_bl', 'fg_tl']:
    art.alpha_composite(Image.open(f'{M}/{n}.png').convert('RGBA'), dest=(int(rects[n][0]), int(rects[n][1])))


def cover(vw, vh):
    s = max(vw / 1200, vh / 2400)
    w, h = int(1200 * s), int(2400 * s)
    sc = art.resize((w, h), Image.LANCZOS)
    x, y = (vw - w) // 2, (vh - h) // 2
    out = Image.new('RGBA', (vw, vh))
    out.alpha_composite(sc.crop((-x, -y, -x + vw, -y + vh)))
    return out


def nine(img, w, h, l, t, r, b):
    out = Image.new('RGBA', (w, h))
    W, H = img.size
    for box, pos in [((0, 0, l, t), (0, 0)), ((W - r, 0, W, t), (w - r, 0)), ((0, H - b, l, H), (0, h - b)), ((W - r, H - b, W, H), (w - r, h - b))]:
        out.alpha_composite(img.crop(box), dest=pos)
    out.alpha_composite(img.crop((l, 0, W - r, t)).resize((w - l - r, t)), dest=(l, 0))
    out.alpha_composite(img.crop((l, H - b, W - r, H)).resize((w - l - r, b)), dest=(l, h - b))
    out.alpha_composite(img.crop((0, t, l, H - b)).resize((l, h - t - b)), dest=(0, t))
    out.alpha_composite(img.crop((W - r, t, W, H - b)).resize((r, h - t - b)), dest=(w - r, t))
    out.alpha_composite(img.crop((l, t, W - r, H - b)).resize((w - l - r, h - t - b)), dest=(l, t))
    return out


def render(vw, vh, name):
    k = vw / 1080
    f = lambda v: max(1, int(v * k))
    sc = cover(vw, vh)
    # layout maths mirrors scripts/screens/main_menu.gd (design px, viewport 1080 wide)
    design_h = vh / k
    fixed = 540 + 200 + 164 + 164 + 36 + 7 * 24
    free = design_h - 80 - fixed
    r = 0.7 + 1.0 + 0.9
    sp1, sp2 = free * 0.7 / r, free * 1.0 / r
    logo_y = 40 + sp1
    logo = Image.open(f'{U}/logo.png').convert('RGBA').resize((f(844), f(540)), Image.LANCZOS)
    sc.alpha_composite(logo, dest=((vw - f(844)) // 2, int(logo_y * k)))
    y = (logo_y + 540 + 24 + sp2 + 24)
    for text, kind, icon, h, fs in [('Play', 'green', 'icon_play', 200, 68), ('Levels', 'wood', 'icon_levels', 164, 56), ('Settings', 'wood', 'icon_settings', 164, 56)]:
        bt = Image.open(f'{U}/btn_{kind}.png').convert('RGBA')
        bw, bh = f(620), f(h)
        b = nine(bt, bw, bh, f(58), f(50), f(58), f(54))
        x0 = (vw - bw) // 2
        sc.alpha_composite(b, dest=(x0, int(y * k)))
        isz = f(100 if h >= 200 else 80)
        ic = Image.open(f'{U}/{icon}.png').convert('RGBA').resize((isz, isz), Image.LANCZOS)
        sc.alpha_composite(ic, dest=(x0 + f(44), int(y * k) + bh // 2 - isz // 2 - f(4)))
        d = ImageDraw.Draw(sc)
        font = ImageFont.truetype(ROOT + '/assets/fonts/Outfit-Bold.ttf', f(fs))
        tw = d.textlength(text, font=font)
        d.text(((vw - tw) / 2 + f(40), int(y * k) + bh / 2 - f(fs) * 0.62), text, font=font, fill=(255, 248, 232),
               stroke_width=max(1, f(8) // 2), stroke_fill={'green': (14, 70, 26), 'wood': (60, 30, 12)}[kind])
        y += h + 24
    d = ImageDraw.Draw(sc)
    d.text((vw / 2, vh - f(70)), 'v0.3.1', font=ImageFont.truetype(ROOT + '/assets/fonts/Outfit-Bold.ttf', f(30)), fill=(255, 255, 255, 170), anchor='mm')
    sc.convert('RGB').save(name)


render(1080, 1920, '/home/claude/mock_916_full.png')
render(1080, 2400, '/home/claude/mock_920_full.png')
from PIL import Image as _I
_I.open('/home/claude/mock_916_full.png').resize((540, 960), _I.LANCZOS).save('/home/claude/mock_916.png')
_I.open('/home/claude/mock_920_full.png').resize((540, 1200), _I.LANCZOS).save('/home/claude/mock_920.png')
print('mocks ok')
