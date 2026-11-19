"""Shared helpers for the PIPE FLOW art generator.
Everything is drawn with 2x supersampling per element, then downsampled and
composited, so edges are clean. Shading uses a blurred-mask 'height field'
(light from the upper left) to give shapes soft volume without hand painting.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
from scipy import ndimage as ndi

SS = 2
LIGHT = (-0.55, -0.83)  # direction TOWARD the light (upper left)


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(len(c1)))


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def fbm(w, h, seed, scale=64, octaves=5, persistence=0.5, wrap=False):
    """Value-noise fractal, float32 0..1, shape (h, w)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(scale / (2 ** o)))
        gh, gw = h // s + 3, w // s + 3
        small = rng.random((gh, gw)).astype(np.float32)
        if wrap:
            small[:, -1] = small[:, 0]
            small[-1, :] = small[0, :]
        up = ndi.zoom(small, s, order=3, mode='wrap' if wrap else 'nearest')[:h, :w]
        out += up * amp
        total += amp
        amp *= persistence
    out /= total
    out -= out.min()
    out /= max(out.max(), 1e-6)
    return out


def ramp(t, stops):
    """Map array t (0..1) through colour stops [(pos, (r,g,b)), ...] -> (h,w,3) float."""
    t = np.clip(t, 0, 1)
    pos = [p for p, _ in stops]
    res = np.zeros(t.shape + (3,), np.float32)
    for ch in range(3):
        res[..., ch] = np.interp(t, pos, [c[ch] for _, c in stops])
    return res


def to_img(rgb, alpha):
    """rgb float (h,w,3) 0..255, alpha float (h,w) 0..1 -> RGBA PIL image."""
    a = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    arr = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), a])
    return Image.fromarray(arr, 'RGBA')


def shade(mask, sigma, strength=1.6, light=LIGHT):
    """Soft-volume brightness 0..1 derived from the blurred mask (0.5 = flat)."""
    hgt = ndi.gaussian_filter(mask.astype(np.float32), sigma)
    gy, gx = np.gradient(hgt)
    d = -(gx * light[0] + gy * light[1]) * sigma * strength
    return np.clip(0.5 + d * 0.5, 0, 1)


def poly_mask(w, h, pts):
    im = Image.new('L', (w, h), 0)
    ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return np.asarray(im, np.float32) / 255.0


def down(img):
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def blit(canvas, img, x, y):
    """alpha-composite img onto canvas at (x, y) (clips to the canvas)."""
    x, y = int(round(x)), int(round(y))
    sx, sy = max(0, -x), max(0, -y)
    ex, ey = min(img.width, canvas.width - x), min(img.height, canvas.height - y)
    if ex <= sx or ey <= sy:
        return
    part = img.crop((sx, sy, ex, ey))
    canvas.alpha_composite(part, dest=(x + sx, y + sy))


def warp(mask, seed, amount=10.0, scale=40):
    """Organic edge wobble."""
    h, w = mask.shape
    dx = (fbm(w, h, seed, scale, 3) - 0.5) * 2 * amount
    dy = (fbm(w, h, seed + 7, scale, 3) - 0.5) * 2 * amount
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return ndi.map_coordinates(mask, [yy + dy, xx + dx], order=1, mode='constant')


def glow(canvas, x, y, radius, color, alpha):
    """Soft radial light/mist blob (design-unit coordinates)."""
    r = int(radius)
    yy, xx = np.mgrid[-r:r, -r:r].astype(np.float32)
    d = np.sqrt(xx * xx + yy * yy) / r
    a = np.clip(1 - d, 0, 1) ** 2 * alpha
    img = to_img(np.full((2 * r, 2 * r, 3), color[:3], np.float32), a)
    blit(canvas, img, x - r, y - r)
