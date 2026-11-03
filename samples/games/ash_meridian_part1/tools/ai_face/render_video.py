"""Render the Ash Meridian intro (alien holo face -> mouth tunnel -> light) to PNG frames.

The video ends on black after the blue cool-down; the game draws its live title menu
on top from MENU_START seconds. Usage:
  TUNNEL_LEN=26 python3 render_video.py <out_dir> [fps] [kind] [wire|holo]
"""
import math, os, sys
from multiprocessing import Pool
import numpy as np
from PIL import Image, ImageChops, ImageDraw
import face as F

W, H = 960, 540
DURATION = 16.0

def ss(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a))); return t * t * (3 - 2 * t)

_ctx = {}

def performance(t):
    look = ss(0.17, 0.27, t)
    turn = ss(0.20, 0.29, t)
    settle = (1-turn)*(1-ss(0.29,0.40,t))
    return dict(
        yaw=math.radians(-18)*(1-turn)+math.radians(1.2)*math.sin(t*35)*settle,
        roll=math.radians(-3)*(1-turn)+math.radians(1.5)*math.sin(t*18)*settle,
        eyes=(ss(0.105,0.19,t),ss(0.13,0.215,t)),
        gaze=-11*(1-look),
    )

def crt_space(img, t, mouth):
    yy,xx=np.mgrid[0:H,0:W]
    x=(xx-W/2)/(W/2); y=(yy-H/2)/(H/2)
    rng=np.random.default_rng(int(t*960))
    noise=rng.random((H,W))
    band=np.exp(-((y-((t*2.7)%2.6-1.3))/0.075)**2)
    quiet=1-0.7*ss(0.25,0.285,t)
    field=(4+noise*9*quiet+band*7)*(np.clip(1-0.45*(x*x+y*y),0,1))
    bg=Image.fromarray(np.stack((field*0.22,field,field*0.72),-1).astype(np.uint8))
    draw=ImageDraw.Draw(bg)
    draw.rounded_rectangle((24,16,W-25,H-17),radius=42,outline=(12,39,35),width=3)
    draw.rounded_rectangle((35,27,W-36,H-28),radius=34,outline=(5,20,24),width=2)
    for side in (-1,1):
        edge=W/2+side*W*0.32
        draw.line((edge,56,edge-side*32,H-56),fill=(5,18,21),width=1)
        draw.line((edge,56, W/2+side*W*0.43,36),fill=(5,18,21),width=1)
        draw.line((edge-side*32,H-56,W/2+side*W*0.43,H-36),fill=(5,18,21),width=1)
    for side in (-1,1):
        sx=W/2+side*W*0.39
        draw.line((sx,70,sx, H-70),fill=(4,16,19),width=1)
        for row in range(7):
            py=H*0.32+row*13
            draw.line((sx-10,py,sx+10,py),fill=(5,24,21),width=2)
    ghost=ImageChops.offset(img,int(-7*(1-ss(0.27,0.30,t))),2)
    ghost=Image.eval(ghost,lambda v:int(v*0.10*(1-ss(0.29,0.32,t))))
    img=ImageChops.add(ImageChops.add(img,ghost),bg)
    pixels=np.asarray(img).astype(float)
    # Bend the tube and pull its scan bands toward the mouth before the dive.
    pull=mouth*ss(0.30,0.40,t)
    r2=x*x+y*y
    sx=x*(1+0.035*r2)+x*pull*0.025/(0.12+r2)
    sy=y*(1+0.035*r2)+(y-0.35)*pull*0.018/(0.12+r2)
    ix=np.clip(((sx+1)*W/2).astype(int),0,W-1)
    iy=np.clip(((sy+1)*H/2).astype(int),0,H-1)
    pixels=pixels[iy,ix]
    scan=0.90+0.10*np.cos(yy*math.pi*0.67+pull*r2*18)
    vignette=np.clip(1-0.3*r2,0.25,1)
    pixels*= (scan*vignette)[:,:,None]
    return Image.fromarray(np.clip(pixels,0,255).astype(np.uint8))

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
    img = F.render(D, V, T, E, o, (zoom, fx, fy), W=W, H=H, holo=_ctx["holo"], tunnel=tun, **performance(t))
    if t<0.48:
        screen=crt_space(img,t,o)
        img=Image.blend(screen,img,ss(0.40,0.48,t))
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
    with Pool(min(4,os.cpu_count() or 1), initializer=_init, initargs=(kind, holo)) as p:
        for done, _ in enumerate(p.imap_unordered(frame, [(i, n, out) for i in idx]), 1):
            if done % 40 == 0: print(f"{done}/{len(idx)}", flush=True)
