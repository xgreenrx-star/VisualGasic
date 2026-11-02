"""Render the Ash Meridian intro (alien holo face -> mouth tunnel -> light) to PNG frames.

The video ends on black after the blue cool-down; the game draws its live title menu
on top from MENU_START seconds. Usage:
  TUNNEL_LEN=26 python3 render_video.py <out_dir> [fps] [kind] [wire|holo]
"""
import math, os, sys
from multiprocessing import Pool
import numpy as np
from PIL import Image, ImageChops
import face as F

W, H = 960, 540
DURATION = 16.0

def ss(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a))); return t * t * (3 - 2 * t)

_ctx = {}

def _init(kind, holo):
    D = F.design(kind); V, T, E = F.build(D)
    _ctx.update(D=D, V=V, T=T, E=E, mc=F.mouth_center(D), holo=holo)

def frame(args):
    i, n, out = args
    D, V, T, E, mc = (_ctx[k] for k in ("D", "V", "T", "E", "mc"))
    t = i / (n - 1)
    fade = ss(0.0, 0.15, t)
    o = ss(0.30, 0.40, t)
    zoom = math.exp(math.log(80.0) * ss(0.40, 0.66, t))
    fx = 500 + (mc[0] - 500) * ss(0.40, 0.55, t)
    fy = 490 + (mc[1] - 490) * ss(0.40, 0.55, t)
    tun = ss(0.40, 0.97, t)
    img = F.render(D, V, T, E, o, (zoom, fx, fy), W=W, H=H, holo=_ctx["holo"], tunnel=tun)
    img = Image.eval(img, lambda v: int(v * fade))
    fl = ss(0.84, 0.91, t); m = ss(0.91, 1.0, t)
    if fl > 0 or m > 0:
        yy, xx = np.mgrid[0:H, 0:W]
        rr = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2 * 0.9)) ** 2)
        g = np.clip(1 - rr / max(0.05, fl * 1.25), 0, 1) ** 1.4
        img = ImageChops.lighter(img, Image.fromarray(np.stack([g * 225, g * 250, g * 255], -1).astype(np.uint8)))
        if m > 0:
            k = (1 - m) ** 1.5
            r, g_, b = img.split()
            img = Image.merge("RGB", (r.point(lambda v: int(v * k ** 3)), g_.point(lambda v: int(v * k ** 1.6)), b.point(lambda v: int(v * k))))
    img.save(os.path.join(out, f"f{i:04d}.png"))
    return i

if __name__ == "__main__":
    out = sys.argv[1]; fps = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    kind = sys.argv[3] if len(sys.argv) > 3 else "alien"
    holo = (sys.argv[4] if len(sys.argv) > 4 else "holo") == "holo"
    os.makedirs(out, exist_ok=True)
    n = int(DURATION * fps)
    only = os.environ.get("ONLY")
    idx = [int(x) for x in only.split(",")] if only else range(n)
    with Pool(os.cpu_count(), initializer=_init, initargs=(kind, holo)) as p:
        for done, _ in enumerate(p.imap_unordered(frame, [(i, n, out) for i in idx]), 1):
            if done % 40 == 0: print(f"{done}/{len(idx)}", flush=True)
