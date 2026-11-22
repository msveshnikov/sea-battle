"""Paint every texture of Sea Battle with numpy (run with system Python: numpy + pillow).

    python blender/scripts/make_textures.py

Writes PNGs into assets/textures/. Palette = style block of the design doc.
All tileable textures wrap on both axes (noise is built from periodic octaves).
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


def periodic_noise(h, w, cells, octaves=4, seed=0):
    """Tileable value noise in [0,1]: sum of upsampled random grids with wrap-around."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        grid = rng.random((c, c)).astype(np.float32)
        ys = np.linspace(0, c, h, endpoint=False)
        xs = np.linspace(0, c, w, endpoint=False)
        y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
        fy = ys - y0; fx = xs - x0
        fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
        y1 = (y0 + 1) % c; x1 = (x0 + 1) % c
        a = grid[y0][:, x0]; b = grid[y0][:, x1]; cc = grid[y1][:, x0]; d = grid[y1][:, x1]
        top = a + (b - a) * fx[None, :]
        bot = cc + (d - cc) * fx[None, :]
        out += amp * (top + (bot - top) * fy[:, None])
        total += amp
        amp *= 0.5
    return out / total


def rgb(hexstr):
    hexstr = hexstr.lstrip("#")
    return np.array([int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def save(name, img, alpha=None):
    img = np.clip(img, 0, 1)
    if alpha is not None:
        img = np.dstack([img, np.clip(alpha, 0, 1)])
    mode = "RGBA" if img.shape[2] == 4 else "RGB"
    Image.fromarray((img * 255).astype(np.uint8), mode).save(os.path.join(OUT, name))
    print("texture", name, img.shape)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


# ---------------------------------------------------------------- hull
def hull():
    """U = 8 m along the hull (tiles), V = z from -2 m (0) to +2 m (1); waterline at V = 0.5,
    red anti-fouling shows 0.22 m above it (as in the fleet sheet), black boot-top above that.
    Image row 0 is the TOP of the texture (V = 1)."""
    h, w = 512, 1024
    v = 1.0 - (np.arange(h) + 0.5) / h  # V per row
    V = np.repeat(v[:, None], w, 1)
    n = periodic_noise(h, w, 8, 5, 1)
    n2 = periodic_noise(h, w, 32, 3, 2)
    grey = rgb("#646b72")
    red = rgb("#8e2a24")
    black = rgb("#1d1f22")
    img = np.zeros((h, w, 3), np.float32)
    img[:] = grey
    img = img * (0.92 + 0.12 * n[..., None]) * (0.96 + 0.06 * n2[..., None])
    # plate seams: horizontal strakes every 0.45 m, vertical butts every 1.6 m (staggered)
    z = V * 4 - 2
    strake = np.abs(((z - 0.1) / 0.45) % 1.0 - 0.5)
    u_m = (np.arange(w) + 0.5) / w * 8.0
    U = np.repeat(u_m[None, :], h, 0)
    row = np.floor((z - 0.1) / 0.45)
    butt = np.abs(((U + (row % 2) * 0.8) / 1.6) % 1.0 - 0.5)
    seam = (strake > 0.485) | (butt > 0.494)
    img[seam] *= 0.78
    # plate highlight just above each seam (baked bevel shading)
    hl = (strake > 0.46) & (strake <= 0.485) & (((z - 0.1) / 0.45) % 1.0 < 0.5)
    img[hl] *= 1.07
    # rust streaks running down from portholes / scuppers
    streak_cols = periodic_noise(1, w, 64, 2, 3)[0]
    streaks = (streak_cols > 0.66).astype(np.float32)
    streak_len = np.clip((0.9 - V) * 3.0, 0, 1)
    rust = rgb("#7a4a2c")
    amt = (streaks[None, :] * (V > 0.6) * (V < 0.85) * streak_len * 0.35 * n2)
    img = lerp(img, np.broadcast_to(rust, img.shape), amt)
    # portholes at z = 0.55 m every 0.55 m
    pz = 0.8
    pv = (pz + 2) / 4
    py = (1 - pv) * h
    for x in np.arange(0.2, 8.0, 0.55):
        px = x / 8.0 * w
        yy, xx = np.ogrid[:h, :w]
        d = np.sqrt((yy - py) ** 2 + ((xx - px) * 0.5) ** 2 * 4)
        img[d < 4.2] = img[d < 4.2] * 0.55 + rgb("#3a3f44") * 0.2
        img[d < 3.0] = rgb("#14181c")
    # boot top and anti-fouling
    boot = (V > 0.555) & (V < 0.585)
    below = V <= 0.555
    img[boot] = black * (0.9 + 0.2 * n[boot][:, None])
    img[below] = red * (0.85 + 0.25 * n[below][:, None]) * (0.95 + 0.08 * n2[below][:, None])
    # algae/grime fading near the waterline
    grime = np.clip(1 - np.abs(V - 0.5) / 0.04, 0, 1) * 0.3 * n
    img = lerp(img, np.broadcast_to(rgb("#3d4a3a"), img.shape), grime)
    save("hull.png", img)


def deck():
    """Teak planks along U (U = 4 m, V = 4 m)."""
    h = w = 512
    plank_w = 0.16  # m
    vs = (np.arange(h) + 0.5) / h * 4.0
    us = (np.arange(w) + 0.5) / w * 4.0
    V, U = np.meshgrid(vs, us, indexing="ij")
    row = np.floor(V / plank_w)
    rng = np.random.default_rng(11)
    tone = rng.random(64)[(row % 64).astype(int)]
    off = rng.random(64)[(row % 64).astype(int)] * 4
    butt = ((U + off) % 2.0) < 0.012
    gap = (V / plank_w) % 1.0 > 0.93
    grain = periodic_noise(h, w, 4, 4, 5)
    fine = np.sin((U * 40 + grain * 20 + row * 3)) * 0.5 + 0.5
    base = rgb("#b8834f")
    img = np.zeros((h, w, 3), np.float32) + base
    img *= (0.82 + 0.25 * tone[..., None]) * (0.9 + 0.12 * fine[..., None]) * (0.92 + 0.1 * grain[..., None])
    img[gap] = rgb("#3b2a1c")
    img[butt] *= 0.55
    save("deck.png", img)


def steel():
    """Light neutral steel panels, 2 m tile; tinted per material by the base colour factor."""
    h = w = 512
    n = periodic_noise(h, w, 6, 5, 21)
    n2 = periodic_noise(h, w, 24, 3, 22)
    img = np.zeros((h, w, 3), np.float32) + 0.86
    img *= (0.9 + 0.14 * n[..., None]) * (0.96 + 0.06 * n2[..., None])
    ys = (np.arange(h) + 0.5) / h * 2
    xs = (np.arange(w) + 0.5) / w * 2
    Y, X = np.meshgrid(ys, xs, indexing="ij")
    seam = (np.abs((Y / 0.5) % 1 - 0.5) > 0.488) | (np.abs((X / 1.0) % 1 - 0.5) > 0.494)
    img[seam] *= 0.72
    rivet = ((np.abs((Y / 0.5) % 1 - 0.5) > 0.45) & (np.abs((X / 0.1) % 1 - 0.5) < 0.12))
    img[rivet] *= 0.85
    # grime collects at the bottom of each panel
    grime = np.clip(((Y / 0.5) % 1) - 0.75, 0, 1) * 1.4 * n2
    img *= (1 - 0.35 * grime[..., None])
    save("steel.png", img)


def windows():
    """Bridge windows: dark glass panes with frames. emissive twin for night."""
    h, w = 128, 512
    img = np.zeros((h, w, 3), np.float32) + 0.8
    emit = np.zeros((h, w, 3), np.float32)
    pane_w = 64
    for i in range(w // pane_w):
        x0 = i * pane_w + 8
        x1 = (i + 1) * pane_w - 8
        img[24:104, x0:x1] = rgb("#1b2a36")
        # sky reflection gradient
        grad = np.linspace(0.35, 0.0, 80)[:, None, None]
        img[24:104, x0:x1] += grad * rgb("#9cc7e6")
        lit = (i * 7919) % 5 != 0
        if lit:
            emit[24:104, x0:x1] = rgb("#ffcf7a") * (0.8 + 0.2 * ((i * 31) % 3) / 2)
    save("windows.png", img)
    save("windows_emit.png", emit)


def sand():
    h = w = 512
    n = periodic_noise(h, w, 8, 6, 31)
    speck = (RNG.random((h, w)) > 0.985).astype(np.float32)
    img = lerp(np.broadcast_to(rgb("#d9c08f"), (h, w, 3)).copy(), np.broadcast_to(rgb("#f2e2b8"), (h, w, 3)), n)
    img *= (1 - 0.25 * speck[..., None])
    save("sand.png", img)


def grass():
    h = w = 512
    n = periodic_noise(h, w, 6, 6, 41)
    n2 = periodic_noise(h, w, 40, 2, 42)
    img = lerp(np.broadcast_to(rgb("#3f7a2c"), (h, w, 3)).copy(), np.broadcast_to(rgb("#7fae3e"), (h, w, 3)), n)
    img *= (0.85 + 0.25 * n2[..., None])
    save("grass.png", img)


def rock():
    h = w = 512
    n = periodic_noise(h, w, 5, 6, 51)
    n2 = periodic_noise(h, w, 20, 4, 52)
    strata = np.sin((np.arange(h)[:, None] / h * 2 * np.pi * 9) + n * 6) * 0.5 + 0.5
    base = lerp(np.broadcast_to(rgb("#8a7b6a"), (h, w, 3)).copy(), np.broadcast_to(rgb("#c2b29a"), (h, w, 3)), n)
    img = base * (0.82 + 0.18 * strata[..., None]) * (0.85 + 0.25 * n2[..., None])
    cracks = np.abs(n2 - 0.5) < 0.012
    img[cracks] *= 0.6
    save("rock.png", img)


def bark():
    h = w = 256
    n = periodic_noise(h, w, 4, 4, 61)
    rings = (np.sin(np.arange(h)[:, None] / h * 2 * np.pi * 10 + n * 2) * 0.5 + 0.5)
    img = lerp(np.broadcast_to(rgb("#6b5236"), (h, w, 3)).copy(), np.broadcast_to(rgb("#a3825a"), (h, w, 3)), rings * 0.7 + n * 0.3)
    save("bark.png", img)


def palm_leaf():
    """One frond on a 256x1024 card: stem along the centre (V), leaflets with alpha."""
    h, w = 1024, 256
    ys = np.linspace(0, 1, h)[:, None]   # 0 = tip (row 0), 1 = base
    xs = np.linspace(-1, 1, w)[None, :]
    t = 1 - ys  # 1 at tip
    width = np.sin(np.clip(ys, 0, 1) * np.pi) ** 0.6 * 0.95
    # leaflets: diagonal strips
    ang = (np.abs(xs) * 2.2 + ys * 60) % 1.0
    leaflet = (ang < 0.72) & (np.abs(xs) < width)
    stem = np.abs(xs) < 0.035
    alpha = (leaflet | stem).astype(np.float32)
    n = periodic_noise(h, w, 8, 3, 71)
    col = lerp(np.broadcast_to(rgb("#2f6b23"), (h, w, 3)).copy(), np.broadcast_to(rgb("#86b43c"), (h, w, 3)), np.clip(n * 0.6 + np.abs(xs) * 0.6, 0, 1))
    col[np.broadcast_to(stem, (h, w))] = rgb("#9a8a4a")
    # dry tips
    col = lerp(col, np.broadcast_to(rgb("#b7a14a"), (h, w, 3)), np.clip((np.abs(xs) - width * 0.75) * 4, 0, 1) * 0.6)
    save("palm_leaf.png", col, alpha)


def plaster():
    h = w = 256
    n = periodic_noise(h, w, 6, 5, 81)
    img = np.zeros((h, w, 3), np.float32) + rgb("#f1ece2")
    img *= (0.9 + 0.12 * n[..., None])
    save("plaster.png", img)


def roof_tiles():
    h = w = 256
    ys = (np.arange(h) + 0.5) / h * 2
    xs = (np.arange(w) + 0.5) / w * 2
    Y, X = np.meshgrid(ys, xs, indexing="ij")
    row = np.floor(Y / 0.25)
    tile = ((X + row * 0.1) / 0.2) % 1.0
    shade = 0.75 + 0.25 * np.sin(tile * np.pi)
    edge = (Y / 0.25) % 1.0
    shade *= 0.8 + 0.2 * edge
    n = periodic_noise(h, w, 8, 3, 91)
    img = np.zeros((h, w, 3), np.float32) + rgb("#c2552d")
    img *= (shade * (0.9 + 0.15 * n))[..., None]
    save("roof.png", img)


def wood():
    h = w = 256
    n = periodic_noise(h, w, 4, 4, 101)
    ys = (np.arange(h) + 0.5) / h * 2
    Y = np.repeat(ys[:, None], w, 1)
    gap = (Y / 0.25) % 1 > 0.94
    img = lerp(np.broadcast_to(rgb("#6e5338"), (h, w, 3)).copy(), np.broadcast_to(rgb("#a07b52"), (h, w, 3)), n)
    img[gap] = rgb("#2c2016")
    save("wood.png", img)


def flag():
    """Fleet pennant: orange with a white anchor-ish chevron, used on masts and the logo."""
    h, w = 128, 192
    img = np.zeros((h, w, 3), np.float32) + rgb("#e9772b")
    yy, xx = np.mgrid[:h, :w]
    chev = np.abs((yy - h / 2) * 1.2) + (xx - w * 0.25)
    img[(chev > 20) & (chev < 44)] = rgb("#f6f1e6")
    save("flag.png", img)


if __name__ == "__main__":
    hull(); deck(); steel(); windows(); sand(); grass(); rock(); bark(); palm_leaf()
    plaster(); roof_tiles(); wood(); flag()
    print("DONE")
