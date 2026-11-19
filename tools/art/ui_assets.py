"""Builds the reusable UI kit into assets/ui/: wood + parchment panels, textured
buttons (green / blue / wood), icons, stars and the PIPE FLOW logo."""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
from scipy import ndimage as ndi
from common import *
import scene_b as B

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'ui')
FONT_DISPLAY = os.path.join(ROOT, 'assets', 'fonts', 'EricaOne-Regular.ttf')

WOOD_STOPS = [(0, (126, 74, 34)), (0.5, (184, 118, 58)), (1, (226, 160, 92))]


def rrect_mask(w, h, box, radius):
    im = Image.new('L', (w, h), 0)
    ImageDraw.Draw(im).rounded_rectangle(box, radius=radius, fill=255)
    return np.asarray(im, np.float32) / 255


def wood_rgb(w, h, seed, plank_h=None, stops=WOOD_STOPS):
    rng = np.random.default_rng(seed)
    n = ndi.gaussian_filter(rng.random((h, w)).astype(np.float32), (1.4, w * 0.18 + 6))
    n = (n - n.min()) / (n.max() - n.min() + 1e-6)
    fine = ndi.gaussian_filter(rng.random((h, w)).astype(np.float32), (0.8, 18))
    fine = (fine - fine.min()) / (fine.max() - fine.min() + 1e-6)
    rings = 0.5 + 0.5 * np.sin(n * 26.0 + fine * 3.0)
    t = np.clip(0.18 + 0.50 * n + 0.14 * rings + 0.12 * (fine - 0.5), 0, 1)
    rgb = ramp(t, stops)
    if plank_h:
        for y in range(plank_h, h, plank_h):
            rgb[max(0, y - 1):y + 1, :, :] *= 0.55
            rgb[y + 1:y + 3, :, :] *= 1.10
    return rgb


def drop_shadow(mask, dy, blur, alpha):
    sh = np.roll(mask, dy, axis=0)
    sh[:dy, :] = 0
    return ndi.gaussian_filter(sh, blur) * alpha


def compose_shadowed(w, h, body_img, mask, shadow_dy, shadow_blur, shadow_alpha):
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    sh = drop_shadow(mask, shadow_dy, shadow_blur, shadow_alpha)
    out.alpha_composite(to_img(np.zeros((h, w, 3), np.float32), sh))
    out.alpha_composite(body_img)
    return out


def button(kind, w=256, h=128, lip=10, radius=44, border=5):
    """Clean dimensional button, 256x128, built for 9-slice (margins L/R 52, T 50, B 58).
    Four simple parts only (no blurred shadow, no halo, no stacked glows):
      1. a darker 'lip' plate = the full pill silhouette (gives depth along the bottom edge),
      2. the face, sitting `lip` px higher, with a consistent outline,
      3. a subtle top-to-bottom face gradient,
      4. ONE smooth highlight across the upper part of the face.
    Every kind uses the same geometry, so all buttons share corner radius, outline and depth."""
    K = 4
    Wc, Hc = w * K, h * K
    R, LIP, BT = radius * K, lip * K, border * K
    D = {'green': (32, 128, 50), 'blue': (22, 66, 150), 'wood': (92, 52, 24)}[kind]
    plate = rrect_mask(Wc, Hc, [0, 0, Wc - 1, Hc - 1], R)
    face_h = Hc - LIP
    face = rrect_mask(Wc, Hc, [0, 0, Wc - 1, face_h - 1], R)
    inner = rrect_mask(Wc, Hc, [BT, BT, Wc - 1 - BT, face_h - 1 - BT], R - BT)
    ys = np.arange(Hc, dtype=np.float32)[:, None] * np.ones((1, Wc), np.float32)
    t = np.clip((ys - BT) / max(face_h - 2 * BT, 1), 0, 1)
    if kind == 'wood':
        rgb = wood_rgb(Wc, Hc, 12) * (1.08 - 0.14 * t[..., None])
    else:
        stops = {'green': [(0, (122, 226, 74)), (1, (60, 172, 50))],
                 'blue': [(0, (116, 190, 252)), (1, (48, 116, 222))]}[kind]
        rgb = ramp(t, stops)
    flat = lambda col: np.zeros((Hc, Wc, 3), np.float32) + np.array(col, np.float32)
    body = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    body.alpha_composite(to_img(flat(tuple(int(c * 0.92) for c in D)), plate))   # lip plate, just under the outline tone
    body.alpha_composite(to_img(flat(D), face))                                  # outline colour
    body.alpha_composite(to_img(rgb, inner))                                     # face
    top = BT + 5 * K
    bottom = top + int(0.30 * (face_h - 2 * BT))
    hl = rrect_mask(Wc, Hc, [BT + 6 * K, top, Wc - 1 - BT - 6 * K, bottom], max(8, R - BT - 8 * K))
    fade = 1.0 - np.clip((ys - top) / max(bottom - top, 1), 0, 1)
    body.alpha_composite(to_img(flat((255, 255, 255)), hl * (0.06 + 0.28 * fade)))
    return body.resize((w, h), Image.LANCZOS)


