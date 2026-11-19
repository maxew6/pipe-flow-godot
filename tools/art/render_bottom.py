"""Faithful offline render of the gameplay bottom control row (NOT a Godot screenshot):
real background + real button textures, 9-slice at design resolution (1080 wide), the same margins
GameButton uses. Used to diagnose and verify button/background artifacts."""
import sys, os, numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
U = ROOT + '/assets/ui'

def nine(img, w, h, l, t, r, b):
    out = Image.new('RGBA', (w, h)); W, H = img.size
    for box, pos in [((0,0,l,t),(0,0)), ((W-r,0,W,t),(w-r,0)), ((0,H-b,l,H),(0,h-b)), ((W-r,H-b,W,H),(w-r,h-b))]:
        out.alpha_composite(img.crop(box), dest=pos)
    out.alpha_composite(img.crop((l,0,W-r,t)).resize((w-l-r,t)), dest=(l,0))
    out.alpha_composite(img.crop((l,H-b,W-r,H)).resize((w-l-r,b)), dest=(l,h-b))
    out.alpha_composite(img.crop((0,t,l,H-b)).resize((l,h-t-b)), dest=(0,t))
    out.alpha_composite(img.crop((W-r,t,W,H-b)).resize((r,h-t-b)), dest=(w-r,t))
    out.alpha_composite(img.crop((l,t,W-r,H-b)).resize((w-l-r,h-t-b)), dest=(l,t))
    return out

def tint(img, mul):
    a = np.asarray(img).astype(float); a[..., :3] *= np.array(mul[:3]); a[..., 3] *= mul[3]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')

def render(margins, label, out, boost=False, disabled_start=False, icon=None):
    W, H = 1080, 1920
    bg = Image.open(ROOT + '/assets/game/bg_game.png').convert('RGBA')
    sc = bg.copy()
    d = ImageDraw.Draw(sc)
    # parchment message panel (approximation) above the buttons
    d.rounded_rectangle([28, 1592, 1052, 1722], radius=28, fill=(246, 230, 189), outline=(78, 49, 24), width=5)
    font = ImageFont.truetype(ROOT + '/assets/fonts/Outfit-Bold.ttf', 56)
    l, t, r, b = margins
    y, h = 1742, 140
    items = [('Reset', 'blue', 28, 290), ('Start Water', 'green', 342, 710)]
    for text, kind, x, w in items:
        tex = Image.open(f'{U}/btn_{kind}.png').convert('RGBA')
        btn = nine(tex, w, h, l, t, r, b)
        if disabled_start and kind == 'green':
            btn = tint(btn, (0.55, 0.55, 0.55, 0.9))
        sc.alpha_composite(btn, dest=(x, y))
        tw = d.textlength(text, font=font)
        sf = (10, 36, 92) if kind == 'blue' else (14, 70, 26)
        if kind == 'green':
            ic = Image.open(f'{U}/icon_play_btn.png').convert('RGBA')
            group = ic.width + 14 + tw
            gx = x + (w - group) / 2
            sc.alpha_composite(ic, dest=(int(gx), int(y + (h - 10) / 2 - ic.height / 2)))
            d.text((gx + ic.width + 14, y + 28), text, font=font, fill=(255, 248, 232), stroke_width=4, stroke_fill=sf)
        else:
            d.text((x + (w - tw) / 2, y + 28), text, font=font, fill=(255, 248, 232), stroke_width=4, stroke_fill=sf)
    crop = sc.crop((0, 1560, 1080, 1920)).convert('RGB')
    if boost:
        arr = np.asarray(crop).astype(float); m = arr.mean(axis=(0, 1)); crop = Image.fromarray(np.clip((arr - m) * 3 + m, 0, 255).astype(np.uint8))
    crop.save(out)

if __name__ == '__main__':
    render((52, 50, 52, 58), 'new', '/home/claude/bottom_final.png')
    render((52, 50, 52, 58), 'new', '/home/claude/bottom_final_boost.png', boost=True)
    render((52, 50, 52, 58), 'new', '/home/claude/bottom_final_disabled.png', disabled_start=True)
    print('ok')
