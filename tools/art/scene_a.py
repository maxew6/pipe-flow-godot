"""Menu scene, part A: sky, clouds, mountains, forested hills, house."""
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from common import *

W, H = 1200, 2400
HAZE = np.array((196, 224, 246), np.float32)


def build_sky():
    y = np.linspace(0, 1, H, dtype=np.float32)
    stops = [(0.0, (38, 134, 222)), (0.30, (70, 168, 238)), (0.55, (150, 212, 250)), (0.72, (205, 236, 252)), (1.0, (225, 244, 252))]
    col = ramp(y, stops)                       # (H,3)
    rgb = np.repeat(col[:, None, :], W, axis=1)
    noise = fbm(W, H, 5, 220, 4)
    rgb += (noise[..., None] - 0.5) * 10          # faint tonal variation
    # sun bloom, upper right (behind the big peak)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - 900) ** 2 + (yy - 520) ** 2) / 520.0
    bloom = np.clip(1 - d, 0, 1) ** 2.2 * 0.55
    rgb = rgb * (1 - bloom[..., None]) + np.array((255, 250, 225), np.float32) * bloom[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB').convert('RGBA')


def cloud(w, h, seed):
    Wc, Hc = w * SS, h * SS
    rng = np.random.default_rng(seed)
    m = Image.new('L', (Wc, Hc), 0)
    d = ImageDraw.Draw(m)
    base = Hc * 0.74
    x = Wc * 0.12
    while x < Wc * 0.86:
        edge = 1 - abs(x / Wc - 0.5) * 1.5
        r = Hc * (0.26 + 0.20 * rng.random()) * max(edge, 0.5)
        d.ellipse([x - r, base - r * 1.45, x + r, base + r * 0.4], fill=255)
        x += r * 0.85
    d.ellipse([Wc * 0.07, base - Hc * 0.16, Wc * 0.93, base + Hc * 0.22], fill=255)
    mask = np.asarray(m, np.float32) / 255
    mask = warp(mask, seed, amount=Hc * 0.03, scale=int(Hc * 0.12) + 4)
    mask = np.clip((ndi.gaussian_filter(mask, 3) - 0.5) * 6 + 0.5, 0, 1)
    sh = shade(mask, Hc * 0.16, 1.7)
    rgb = ramp(sh, [(0.0, (176, 205, 232)), (0.5, (238, 247, 255)), (1.0, (255, 255, 255))])
    yy = np.linspace(0, 1, Hc, dtype=np.float32)[:, None]
    under = smoothstep(0.62, 0.95, yy)[..., None]
    rgb = rgb * (1 - 0.45 * under) + np.array((148, 186, 224), np.float32) * 0.45 * under
    return down(to_img(rgb, ndi.gaussian_filter(mask, 1.2)))


def _jag(p0, p1, n, amt, rng):
    pts = [p0]
    nx, ny = -(p1[1] - p0[1]), (p1[0] - p0[0])
    L = math.hypot(nx, ny) or 1.0
    nx, ny = nx / L, ny / L
    for i in range(1, n):
        t = i / n
        j = (rng.random() - 0.5) * amt
        pts.append((p0[0] + (p1[0] - p0[0]) * t + nx * j, p0[1] + (p1[1] - p0[1]) * t + ny * j))
    pts.append(p1)
    return pts


def mountain(canvas, apex, left, right, base, seed, lit, shd, haze_amt):
    """Faceted peak: lit left face, shaded right face, extra facets, foot haze."""
    rng = np.random.default_rng(seed)
    ax, ay = apex
    x0, x1 = max(0, int(left) - 40), min(W, int(right) + 40)
    y0, y1 = max(0, int(ay) - 30), int(base) + 4
    w, h = x1 - x0, y1 - y0
    S = lambda p: ((p[0] - x0) * SS, (p[1] - y0) * SS)
    amt = (right - left) * 0.05
    le = [S(p) for p in _jag((left, base), (ax, ay), 9, amt, rng)]
    re = [S(p) for p in _jag((ax, ay), (right, base), 9, amt, rng)]
    rx = ax + (rng.random() - 0.35) * (right - left) * 0.14
    ridge = [S(p) for p in _jag((ax, ay), (rx, base), 8, amt * 0.7, rng)]
    bl, br = S((left, base + 6)), S((right, base + 6))
    lit_poly = le + ridge[1:] + [S((rx, base + 6)), bl]
    shd_poly = ridge + re[1:] + [br, S((rx, base + 6))]
    Wl, Hl = w * SS, h * SS
    noise = fbm(Wl, Hl, seed + 2, scale=60, octaves=4)
    yy = np.linspace(0, 1, Hl, dtype=np.float32)[:, None]
    out = Image.new('RGBA', (Wl, Hl), (0, 0, 0, 0))

    def face(poly, col):
        mk = poly_mask(Wl, Hl, poly)
        tone = 0.88 + 0.24 * noise
        rgb = np.zeros((Hl, Wl, 3), np.float32) + np.array(col[:3], np.float32)
        rgb *= tone[..., None]
        hz = (smoothstep(0.35, 1.0, yy) * haze_amt)[..., None]
        rgb = rgb * (1 - hz) + HAZE * hz
        out.alpha_composite(to_img(rgb, mk))

    face(lit_poly, lit)
    face(shd_poly, shd)
    # extra facets: a brighter slab on the lit side, a deeper one on the shaded side
    t1 = _jag((ax, ay), (left + (ax - left) * 0.25, base), 6, amt * 0.5, rng)
    t2 = _jag((ax, ay), (rx, base * 0.62 + ay * 0.38), 5, amt * 0.4, rng)
    slab = [S(p) for p in t1] + [S(p) for p in reversed(t2)]
    mk = poly_mask(Wl, Hl, slab)
    hi = np.zeros((Hl, Wl, 3), np.float32) + np.array(mix(lit, (255, 255, 255), 0.22)[:3], np.float32)
    out.alpha_composite(to_img(hi, mk * 0.55))
    blit(canvas, down(out), x0, y0)


def mountain_range(peaks, base, top_y, seed, lit, shd, haze_amt):
    """One continuous range lit from the upper left.
    The silhouette is a smooth profile built from rounded peaks; the relief comes from the
    distance-to-edge height field, so ridges and shaded faces follow the shape naturally
    (no hard straight cuts)."""
    xs = np.arange(W, dtype=np.float32)
    prof = np.zeros(W, np.float32)
    for (px, ph, pw) in peaks:
        prof = np.maximum(prof, ph * np.clip(1 - np.abs(xs - px) / pw, 0, 1) ** 1.12)
    prof += (fbm(W, 4, seed, 70, 4)[0] - 0.5) * 46 * (prof > 20)
    prof = ndi.gaussian_filter1d(prof, 5)
    Hh = int(base - top_y) + 40
    y0 = int(top_y)
    yy = (np.arange(Hh, dtype=np.float32) + y0)[:, None]
    top = (base - prof)[None, :]
    mask = (yy >= top).astype(np.float32)
    dist = ndi.distance_transform_edt(np.pad(mask, ((0, 0), (0, 0)), mode='edge'))
    relief = dist ** 0.82 + 26 * (fbm(W, Hh, seed + 5, 60, 4) - 0.5) * np.clip(dist / 40, 0, 1)
    relief = ndi.gaussian_filter(relief, 2.0)
    gy, gx = np.gradient(relief)
    d = -(gx * LIGHT[0] + gy * LIGHT[1])
    sh = np.clip(0.5 + d * 1.05, 0, 1)
    sh = np.clip(sh + (fbm(W, Hh, seed + 9, 28, 3) - 0.5) * 0.10, 0, 1)
    rgb = ramp(sh, [(0.0, shd), (0.5, mix(shd, lit, 0.5)[:3]), (1.0, lit)])
    t = np.clip((yy - y0) / (base - y0 + 1), 0, 1) * np.ones((1, W), np.float32)
    hz = (smoothstep(0.30, 1.0, t) * haze_amt)[..., None]
    rgb = rgb * (1 - hz) + HAZE * hz
    img = to_img(rgb, ndi.gaussian_filter(mask, 0.9))
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.alpha_composite(img, dest=(0, y0))
    return out


def build_mountains():
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    c.alpha_composite(mountain_range([(300, 330, 520), (700, 290, 430), (1010, 380, 520)], 1700, 1280, 11, (176, 208, 242), (136, 172, 222), 0.55))
    c.alpha_composite(mountain_range([(150, 520, 460), (790, 420, 520)], 1700, 1160, 12, (118, 170, 226), (66, 114, 178), 0.30))
    c.alpha_composite(mountain_range([(980, 660, 640)], 1730, 1060, 13, (92, 154, 216), (44, 90, 154), 0.14))
    return c


def canopy(w, h, seed, pal, n=16, haze=0.0, flat_bottom=False):
    Wc, Hc = w * SS, h * SS
    rng = np.random.default_rng(seed)
    m = Image.new('L', (Wc, Hc), 0)
    d = ImageDraw.Draw(m)
    for _ in range(n):
        cx = Wc * (0.2 + 0.6 * rng.random())
        cy = Hc * (0.28 + 0.42 * rng.random())
        r = min(Wc, Hc) * (0.17 + 0.15 * rng.random())
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    mask = np.asarray(m, np.float32) / 255
    mask = warp(mask, seed, amount=Wc * 0.02, scale=int(Wc * 0.07) + 4)
    mask = (ndi.gaussian_filter(mask, 2) > 0.5).astype(np.float32)
    if flat_bottom:
        mask[int(Hc * 0.86):, :] = 0
    sh = shade(mask, min(Wc, Hc) * 0.15, 1.9)
    noise = fbm(Wc, Hc, seed + 3, scale=int(Wc * 0.055) + 4, octaves=3)
    sh = np.clip(sh + 0.24 * smoothstep(0.56, 0.70, noise) * (sh > 0.32), 0, 1)
    yy = np.linspace(0, 1, Hc, dtype=np.float32)[:, None]
    sh = np.clip(sh - 0.22 * np.clip(yy - 0.55, 0, 1), 0, 1)
    rgb = ramp(sh, [(0.0, pal[0]), (0.5, pal[1]), (1.0, pal[2])])
    if haze > 0:
        rgb = rgb * (1 - haze) + HAZE * haze
    return down(to_img(rgb, ndi.gaussian_filter(mask, 1.0)))


def build_midground():
    """Forested foothills + a small cottage; sits between the mountains and the river."""
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    # rolling green foothills
    for k, (yb, col_top, col_bot, seed, amp) in enumerate([
        (1610, (86, 150, 120), (62, 128, 100), 21, 60),
        (1690, (58, 140, 84), (36, 108, 66), 22, 46),
    ]):
        xs = np.arange(0, W + 1, 6)
        ridge = yb - amp * (0.5 + 0.5 * np.sin(xs * 0.006 + seed)) - amp * 0.5 * fbm(len(xs), 2, seed, 30, 3)[0]
        pts = [(float(x), float(y)) for x, y in zip(xs, ridge)] + [(W, 1800.0), (0.0, 1800.0)]
        m = poly_mask(W, 1800, pts)
        hh = np.linspace(0, 1, 1800, dtype=np.float32)[:, None]
        rgb = ramp(np.broadcast_to(hh, (1800, W)), [(0.80, col_top), (1.0, col_bot)])
        c.alpha_composite(to_img(np.pad(rgb, ((0, 0), (0, 0), (0, 0))), m), dest=(0, 0))
    # distant tree clumps along the hills (hazy)
    rng = np.random.default_rng(31)
    pal_far = [((52, 112, 84), (82, 150, 108), (128, 188, 140)), ((44, 104, 70), (70, 140, 92), (112, 178, 124))]
    for i in range(16):
        x = 20 + i * 75 + rng.random() * 30
        s = int(120 + rng.random() * 90)
        t = canopy(s, int(s * 0.9), 40 + i, pal_far[i % 2], n=10, haze=0.30)
        blit(c, t, x - s / 2, 1640 - s * 0.55 + (i % 3) * 14)
    return c