def icon_play_small(px=56):
    """Small white play glyph for in-button use (drawn natively at this size, no downscaling blur)."""
    K = 8
    S_ = px * K
    m = Image.new('L', (S_, S_), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S_ * 0.54, S_ * 0.5
    tri = [(S_ * 0.26, S_ * 0.16), (S_ * 0.26, S_ * 0.84), (S_ * 0.80, S_ * 0.5)]
    shrunk = [(cx + (x - cx) * 0.78, cy + (y - cy) * 0.78) for x, y in tri]
    rad = S_ * 0.07
    d.polygon(shrunk, fill=255)
    d.line(shrunk + [shrunk[0]], fill=255, width=int(2 * rad))
    for (x, y) in shrunk:
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=255)
    mask = np.asarray(m, np.float32) / 255
    img = to_img(np.zeros((S_, S_, 3), np.float32) + np.array((255, 255, 255), np.float32), mask)
    return img.resize((px, px), Image.LANCZOS)


def panel_wood(s=384):
    Wc = Hc = s * SS
    r = 46 * SS
    mask = rrect_mask(Wc, Hc, [10 * SS, 6 * SS, Wc - 10 * SS, Hc - 14 * SS], r)
    inner = rrect_mask(Wc, Hc, [20 * SS, 16 * SS, Wc - 20 * SS, Hc - 24 * SS], r - 10 * SS)
    rgb = wood_rgb(Wc, Hc, 21, plank_h=int(Hc / 2.6))
    yy = np.linspace(0, 1, Hc, dtype=np.float32)[:, None]
    rgb = rgb * (1 - 0.18 * smoothstep(0.8, 1.0, yy)[..., None])
    body = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    body.alpha_composite(to_img(np.zeros((Hc, Wc, 3), np.float32) + np.array((80, 44, 20), np.float32), mask))
    body.alpha_composite(to_img(rgb, inner))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([20 * SS, 16 * SS, Wc - 20 * SS, Hc - 24 * SS], radius=r - 10 * SS, outline=(255, 226, 170, 80), width=2 * SS)
    for (x, y) in [(44, 40), (s - 44, 40), (44, s - 48), (s - 44, s - 48)]:   # nails
        d.ellipse([(x - 9) * SS, (y - 9) * SS, (x + 9) * SS, (y + 9) * SS], fill=(88, 96, 108), outline=(40, 44, 52), width=2 * SS)
        d.ellipse([(x - 5) * SS, (y - 6) * SS, (x - 1) * SS, (y - 2) * SS], fill=(214, 224, 234))
    return down(compose_shadowed(Wc, Hc, body, mask, 6 * SS, 6 * SS, 0.35))


