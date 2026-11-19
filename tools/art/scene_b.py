"""Menu scene, part B: rocks, cliff, waterfall, water tower, river, foliage."""
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from common import *
from scene_a import W, H, HAZE, canopy

WOOD = ((92, 58, 30), (160, 106, 56), (214, 160, 96))
ROCK = ((44, 56, 74), (104, 118, 136), (186, 198, 210))


def rock(w, h, seed, pal=ROCK, moss=True):
    Wc, Hc = w * SS, h * SS
    rng = np.random.default_rng(seed)
    n = 36
    ang = np.linspace(0, 2 * np.pi, n, endpoint=False)
    rad = 1 + ndi.gaussian_filter1d(rng.standard_normal(n), 1.5, mode='wrap') * 0.16
    pts = []
    for a, r in zip(ang, rad):
        x = Wc * 0.5 + math.cos(a) * Wc * 0.49 * r
        y = Hc * 0.56 + math.sin(a) * Hc * 0.44 * r
        pts.append((x, min(y, Hc * 0.97)))
    mask = poly_mask(Wc, Hc, pts)
    mask = ndi.gaussian_filter(mask, 1.2)
    sh = shade(mask, min(Wc, Hc) * 0.2, 1.9)
    noise = fbm(Wc, Hc, seed + 1, scale=int(Wc * 0.1) + 4, octaves=4)
    sh = np.clip(sh + (noise - 0.5) * 0.30, 0, 1)
    yy = np.linspace(0, 1, Hc, dtype=np.float32)[:, None]
    sh = np.clip(sh - 0.20 * smoothstep(0.7, 1.0, yy), 0, 1)           # wet/dark base
    rgb = ramp(sh, [(0.0, pal[0]), (0.55, pal[1]), (1.0, pal[2])])
    if moss:
        mm = mask * smoothstep(0.50, 0.20, yy) * smoothstep(0.35, 0.55, noise + 0.25)
        mm = ndi.gaussian_filter(mm, 2.0)
        grn = ramp(np.clip(sh + 0.1, 0, 1), [(0, (40, 100, 48)), (0.6, (84, 164, 66)), (1, (150, 214, 92))])
        rgb = rgb * (1 - mm[..., None]) + grn * mm[..., None]
    img = to_img(rgb, np.clip((mask - 0.5) * 8 + 0.5, 0, 1))
    return down(img)


def leaf(length, width, seed, pal=((30, 96, 48), (58, 146, 62), (132, 204, 86)), curve=0.10, angle=0.0):
    """One pointed leaf rotated about its base. Returns (image, anchor_xy in design units)."""
    L = int(length * SS)
    Wc = Hc = 2 * L + 8
    c = L + 4
    t = np.linspace(0, 1, 48)
    cx = c + L * t
    cy = c - curve * L * np.sin(np.pi * t) * 1.4
    wp = width * SS * 0.5 * np.sin(np.pi * np.clip(t, 0, 1) ** 0.72) ** 0.9
    upper = [(x, y - w) for x, y, w in zip(cx, cy, wp)]
    lower = [(x, y + w) for x, y, w in zip(cx, cy, wp)]
    full = upper + lower[::-1]
    mask = poly_mask(Wc, Hc, full)
    sh = shade(mask, width * SS * 0.30, 1.6)
    up_m = poly_mask(Wc, Hc, upper + [(x, y) for x, y in zip(cx[::-1], cy[::-1])])
    sh = np.clip(sh + 0.16 * up_m - 0.06, 0, 1)
    rgb = ramp(sh, [(0.0, pal[0]), (0.55, pal[1]), (1.0, pal[2])])
    img = to_img(rgb, mask)
    d = ImageDraw.Draw(img)
    mid = [(float(x), float(y)) for x, y in zip(cx, cy)]
    d.line(mid[2:-3], fill=(*pal[2], 210), width=max(2, int(width * SS * 0.035)))
    for i in range(6, 44, 5):                                  # side veins
        x, y, w = cx[i], cy[i], wp[i]
        d.line([(x, y), (x + w * 0.9, y - w * 0.85)], fill=(*pal[2], 120), width=max(1, int(SS * 1.2)))
        d.line([(x, y), (x + w * 0.9, y + w * 0.85)], fill=(*pal[0], 120), width=max(1, int(SS * 1.2)))
    img = img.rotate(angle, resample=Image.BICUBIC, center=(c, c))
    return down(img), (c / SS, c / SS)


