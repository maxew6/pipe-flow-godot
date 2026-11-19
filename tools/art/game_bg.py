"""Gameplay backdrop (assets/game/bg_game.png, 1080x1920): a plain forest-green vertical gradient.
Deliberately NO vignette, blobs or mottling: any radial/elliptical darkening reads as a dark curved
band behind the bottom controls. A touch of dither noise stops gradient banding on 8-bit screens."""
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from common import fbm, ramp

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
W, H = 1080, 1920

y = np.linspace(0, 1, H, dtype=np.float32)
col = ramp(y, [(0.0, (58, 156, 85)), (1.0, (14, 66, 40))])
rgb = np.repeat(col[:, None, :], W, axis=1)
rgb += (np.random.default_rng(3).random((H, W, 1)).astype(np.float32) - 0.5) * 2.2   # dither
out = os.path.join(ROOT, 'assets', 'game', 'bg_game.png')
Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB').save(out, optimize=True)
print('wrote', out)