def panel_parchment(s=384):
    Wc = Hc = s * SS
    r = 54 * SS
    outer = rrect_mask(Wc, Hc, [10 * SS, 6 * SS, Wc - 10 * SS, Hc - 14 * SS], r)
    frame_in = rrect_mask(Wc, Hc, [34 * SS, 30 * SS, Wc - 34 * SS, Hc - 38 * SS], r - 24 * SS)
    wood = wood_rgb(Wc, Hc, 33, plank_h=int(Hc / 2.2))
    rng = np.random.default_rng(3)
    n = fbm(Wc, Hc, 9, 140, 4)
    parch = ramp(np.clip(0.45 + 0.35 * n, 0, 1), [(0, (232, 210, 160)), (1, (252, 240, 205))])
    edge = ndi.gaussian_filter(frame_in, 14 * SS)
    parch = parch * (0.80 + 0.20 * edge[..., None])      # soft inner shadow near the frame
    body = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    body.alpha_composite(to_img(np.zeros((Hc, Wc, 3), np.float32) + np.array((74, 40, 18), np.float32), outer))
    inner_wood = rrect_mask(Wc, Hc, [16 * SS, 12 * SS, Wc - 16 * SS, Hc - 20 * SS], r - 6 * SS)
    body.alpha_composite(to_img(wood, inner_wood))
    body.alpha_composite(to_img(np.zeros((Hc, Wc, 3), np.float32) + np.array((96, 56, 26), np.float32), frame_in))
    inner2 = rrect_mask(Wc, Hc, [38 * SS, 34 * SS, Wc - 38 * SS, Hc - 42 * SS], r - 28 * SS)
    body.alpha_composite(to_img(parch, inner2))
    d = ImageDraw.Draw(body)
    for (x, y) in [(36, 32), (s - 36, 32), (36, s - 40), (s - 36, s - 40)]:
        d.ellipse([(x - 8) * SS, (y - 8) * SS, (x + 8) * SS, (y + 8) * SS], fill=(88, 96, 108), outline=(40, 44, 52), width=2 * SS)
        d.ellipse([(x - 4) * SS, (y - 5) * SS, (x - 1) * SS, (y - 2) * SS], fill=(214, 224, 234))
    return down(compose_shadowed(Wc, Hc, body, outer, 8 * SS, 8 * SS, 0.38))


# ---------------------------------------------------------------- icons
def _glyph_canvas(s=192):
    return Image.new('RGBA', (s * SS, s * SS), (0, 0, 0, 0)), ImageDraw.Draw


def _finish_icon(img, shadow=True, s=192):
    a = np.asarray(img.getchannel('A'), np.float32) / 255
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    if shadow:
        sh = drop_shadow(a, 5 * SS, 4 * SS, 0.45)
        out.alpha_composite(to_img(np.zeros((img.height, img.width, 3), np.float32) + np.array((60, 30, 10), np.float32), sh))
    out.alpha_composite(img)
    return down(out)


def gradient_fill(size, mask, c_top, c_bot):
    h, w = mask.shape
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None] * np.ones((1, w), np.float32)
    return to_img(ramp(yy, [(0, c_top), (1, c_bot)]), mask)


def icon_play():
    img, _ = _glyph_canvas()
    S_ = 192 * SS
    m = Image.new('L', (S_, S_), 0)
    d = ImageDraw.Draw(m)
    cx, cy = 100, 96
    tri = [(64, 44), (64, 148), (154, 96)]
    shrunk = [(cx + (x - cx) * 0.72 + 0, cy + (y - cy) * 0.72) for x, y in tri]
    pts = [(x * SS, y * SS) for x, y in shrunk]
    d.polygon(pts, fill=255)
    rad = 17 * SS
    d.line(pts + [pts[0]], fill=255, width=2 * rad)
    for (x, y) in pts:
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=255)
    mask = np.asarray(m, np.float32) / 255
    img.alpha_composite(gradient_fill(S_, mask, (255, 255, 255), (214, 238, 206)))
    return _finish_icon(img)


def icon_levels():
    img, _ = _glyph_canvas()
    s = 192 * SS
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([22 * SS, 22 * SS, 170 * SS, 170 * SS], radius=26 * SS, fill=(112, 62, 30), outline=(70, 38, 16), width=4 * SS)
    for r in range(3):
        for c in range(3):
            x, y = 44 + c * 44, 44 + r * 44
            d.rounded_rectangle([x * SS, y * SS, (x + 34) * SS, (y + 34) * SS], radius=8 * SS, fill=(255, 250, 240))
    return _finish_icon(img)