def rosette(canvas, base, n, lmin, lmax, wmin, wmax, a0, a1, seed, pal_set):
    rng = np.random.default_rng(seed)
    for i in range(n):
        a = a0 + (a1 - a0) * (i + rng.random() * 0.6) / n
        pal = pal_set[i % len(pal_set)]
        img, (ax, ay) = leaf(lmin + rng.random() * (lmax - lmin), wmin + rng.random() * (wmax - wmin),
                             seed + i, pal=pal, curve=0.06 + rng.random() * 0.12, angle=a)
        blit(canvas, img, base[0] - ax, base[1] - ay)


def wood_post(w, h, seed):
    Wc, Hc = w * SS, h * SS
    mask = np.ones((Hc, Wc), np.float32)
    xs = np.linspace(0, 1, Wc, dtype=np.float32)[None, :]
    sh = np.broadcast_to(1 - xs * 0.9, (Hc, Wc)) * 0.8 + 0.1
    grain = ndi.gaussian_filter(np.random.default_rng(seed).random((Hc, Wc)).astype(np.float32), (Hc * 0.15, 1.2))
    sh = np.clip(sh + (grain - 0.5) * 0.5, 0, 1)
    rgb = ramp(sh, [(0, WOOD[0]), (0.5, WOOD[1]), (1, WOOD[2])])
    return down(to_img(rgb, mask))


def tower():
    """Wooden water tower on stilts (design size 260 x 480)."""
    w, h = 260, 480
    Wc, Hc = w * SS, h * SS
    out = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    S = lambda v: v * SS
    # stilts + cross braces
    for x in (50, 96, 150, 196):
        post = wood_post(16, 150, int(x))
        out.alpha_composite(post.resize((post.width * SS, post.height * SS)), dest=(S(x - 8), S(330)))
    d = ImageDraw.Draw(out)
    for (a, b) in [((58, 350), (190, 450)), ((190, 350), (58, 450)), ((58, 400), (190, 400))]:
        d.line([(S(a[0]), S(a[1])), (S(b[0]), S(b[1]))], fill=hexc('5a3a1c'), width=S(7))
        d.line([(S(a[0]) - 2, S(a[1]) - 2), (S(b[0]) - 2, S(b[1]) - 2)], fill=hexc('a86d38'), width=S(3))
    # deck
    deck = poly_mask(Wc, Hc, [(S(28), S(318)), (S(232), S(318)), (S(244), S(342)), (S(16), S(342))])
    sh = shade(deck, S(6), 1.6)
    out.alpha_composite(to_img(ramp(sh, [(0, WOOD[0]), (0.55, WOOD[1]), (1, WOOD[2])]), deck))
    # tank (cylinder, light from the left)
    tank = np.zeros((Hc, Wc), np.float32)
    ImageDraw.Draw(Image.new('L', (1, 1)))
    tm = Image.new('L', (Wc, Hc), 0)
    ImageDraw.Draw(tm).rounded_rectangle([S(46), S(130), S(214), S(322)], radius=S(16), fill=255)
    tank = np.asarray(tm, np.float32) / 255
    xs = np.linspace(0, 1, Wc, dtype=np.float32)[None, :]
    cyl = np.clip(1.0 - np.abs((xs - 0.30) / 0.62) ** 1.6, 0, 1)
    cyl = np.broadcast_to(cyl, (Hc, Wc))
    grain = ndi.gaussian_filter(np.random.default_rng(3).random((Hc, Wc)).astype(np.float32), (Hc * 0.2, 1.0))
    shade_t = np.clip(cyl * 0.85 + 0.1 + (grain - 0.5) * 0.18, 0, 1)
    rgb = ramp(shade_t, [(0, WOOD[0]), (0.5, WOOD[1]), (1, WOOD[2])])
    out.alpha_composite(to_img(rgb, tank))
    d = ImageDraw.Draw(out)
    for xv in range(62, 212, 21):                                  # plank seams
        d.line([(S(xv), S(138)), (S(xv), S(318))], fill=(70, 42, 20, 150), width=SS)
    for yv in (176, 282):                                          # metal bands
        d.rounded_rectangle([S(44), S(yv), S(216), S(yv + 12)], radius=S(4), fill=hexc('5d6b79'), outline=hexc('2c3744'), width=SS)
        d.line([(S(50), S(yv + 3)), (S(205), S(yv + 3))], fill=hexc('b9c6d2'), width=SS)
    for wx in (82, 150):                                           # glass windows
        d.rounded_rectangle([S(wx), S(206), S(wx + 36), S(262)], radius=S(16), fill=hexc('8fd8f0'), outline=hexc('5a3a1c'), width=S(4))
        d.rounded_rectangle([S(wx + 6), S(212), S(wx + 14), S(246)], radius=S(4), fill=(255, 255, 255, 170))
    # roof cone
    cone = poly_mask(Wc, Hc, [(S(26), S(138)), (S(130), S(32)), (S(234), S(138))])
    roof_l = poly_mask(Wc, Hc, [(S(26), S(138)), (S(130), S(32)), (S(130), S(138))])
    base_col = np.zeros((Hc, Wc, 3), np.float32) + np.array((176, 50, 40), np.float32)
    lit = np.zeros((Hc, Wc, 3), np.float32) + np.array((226, 88, 62), np.float32)
    rgb = base_col * (1 - roof_l[..., None]) + lit * roof_l[..., None]
    out.alpha_composite(to_img(rgb, cone))
    d = ImageDraw.Draw(out)
    d.ellipse([S(18), S(124), S(242), S(152)], fill=hexc('8e2e24'), outline=hexc('5e1d17'), width=SS)
    for xv in range(58, 210, 26):
        d.line([(S(xv), S(138)), (S(130 + (xv - 130) * 0.1), S(40))], fill=(120, 30, 24, 130), width=SS)
    d.ellipse([S(120), S(18), S(140), S(38)], fill=hexc('d8a248'), outline=hexc('7a4e12'), width=SS)
    return down(out)