def gear_polygon(cx, cy, r_out, r_in, teeth=10):
    pts = []
    for i in range(teeth * 4):
        a = math.pi * 2 * i / (teeth * 4)
        phase = i % 4
        r = r_out if phase in (1, 2) else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def icon_settings():
    img, _ = _glyph_canvas()
    s = 192 * SS
    d = ImageDraw.Draw(img)
    d.ellipse([14 * SS, 14 * SS, 178 * SS, 178 * SS], fill=(112, 62, 30), outline=(70, 38, 16), width=4 * SS)
    gp = [(x * SS, y * SS) for x, y in gear_polygon(96, 96, 56, 44, 9)]
    m = Image.new('L', (s, s), 0)
    ImageDraw.Draw(m).polygon(gp, fill=255)
    ImageDraw.Draw(m).ellipse([(96 - 49) * SS, (96 - 49) * SS, (96 + 49) * SS, (96 + 49) * SS], fill=255)
    ImageDraw.Draw(m).ellipse([(96 - 20) * SS, (96 - 20) * SS, (96 + 20) * SS, (96 + 20) * SS], fill=0)
    mask = np.asarray(m, np.float32) / 255
    mask = np.clip((ndi.gaussian_filter(mask, 2.0 * SS) - 0.5) * 8 + 0.5, 0, 1)
    img.alpha_composite(gradient_fill(s, mask, (255, 255, 255), (220, 214, 204)))
    return _finish_icon(img)


def icon_back():
    img, _ = _glyph_canvas()
    d = ImageDraw.Draw(img)
    pts = [(118 * SS, 44 * SS), (66 * SS, 96 * SS), (118 * SS, 148 * SS)]
    d.line(pts, fill=(255, 255, 255), width=24 * SS, joint='curve')
    for (x, y) in (pts[0], pts[2]):
        d.ellipse([x - 12 * SS, y - 12 * SS, x + 12 * SS, y + 12 * SS], fill=(255, 255, 255))
    return _finish_icon(img)


def icon_pause():
    img, _ = _glyph_canvas()
    d = ImageDraw.Draw(img)
    for x in (58, 108):
        d.rounded_rectangle([x * SS, 44 * SS, (x + 28) * SS, 148 * SS], radius=10 * SS, fill=(255, 255, 255))
    return _finish_icon(img)


def icon_lock():
    img, _ = _glyph_canvas()
    d = ImageDraw.Draw(img)
    d.arc([58 * SS, 30 * SS, 134 * SS, 120 * SS], 180, 360, fill=(196, 204, 214), width=15 * SS)
    d.line([(58 * SS, 76 * SS), (58 * SS, 100 * SS)], fill=(196, 204, 214), width=15 * SS)
    d.line([(134 * SS, 76 * SS), (134 * SS, 100 * SS)], fill=(196, 204, 214), width=15 * SS)
    d.rounded_rectangle([40 * SS, 92 * SS, 152 * SS, 164 * SS], radius=16 * SS, fill=(150, 160, 174), outline=(86, 94, 106), width=4 * SS)
    d.rounded_rectangle([46 * SS, 98 * SS, 146 * SS, 118 * SS], radius=10 * SS, fill=(190, 200, 212))
    d.ellipse([86 * SS, 120 * SS, 106 * SS, 140 * SS], fill=(70, 78, 90))
    d.rounded_rectangle([92 * SS, 132 * SS, 100 * SS, 150 * SS], radius=3 * SS, fill=(70, 78, 90))
    return _finish_icon(img)