def cliff(w, h, seed):
    Wc, Hc = w * SS, h * SS
    rng = np.random.default_rng(seed)
    S = lambda v: v * SS
    top = [(0, 40)]
    for x in range(30, w - 60, 30):
        top.append((x, 36 + rng.random() * 18))
    edge = [(w - 70, 44), (w - 30, 120), (w - 52, 230), (w - 8, 330), (w - 40, 430), (w - 14, h - 6)]
    pts = [(S(x), S(y)) for x, y in top + edge] + [(S(w * 0.4), S(h)), (0, S(h))]
    mask = poly_mask(Wc, Hc, pts)
    mask = (ndi.gaussian_filter(warp(mask, seed, S(4), S(30)), 1.5) > 0.5).astype(np.float32)
    out = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    base = ramp(shade(mask, S(60), 1.2), [(0, ROCK[0]), (0.55, ROCK[1]), (1, ROCK[2])])
    out.alpha_composite(to_img(base, mask))
    rocks = []
    for r in range(11):
        for c in range(9):
            rocks.append((c * 52 + (r % 2) * 26 + rng.random() * 14 - 10, 70 + r * 40 + rng.random() * 12, 70 + rng.random() * 28, 52 + rng.random() * 22))
    rng.shuffle(rocks)
    tmp = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    for (x, y, rw, rh) in rocks:
        rk = rock(int(rw), int(rh), int(x * 7 + y), moss=(y < 200 or rng.random() < 0.12))
        tmp.alpha_composite(rk.resize((rk.width * SS, rk.height * SS)), dest=(int(S(x)), int(S(y))))
    m_img = Image.fromarray((mask * 255).astype(np.uint8), 'L')
    tmp.putalpha(ImageChops_multiply(tmp.getchannel('A'), m_img))
    out.alpha_composite(tmp)
    # grassy plateau top
    gm = mask * np.pad(np.zeros((1, 1), np.float32), 0)[0, 0] if False else None
    top_mask = np.zeros_like(mask)
    top_mask[: S(70), :] = 1
    top_mask *= mask
    g = ndi.gaussian_filter(top_mask * smoothstep(0.0, 1.0, np.linspace(1, 0.15, Hc, dtype=np.float32)[:, None]), 2)
    grass = ramp(np.broadcast_to(np.linspace(1, 0, Hc, dtype=np.float32)[:, None], (Hc, Wc)) * 0.8 + 0.1,
                 [(0, (36, 104, 52)), (0.6, (70, 150, 62)), (1, (130, 204, 84))])
    out.alpha_composite(to_img(grass, np.clip(g * 1.2, 0, 1)))
    return down(out)


def ImageChops_multiply(a, b):
    from PIL import ImageChops
    return ImageChops.multiply(a, b)


def waterfall(w, h, seed):
    """Water sheet widening toward the pool (design size w x h)."""
    Wc, Hc = w * SS, h * SS
    S = lambda v: v * SS
    pts = [(S(w * 0.22), 0), (S(w * 0.78), 0), (S(w * 0.96), S(h * 0.92)), (S(w * 0.04), S(h * 0.92))]
    mask = poly_mask(Wc, Hc, pts)
    mask = ndi.gaussian_filter(warp(mask, seed, S(2.5), S(24)), 1.2)
    yy = np.linspace(0, 1, Hc, dtype=np.float32)[:, None]
    xx = np.linspace(0, 1, Wc, dtype=np.float32)[None, :]
    streak = ndi.gaussian_filter(np.random.default_rng(seed).random((Hc, Wc)).astype(np.float32), (S(26), 1.6))
    streak = (streak - streak.min()) / (streak.max() - streak.min())
    t = np.clip(0.30 + 0.45 * yy + (streak - 0.5) * 0.75, 0, 1)
    t = t * np.ones_like(xx)
    edge = 1 - np.abs(xx - 0.5) * 2
    t = np.clip(t * (0.8 + 0.4 * edge) - 0.22 * (1 - edge) ** 2, 0, 1)
    rgb = ramp(t, [(0, (28, 142, 226)), (0.45, (74, 196, 250)), (0.8, (170, 232, 255)), (1, (250, 254, 255))])
    img = to_img(rgb, np.clip((mask - 0.5) * 6 + 0.5, 0, 1))
    return down(img)


def foam_and_mist(canvas, cx, cy, spread):
    rng = np.random.default_rng(9)
    for i in range(26):
        glow(canvas, cx + (rng.random() - 0.5) * spread, cy + (rng.random() - 0.5) * 36, 26 + rng.random() * 36, (255, 255, 255), 0.55)
    for i in range(10):
        glow(canvas, cx + (rng.random() - 0.5) * spread * 0.9, cy - 40 - rng.random() * 90, 60 + rng.random() * 50, (235, 248, 255), 0.22)


def build_river():
    top = 1735
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    xs = np.arange(0, W + 1, 8)
    edge = top + 36 * np.sin(xs * 0.0045 + 1.0) + 18 * np.sin(xs * 0.013) + (fbm(len(xs), 2, 77, 40, 3)[0] - 0.5) * 24
    pts = [(float(x), float(y)) for x, y in zip(xs, edge)] + [(W, H), (0, H)]
    m = poly_mask(W, H, pts)
    yy = np.linspace(0, 1, H, dtype=np.float32)[:, None] * np.ones((1, W), np.float32)
    v = np.clip((yy * H - 1700) / 700.0, 0, 1)
    rgb = ramp(v, [(0, (74, 208, 236)), (0.35, (36, 164, 228)), (0.75, (16, 112, 200)), (1, (10, 80, 164))])
    n = fbm(W, H, 55, 90, 4)
    rgb = rgb + (n[..., None] - 0.5) * 22
    c.alpha_composite(to_img(rgb, ndi.gaussian_filter(m, 1.0)))
    # painted ripples; arcs grow toward the viewer
    big = Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    rng = np.random.default_rng(88)
    for i in range(190):
        y = 1760 + (rng.random() ** 0.8) * 620
        x = rng.random() * W
        sc = 0.35 + (y - 1740) / 700.0
        rw, rh = 38 * sc * (0.6 + rng.random()), 7 * sc * (0.6 + rng.random())
        a = int(40 + 70 * rng.random())
        d.arc([(x - rw) * SS, (y - rh) * SS, (x + rw) * SS, (y + rh) * SS], 195, 345, fill=(255, 255, 255, a), width=max(2, int(3 * sc * SS)))
    ripple = down(big)
    c.alpha_composite(ripple)
    # trim ripples to the water body
    alpha = ndi.gaussian_filter(m, 1.0)
    arr = np.asarray(c).copy()
    arr[..., 3] = np.minimum(arr[..., 3], (alpha * 255).astype(np.uint8))
    return Image.fromarray(arr, 'RGBA')


def build_house():
    w, h = 220, 170
    Wc, Hc = w * SS, h * SS
    S = lambda v: v * SS
    out = Image.new('RGBA', (Wc, Hc), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    d.polygon([(S(24), S(70)), (S(120), S(70)), (S(120), S(150)), (S(24), S(150))], fill=hexc('d9cfb8'))
    d.polygon([(S(120), S(70)), (S(190), S(84)), (S(190), S(150)), (S(120), S(150))], fill=hexc('a99f8c'))
    d.polygon([(S(12), S(74)), (S(72), S(14)), (S(132), S(74))], fill=hexc('6f86a6'))
    d.polygon([(S(72), S(14)), (S(132), S(74)), (S(204), S(88)), (S(150), S(34))], fill=hexc('566c8c'))
    for (x, y) in ((40, 92), (80, 92)):
        d.rounded_rectangle([S(x), S(y), S(x + 26), S(y + 30)], radius=S(4), fill=hexc('7fb8d8'), outline=hexc('4a3a2a'), width=S(3))
    d.rectangle([S(140), S(100), S(168), S(150)], fill=hexc('7a5a3a'))
    d.rectangle([S(160), S(30), S(176), S(60)], fill=hexc('8a6a56'))
    img = down(out)
    arr = np.asarray(img).copy().astype(np.float32)
    arr[..., :3] = arr[..., :3] * 0.88 + HAZE * 0.12   # a little distance haze
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')