def star(filled=True, s=192):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 84 if i % 2 == 0 else 38
        pts.append((96 + math.cos(a) * r, 100 + math.sin(a) * r))
    m = Image.new('L', (s * SS, s * SS), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    mask = np.asarray(m, np.float32) / 255
    mask = np.clip((ndi.gaussian_filter(mask, 6 * SS) - 0.5) * 10 + 0.5, 0, 1)     # rounded points
    img = Image.new('RGBA', (s * SS, s * SS), (0, 0, 0, 0))
    ring = np.clip(ndi.maximum_filter(mask, size=9 * SS), 0, 1)
    if filled:
        img.alpha_composite(to_img(np.zeros((s * SS, s * SS, 3), np.float32) + np.array((168, 98, 8), np.float32), ring))
        sh = shade(mask, 26 * SS, 1.4)
        yy = np.linspace(0, 1, s * SS, dtype=np.float32)[:, None]
        t = np.clip(0.2 + 0.55 * sh + 0.25 * (1 - yy), 0, 1)
        img.alpha_composite(to_img(ramp(t, [(0, (240, 150, 20)), (0.55, (255, 205, 56)), (1, (255, 244, 150))]), mask))
    else:
        img.alpha_composite(to_img(np.zeros((s * SS, s * SS, 3), np.float32) + np.array((74, 46, 24), np.float32), ring * 0.85))
        inner = np.clip(ndi.gaussian_filter(mask, 3 * SS), 0, 1)
        img.alpha_composite(to_img(np.zeros((s * SS, s * SS, 3), np.float32) + np.array((118, 80, 48), np.float32), mask * 0.8))
    return _finish_icon(img, shadow=filled)


# ---------------------------------------------------------------- logo
def logo():
    from PIL import ImageFont
    S2 = 2
    Wc, Hc = 1000 * S2, 640 * S2
    img = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    font = ImageFont.truetype(FONT_DISPLAY, 300 * S2)

    def word(text, cy, top, bot, outline_inner, tilt, tracking=22):
        layer = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
        advances = [font.getlength(ch) + tracking * S2 for ch in text]
        total = sum(advances) - tracking * S2
        x0 = (Wc - total) / 2
        bb = font.getbbox(text)
        ytxt = cy * S2 - (bb[1] + bb[3]) / 2

        def draw_text(px):
            mm = Image.new('L', (Wc, Hc), 0)
            dd = ImageDraw.Draw(mm)
            x = x0
            for ch, adv in zip(text, advances):
                dd.text((x, ytxt), ch, font=font, fill=255, stroke_width=px * S2, stroke_fill=255)
                x += adv
            return np.asarray(mm, np.float32) / 255

        base = draw_text(0)
        outer = draw_text(30)
        mid = draw_text(17)
        shadow = ndi.gaussian_filter(np.roll(outer, 14 * S2, axis=0), 7 * S2) * 0.45
        layer.alpha_composite(to_img(np.zeros((Hc, Wc, 3), np.float32) + np.array((10, 30, 70), np.float32), shadow))
        layer.alpha_composite(to_img(np.zeros((Hc, Wc, 3), np.float32) + np.array((16, 52, 116), np.float32), outer))
        layer.alpha_composite(to_img(np.zeros((Hc, Wc, 3), np.float32) + np.array(outline_inner, np.float32), mid))
        ys = np.nonzero(base.max(axis=1) > 0.5)[0]
        y0, y1 = ys.min(), ys.max()
        yy = np.clip((np.arange(Hc, dtype=np.float32)[:, None] - y0) / max(1, (y1 - y0)), 0, 1) * np.ones((1, Wc), np.float32)
        rgb = ramp(yy, [(0, top), (0.55, mix(top, bot, 0.55)[:3]), (1, bot)])
        gloss = (1 - smoothstep(0.0, 0.42, yy)) * 0.34
        rgb = rgb * (1 - gloss[..., None]) + 255 * gloss[..., None]
        rgb = rgb * (1 - 0.20 * smoothstep(0.8, 1.0, yy)[..., None])
        layer.alpha_composite(to_img(rgb, base))
        img.alpha_composite(layer)

    word('PIPE', 190, (255, 255, 255), (168, 198, 236), (84, 160, 232), 0.0)
    word('FLOW', 465, (255, 224, 98), (238, 124, 22), (255, 240, 200), 0.0)
    out = down(img.resize((Wc, Hc)))
    out = out.resize((Wc // S2 // 1, Hc // S2 // 1)) if False else out
    # leaf accent at the top-right of PIPE
    lf, (ax, ay) = B.leaf(130, 62, 7, pal=((30, 110, 50), (70, 170, 64), (160, 226, 96)), curve=0.14, angle=35)
    out.alpha_composite(lf, dest=(int(742 * 1.0 / 1.0 - ax + 130), int(70 - ay + 20)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    save = lambda im, n: im.save(os.path.join(OUT, n), optimize=True)
    save(button('green'), 'btn_green.png')
    save(button('blue'), 'btn_blue.png')
    save(button('wood'), 'btn_wood.png')
    save(panel_wood(), 'panel_wood.png')
    save(panel_parchment(), 'panel_parchment.png')
    for name, fn in [('icon_play', icon_play), ('icon_levels', icon_levels), ('icon_settings', icon_settings),
                     ('icon_back', icon_back), ('icon_pause', icon_pause), ('icon_lock', icon_lock)]:
        save(fn(), name + '.png')
    save(icon_play_small(), 'icon_play_btn.png')
    save(star(True), 'star_gold.png')
    save(star(False), 'star_empty.png')
    save(logo(), 'logo.png')
    print('ui assets written')


if __name__ == '__main__':
    main()
