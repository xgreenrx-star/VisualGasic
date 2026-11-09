#!/usr/bin/env python3
"""Procedural art for the Ash Meridian resistance club.

Renders runtime textures into assets/club/ and concept renders into
docs/development/ash_meridian_club/. Deterministic (fixed seeds); rerun to
regenerate. Requires numpy, scipy and Pillow.

    python3 tools/club_art.py            # everything
    python3 tools/club_art.py textures   # runtime textures only
"""
import math
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
REPO = os.path.abspath(os.path.join(GAME, "..", "..", ".."))
TEX_DIR = os.path.join(GAME, "assets", "club")
DOC_DIR = os.path.join(REPO, "docs", "development", "ash_meridian_club")

# Club palette (linear-ish HDR values). Narcean cyan/amber stay as the
# "infrastructure" colours; the club adds ultraviolet, acid and coral.
CYAN = np.array([0.25, 0.95, 1.0])
AMBER = np.array([1.0, 0.62, 0.18])
UV = np.array([0.62, 0.22, 1.0])
MAGENTA = np.array([1.0, 0.18, 0.72])
ACID = np.array([0.55, 1.0, 0.25])
CORAL = np.array([1.0, 0.36, 0.30])
DEEP = np.array([0.02, 0.025, 0.05])
PALETTE = [CYAN, UV, MAGENTA, ACID, AMBER, CORAL]

# Narcean stroke alphabet (deep_stratum.vg glyph3): 14x18 box, six strokes.
GLYPH_PATHS = [
	[(0, 0), (7, 6), (14, 0)],
	[(0, 18), (7, 12), (14, 18)],
	[(0, 2), (0, 16)],
	[(14, 2), (14, 16)],
	[(3, 9), (11, 9)],
	[(7, -3), (7, 21)],
]
DIGITS = [15, 21, 38, 56, 41, 26, 52, 35, 29, 51]


# ---------------------------------------------------------------- utilities

def rng(seed):
	return np.random.default_rng(seed)


def grid(w, h):
	ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
	return xs + 0.5, ys + 0.5


def smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def value_noise(w, h, cells, seed, tile=False):
	r = rng(seed)
	cw, ch = max(2, int(cells)), max(2, int(cells * h / w))
	base = r.random((ch + 1, cw + 1)).astype(np.float32)
	if tile:
		base[-1, :] = base[0, :]
		base[:, -1] = base[:, 0]
	ys = np.linspace(0, ch, h, endpoint=False, dtype=np.float32)
	xs = np.linspace(0, cw, w, endpoint=False, dtype=np.float32)
	yy, xx = np.meshgrid(ys, xs, indexing="ij")
	return ndimage.map_coordinates(base, [yy, xx], order=3, mode="wrap" if tile else "nearest")


def fbm(w, h, cells, seed, octaves=5, tile=False):
	out = np.zeros((h, w), np.float32)
	amp, total = 1.0, 0.0
	for o in range(octaves):
		out += amp * value_noise(w, h, cells * (2 ** o), seed + o * 101, tile)
		total += amp
		amp *= 0.5
	out /= total
	out -= out.min()
	return out / max(out.max(), 1e-6)


def blur(img, sigma):
	if img.ndim == 2:
		return ndimage.gaussian_filter(img, sigma)
	return np.stack([ndimage.gaussian_filter(img[..., c], sigma) for c in range(img.shape[2])], -1)


def bloom(hdr, strength=1.0, threshold=0.6):
	lum = hdr.max(axis=2, keepdims=True)
	bright = hdr * smoothstep(threshold, threshold + 0.6, lum)
	acc = np.zeros_like(hdr)
	small = bright
	for sigma, weight in ((2, 0.55), (6, 0.45), (16, 0.35), (40, 0.25), (90, 0.18)):
		acc += blur(small, sigma) * weight
	return hdr + acc * strength


def tonemap(hdr, exposure=1.0):
	x = hdr * exposure
	a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
	y = np.clip((x * (a * x + b)) / (x * (c * x + d) + e), 0, 1)
	return np.power(y, 1 / 2.2)


def finish(hdr, seed, exposure=1.0, aberration=1.2, grain=0.025, vignette=0.35, bloom_strength=1.0):
	h, w, _ = hdr.shape
	hdr = bloom(hdr, bloom_strength)
	if aberration > 0:
		xs, ys = grid(w, h)
		cx, cy = w / 2, h / 2
		dx, dy = (xs - cx) / w, (ys - cy) / h
		r = ndimage.map_coordinates(hdr[..., 0], [ys + dy * aberration * 4, xs + dx * aberration * 4], order=1, mode="nearest")
		b = ndimage.map_coordinates(hdr[..., 2], [ys - dy * aberration * 4, xs - dx * aberration * 4], order=1, mode="nearest")
		hdr = np.stack([r, hdr[..., 1], b], -1)
	if vignette > 0:
		xs, ys = grid(w, h)
		d = np.sqrt(((xs - w / 2) / (w / 2)) ** 2 + ((ys - h / 2) / (h / 2)) ** 2)
		hdr *= (1 - vignette * smoothstep(0.55, 1.45, d))[..., None]
	ldr = tonemap(hdr, exposure)
	ldr += (rng(seed).standard_normal((h, w, 1)).astype(np.float32)) * grain
	return np.clip(ldr, 0, 1)


def save_rgb(arr, path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)
	print("wrote", os.path.relpath(path, REPO))


def save_rgba(rgb, alpha, path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	a = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
	c = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
	Image.fromarray(np.dstack([c, a]), "RGBA").save(path, optimize=True)
	print("wrote", os.path.relpath(path, REPO))


def save_gray(arr, path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "L").save(path, optimize=True)
	print("wrote", os.path.relpath(path, REPO))


# ------------------------------------------------------------ SDF drawing

def seg_dist(xs, ys, a, b):
	ax, ay = a
	bx, by = b
	px, py = xs - ax, ys - ay
	vx, vy = bx - ax, by - ay
	t = np.clip((px * vx + py * vy) / max(vx * vx + vy * vy, 1e-9), 0, 1)
	return np.hypot(px - vx * t, py - vy * t)


def polyline_dist(shape, pts, pad):
	"""Distance field to a polyline, evaluated only in its bounding box."""
	h, w = shape
	arr = np.array(pts, np.float32)
	x0 = int(max(0, math.floor(arr[:, 0].min() - pad)))
	x1 = int(min(w, math.ceil(arr[:, 0].max() + pad)))
	y0 = int(max(0, math.floor(arr[:, 1].min() - pad)))
	y1 = int(min(h, math.ceil(arr[:, 1].max() + pad)))
	if x1 <= x0 or y1 <= y0:
		return None
	ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
	xs += 0.5
	ys += 0.5
	d = np.full(xs.shape, 1e9, np.float32)
	for i in range(len(pts) - 1):
		d = np.minimum(d, seg_dist(xs, ys, pts[i], pts[i + 1]))
	return (slice(y0, y1), slice(x0, x1)), d


def neon(hdr, pts, width, color, glow=1.0, core=1.6):
	"""Additive neon tube: white-hot core, coloured body, soft halo."""
	pad = width * 28 + 40 if glow > 0 else width * 2 + 4
	res = polyline_dist(hdr.shape[:2], pts, pad)
	if res is None:
		return
	sl, d = res
	body = 1 - smoothstep(width * 0.5 - 0.8, width * 0.5 + 0.8, d)
	hot = 1 - smoothstep(width * 0.12, width * 0.3 + 0.6, d)
	halo = np.exp(-(d / (width * 2.2 + 1)) ** 2) * 0.5 + np.exp(-d / (width * 5 + 2)) * 0.25
	col = np.asarray(color, np.float32)
	hdr[sl] += (body[..., None] * col * core + hot[..., None] * (0.6 + col * 0.4) * core
		+ halo[..., None] * col * glow)


def paint(rgb, alpha, pts, width, color, opacity=1.0):
	"""Opaque anti-aliased stroke (over operator)."""
	res = polyline_dist(rgb.shape[:2], pts, width + 3)
	if res is None:
		return
	sl, d = res
	a = (1 - smoothstep(width * 0.5 - 0.7, width * 0.5 + 0.7, d)) * opacity
	rgb[sl] = rgb[sl] * (1 - a[..., None]) + np.asarray(color) * a[..., None]
	if alpha is not None:
		alpha[sl] = alpha[sl] + a * (1 - alpha[sl])


def glyph_paths(pattern, x, y, s):
	out = []
	for i, path in enumerate(GLYPH_PATHS):
		if pattern & (1 << i):
			out.append([(x + px * s, y + py * s) for px, py in path])
	return out


def neon_glyphs(hdr, patterns, x, y, s, color, width=None, glow=1.0):
	width = width or max(1.5, 1.7 * s)
	for k, p in enumerate(patterns):
		for path in glyph_paths(p, x + k * 23 * s, y, s):
			neon(hdr, path, width, color, glow)


def circle_pts(cx, cy, r, n=96, a0=0.0, a1=2 * math.pi):
	return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def disc(hdr, cx, cy, r, color, soft=1.0):
	h, w = hdr.shape[:2]
	x0, x1 = int(max(0, cx - r - soft * 4)), int(min(w, cx + r + soft * 4 + 1))
	y0, y1 = int(max(0, cy - r - soft * 4)), int(min(h, cy + r + soft * 4 + 1))
	if x1 <= x0 or y1 <= y0:
		return
	ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
	d = np.hypot(xs + 0.5 - cx, ys + 0.5 - cy)
	a = 1 - smoothstep(r - soft, r + soft, d)
	hdr[y0:y1, x0:x1] += a[..., None] * np.asarray(color)


# ------------------------------------------------------- resistance mark

def resistance_mark_strokes(cx, cy, s):
	"""The 'Rising Eye': an open ring (the club), a surface chevron lifting
	out through a gap at the top, a pierced spine and a broken bar (the
	governor, snapped). Built from the Narcean glyph vocabulary."""
	strokes = []
	strokes.append(circle_pts(cx, cy, 60 * s, 80, math.radians(-62), math.radians(242)))
	strokes.append([(cx - 34 * s, cy - 6 * s), (cx, cy - 40 * s), (cx + 34 * s, cy - 6 * s)])
	strokes.append([(cx - 24 * s, cy - 70 * s), (cx, cy - 98 * s), (cx + 24 * s, cy - 70 * s)])
	strokes.append([(cx, cy + 46 * s), (cx, cy - 56 * s)])
	strokes.append([(cx - 40 * s, cy + 18 * s), (cx - 8 * s, cy + 18 * s)])
	strokes.append([(cx + 9 * s, cy + 24 * s), (cx + 40 * s, cy + 12 * s)])
	return strokes


def spray(shape, strokes, width, seed, drips=True, wear=0.0):
	"""Spray-paint coverage: hard-ish core, overspray, speckle, drips, wear."""
	h, w = shape
	r = rng(seed)
	cov = np.zeros(shape, np.float32)
	over = np.zeros(shape, np.float32)
	speck = r.random(shape).astype(np.float32)
	jitter = fbm(w, h, 24, seed + 5, 3)
	for st in strokes:
		res = polyline_dist(shape, st, width * 4 + 6)
		if res is None:
			continue
		sl, d = res
		wid = width * (0.85 + 0.3 * jitter[sl])
		core = 1 - smoothstep(wid * 0.42, wid * 0.62, d)
		cov[sl] = np.maximum(cov[sl], core)
		over[sl] = np.maximum(over[sl], np.exp(-(d / (width * 1.1)) ** 2))
		if drips:
			for (px, py) in st[:: max(1, len(st) // 6)]:
				if r.random() < 0.55:
					ln = r.uniform(0.6, 3.2) * width
					dx = px + r.uniform(-0.25, 0.25) * width
					dw = r.uniform(0.12, 0.22) * width
					res2 = polyline_dist(shape, [(dx, py), (dx, py + ln)], dw * 2 + 4)
					if res2 is not None:
						sl2, d2 = res2
						cov[sl2] = np.maximum(cov[sl2], 1 - smoothstep(dw * 0.4, dw * 0.65, d2))
					disc_r = dw * 0.75
					yy, xx = np.ogrid[0:h, 0:w]
					m = (xx - dx) ** 2 + (yy - (py + ln)) ** 2 < disc_r ** 2
					cov[m] = 1
	speckle = (speck < over * 0.35).astype(np.float32) * over
	alpha = np.clip(cov + speckle * 0.7 + over * 0.12, 0, 1)
	if wear > 0:
		eroded = fbm(w, h, 10, seed + 9, 5)
		alpha *= smoothstep(wear - 0.15, wear + 0.1, eroded)
	return alpha


def make_mark(stage, size=1024, seed=0):
	"""Stage 0: plaza tag. 1: points to the train line. 2: tunnel ahead.
	3: over the service-door sign (final clue). 4: small, faded repeat."""
	h = w = size
	s = size / 300.0
	cx, cy = w / 2, h / 2 + 10 * s
	strokes = resistance_mark_strokes(cx, cy, s)
	accent = []
	if stage == 1:
		accent.append([(cx + 75 * s, cy + 70 * s), (cx + 130 * s, cy + 70 * s)])
		accent.append([(cx + 112 * s, cy + 55 * s), (cx + 132 * s, cy + 70 * s), (cx + 112 * s, cy + 85 * s)])
		for k in range(4):
			x = cx - 120 * s + k * 18 * s
			accent.append([(x, cy + 112 * s), (x + 10 * s, cy + 112 * s)])
		accent.append([(cx - 124 * s, cy + 104 * s), (cx - 124 * s + 76 * s, cy + 104 * s)])
		accent.append([(cx - 124 * s, cy + 120 * s), (cx - 124 * s + 76 * s, cy + 120 * s)])
	elif stage == 2:
		accent.append([(cx - 110 * s, cy + 108 * s), (cx + 110 * s, cy + 108 * s)])
		for k in range(3):
			x = cx - 40 * s + k * 34 * s
			accent.append([(x, cy + 92 * s), (x + 16 * s, cy + 108 * s), (x, cy + 124 * s)])
	elif stage == 3:
		accent.append([(cx - 30 * s, cy + 112 * s), (cx, cy + 135 * s), (cx + 30 * s, cy + 112 * s)])
	scale_w = 9 * s if stage != 4 else 7 * s
	wear = {0: 0.0, 1: 0.12, 2: 0.18, 3: 0.05, 4: 0.42}[stage]
	alpha = spray((h, w), strokes, scale_w, seed + stage * 17, True, wear)
	acc_a = spray((h, w), accent, scale_w * 0.7, seed + stage * 17 + 3, stage != 3, wear) if accent else np.zeros((h, w), np.float32)
	main_col = np.array([0.95, 0.32, 0.86]) if stage != 3 else np.array([0.35, 1.0, 0.85])
	acc_col = np.array([0.40, 1.0, 0.92])
	ink = fbm(w, h, 6, seed + 31, 3)[..., None]
	rgb = main_col * (0.85 + 0.25 * ink)
	rgb = rgb * (1 - acc_a[..., None]) + acc_col * acc_a[..., None]
	# UV-reactive fluorescence lives in a second, faint outline ring.
	return np.clip(rgb, 0, 1), np.clip(np.maximum(alpha, acc_a), 0, 1)


# ------------------------------------------------------------- video wall

def panel_eye(w, h, seed):
	hdr = np.zeros((h, w, 3), np.float32)
	xs, ys = grid(w, h)
	cx, cy = w / 2, h / 2
	dx, dy = (xs - cx) / (h * 0.45), (ys - cy) / (h * 0.45)
	r = np.hypot(dx, dy)
	ang = np.arctan2(dy, dx)
	lid = np.abs(dy) < 0.62 * np.sqrt(np.clip(1 - (dx / 1.9) ** 2, 0, 1))
	iris = smoothstep(0.62, 0.55, r) * lid
	fib = 0.5 + 0.5 * np.sin(ang * 64 + fbm(w, h, 8, seed, 3) * 9)
	iris_col = UV * (0.3 + 1.6 * fib[..., None] * (1 - r[..., None])) + CYAN * smoothstep(0.35, 0.05, r)[..., None] * 1.5
	pupil = smoothstep(0.17, 0.13, np.hypot(dx * 2.6, dy))
	hdr += iris[..., None] * iris_col * (1 - pupil[..., None])
	sclera = lid * (1 - iris)
	hdr += sclera[..., None] * DEEP * 3
	for sgn in (1, -1):
		pts = [(cx + x * h * 0.45, cy + sgn * 0.62 * math.sqrt(max(0, 1 - (x / 1.9) ** 2)) * h * 0.45) for x in np.linspace(-1.9, 1.9, 60)]
		neon(hdr, pts, 3, MAGENTA, 1.2)
	for k in range(14):
		a = k / 14 * 2 * math.pi
		neon(hdr, [(cx + math.cos(a) * h * 0.36, cy + math.sin(a) * h * 0.36), (cx + math.cos(a) * h * 0.5, cy + math.sin(a) * h * 0.5)], 1.5, AMBER, 0.6)
	disc(hdr, cx - h * 0.06, cy - h * 0.06, h * 0.03, np.array([3, 3, 3]))
	return hdr


def panel_mandala(w, h, seed):
	hdr = np.zeros((h, w, 3), np.float32)
	cx, cy = w / 2, h / 2
	r = rng(seed)
	for ring in range(5):
		rad = h * (0.08 + ring * 0.085)
		n = 6 + ring * 4
		col = PALETTE[(ring + seed) % len(PALETTE)]
		neon(hdr, circle_pts(cx, cy, rad, 128), 1.6, col * 0.8, 0.6)
		for k in range(n):
			a = k / n * 2 * math.pi + ring * 0.3
			s = h * (0.0035 + ring * 0.0006)
			gx, gy = cx + math.cos(a) * rad - 7 * s, cy + math.sin(a) * rad - 9 * s
			for path in glyph_paths(int(r.integers(1, 63)), gx, gy, s):
				neon(hdr, path, 1.2, col * 0.55, 0.35)
	for k in range(12):
		a = k / 12 * 2 * math.pi
		neon(hdr, [(cx, cy), (cx + math.cos(a) * h * 0.48, cy + math.sin(a) * h * 0.48)], 1.0, UV * 0.5, 0.5)
	return hdr


def panel_planet(w, h, seed):
	"""Narcea from orbit, surface lights, the ship leaving."""
	hdr = np.zeros((h, w, 3), np.float32)
	xs, ys = grid(w, h)
	r = rng(seed)
	for _ in range(220):
		disc(hdr, r.uniform(0, w), r.uniform(0, h * 0.6), r.uniform(0.4, 1.1), np.ones(3) * r.uniform(0.3, 1.5), 0.6)
	pcx, pcy, pr = w * 0.5, h * 1.55, h * 1.1
	d = np.hypot(xs - pcx, ys - pcy)
	inside = smoothstep(pr + 1, pr - 1, d)
	nz = np.sqrt(np.clip(1 - (d / pr) ** 2, 0, 1))
	land = fbm(w, h, 7, seed + 2, 5)
	city = (fbm(w, h, 60, seed + 3, 2) > 0.72) * (land > 0.5)
	surf = DEEP * 6 + (land[..., None] * np.array([0.05, 0.10, 0.16])) + city[..., None] * AMBER * 1.6
	hdr = hdr * (1 - inside[..., None]) + surf * inside[..., None] * (0.3 + nz[..., None])
	atm = np.exp(-np.abs(d - pr) / 9) * 1.4 + np.exp(-np.abs(d - pr) / 40) * 0.5
	hdr += atm[..., None] * CYAN
	sx, sy = w * 0.68, h * 0.28
	neon(hdr, [(w * 0.52, pcy - pr), (w * 0.58, h * 0.45), (sx, sy)], 2.0, AMBER, 1.4)
	disc(hdr, sx, sy, 4, np.array([4, 3, 2]))
	return hdr


def panel_tunnel(w, h, seed):
	"""Infinite glyph tunnel (also the music-reactive default)."""
	xs, ys = grid(w, h)
	dx, dy = (xs - w / 2) / h, (ys - h / 2) / h
	r = np.hypot(dx, dy) + 1e-4
	a = np.arctan2(dy, dx)
	z = 0.25 / r
	u = a / math.pi * 8
	rings = np.abs(np.sin(z * 9)) ** 24
	spokes = np.abs(np.sin(u * math.pi)) ** 30
	fade = smoothstep(0.0, 0.35, r)
	hue = (z * 0.15) % 1.0
	col = np.stack([0.5 + 0.5 * np.cos(6.283 * (hue + c)) for c in (0.0, 0.33, 0.67)], -1)
	hdr = (rings + spokes * 0.6)[..., None] * col * fade[..., None] * 2.2
	hdr += smoothstep(0.08, 0.0, r)[..., None] * np.array([2.0, 2.0, 2.4])
	return hdr.astype(np.float32)


def panel_feb_cross(w, h, seed):
	"""Propaganda: FEB silhouette, governor ring, struck through."""
	hdr = np.zeros((h, w, 3), np.float32)
	cx, cy, s = w / 2, h * 0.52, h / 300
	head = circle_pts(cx, cy - 70 * s, 26 * s, 48)
	body = [(cx - 50 * s, cy + 120 * s), (cx - 42 * s, cy - 30 * s), (cx, cy - 44 * s), (cx + 42 * s, cy - 30 * s), (cx + 50 * s, cy + 120 * s)]
	for p in (head, body):
		neon(hdr, p, 3, CORAL, 1.0)
	neon(hdr, [(cx - 34 * s, cy - 76 * s), (cx + 34 * s, cy - 64 * s)], 4, AMBER, 1.2)
	neon(hdr, circle_pts(cx, cy, 120 * s, 120), 5, MAGENTA, 1.2)
	neon(hdr, [(cx - 85 * s, cy - 85 * s), (cx + 85 * s, cy + 85 * s)], 6, MAGENTA, 1.4)
	neon_glyphs(hdr, [DIGITS[3], 63, DIGITS[7]], w * 0.06, h * 0.08, 2.2 * s, CYAN)
	return hdr


def panel_waveform(w, h, seed):
	hdr = np.zeros((h, w, 3), np.float32)
	r = rng(seed)
	bars = 48
	bw = w / bars
	for i in range(bars):
		v = abs(math.sin(i * 0.37 + seed)) * 0.6 + r.random() * 0.4
		hgt = v * h * 0.42
		x = (i + 0.5) * bw
		col = PALETTE[i * len(PALETTE) // bars]
		neon(hdr, [(x, h / 2 - hgt), (x, h / 2 + hgt)], bw * 0.42, col * 0.7, 0.5)
	pts = [(x, h / 2 + math.sin(x * 0.045 + seed) * h * 0.18 * math.sin(x * 0.006)) for x in np.linspace(0, w, 200)]
	neon(hdr, pts, 2.5, np.array([1.5, 1.5, 1.6]), 1.0)
	return hdr


def panel_face(w, h, seed):
	"""A Narcean face in vector hologram lines (not a specific character)."""
	hdr = np.zeros((h, w, 3), np.float32)
	cx, cy, s = w / 2, h / 2, h / 300
	for k in range(26):
		t = k / 25
		y = cy - 120 * s + t * 240 * s
		half = 70 * s * math.sqrt(max(0.0, 1 - ((t - 0.42) / 0.62) ** 2)) * (1 - 0.25 * t)
		pts = [(cx + x, y + 6 * s * math.sin(x / (half + 1) * 3.1)) for x in np.linspace(-half, half, 40)]
		neon(hdr, pts, 1.1, CYAN * (0.5 + 0.5 * t), 0.5)
	for side in (-1, 1):
		neon(hdr, [(cx + side * 18 * s, cy - 18 * s), (cx + side * 48 * s, cy - 26 * s), (cx + side * 62 * s, cy - 12 * s)], 3, MAGENTA, 1.4)
		disc(hdr, cx + side * 38 * s, cy - 18 * s, 4 * s, MAGENTA * 3)
	neon(hdr, [(cx - 22 * s, cy + 62 * s), (cx, cy + 70 * s), (cx + 22 * s, cy + 62 * s)], 2, UV, 1.0)
	neon(hdr, [(cx, cy - 150 * s), (cx, cy - 120 * s)], 2, AMBER, 1)
	return hdr


def panel_kaleido(w, h, seed):
	xs, ys = grid(w, h)
	dx, dy = (xs - w / 2) / h, (ys - h / 2) / h
	a = np.abs(((np.arctan2(dy, dx) / (2 * math.pi) * 10) % 1.0) - 0.5)
	r = np.hypot(dx, dy)
	n = fbm(64, 64, 4, seed, 4, tile=True)
	u = ndimage.map_coordinates(n, [(a * 120) % 64, (r * 140) % 64], order=1, mode="wrap")
	bands = np.abs(np.sin(u * 18 + r * 20)) ** 6
	hue = (u * 1.6 + r) % 1.0
	col = np.stack([0.5 + 0.5 * np.cos(6.283 * (hue + c)) for c in (0.0, 0.25, 0.6)], -1)
	return (bands[..., None] * col * 1.8 * smoothstep(0.55, 0.2, r)[..., None]).astype(np.float32)


def panel_glyph_rain(w, h, seed):
	hdr = np.zeros((h, w, 3), np.float32)
	r = rng(seed)
	s = h / 300 * 0.9
	cols = int(w / (18 * s))
	for c in range(cols):
		x = c * 18 * s + 2
		length = r.integers(4, 13)
		top = r.uniform(-60, h)
		for k in range(length):
			y = top + k * 24 * s
			if y > h:
				break
			bright = (k + 1) / length
			col = ACID * bright * 0.9 if k < length - 1 else np.array([2.2, 2.6, 2.0])
			for path in glyph_paths(int(r.integers(1, 63)), x, y, s * 0.8):
				neon(hdr, path, 1.0, col * 0.7, 0.15)
	return hdr


def panel_slogan(w, h, seed):
	"""'WE RISE' in Narcean glyphs over a gradient sunburst."""
	xs, ys = grid(w, h)
	a = np.arctan2(ys - h * 1.05, xs - w / 2)
	burst = (np.sin(a * 24) > 0).astype(np.float32)
	grad = smoothstep(h * 1.1, 0, ys)
	hdr = (burst * 0.25 + 0.15)[..., None] * (MAGENTA * grad[..., None] + UV * (1 - grad[..., None]))
	s = h / 300 * 3.0
	pats = [DIGITS[1], 63, DIGITS[8], DIGITS[4]]
	x0 = w / 2 - len(pats) * 23 * s / 2
	neon_glyphs(hdr, pats, x0, h * 0.30, s, np.array([1.1, 1.0, 0.9]), width=3.0, glow=0.5)
	return hdr.astype(np.float32)


def panel_scan(w, h, seed):
	"""Surface-route schematic: tunnel -> telepad -> deck (resistance briefing)."""
	hdr = np.zeros((h, w, 3), np.float32)
	xs, ys = grid(w, h)
	hdr += ((np.abs((xs % 24) - 12) < 0.6) | (np.abs((ys % 24) - 12) < 0.6))[..., None] * CYAN * 0.12
	pts = [(w * 0.08, h * 0.8), (w * 0.35, h * 0.8), (w * 0.45, h * 0.55), (w * 0.62, h * 0.55), (w * 0.62, h * 0.2), (w * 0.9, h * 0.2)]
	neon(hdr, pts, 3, AMBER, 1.2)
	for (px, py), col in zip([pts[0], pts[3], pts[5]], [CYAN, UV, MAGENTA]):
		neon(hdr, circle_pts(px, py, 14, 40), 2.5, col, 1.2)
	neon_glyphs(hdr, [DIGITS[2], DIGITS[9]], w * 0.66, h * 0.72, 2.2, CYAN)
	return hdr


def panel_storm(w, h, seed):
	"""Colour plasma: the wall's idle/ambient layer."""
	a = fbm(w, h, 3, seed, 5)
	b = fbm(w, h, 5, seed + 7, 4)
	t = (a * 1.5 + b) % 1.0
	col = np.stack([0.5 + 0.5 * np.cos(6.283 * (t + c)) for c in (0.0, 0.33, 0.67)], -1)
	ridge = (1 - np.abs(a - 0.5) * 2) ** 8
	return (col * (0.25 + 1.6 * ridge[..., None])).astype(np.float32)


def panel_rings(w, h, seed):
	hdr = np.zeros((h, w, 3), np.float32)
	r = rng(seed)
	for k in range(9):
		cx, cy = r.uniform(0.15, 0.85) * w, r.uniform(0.2, 0.8) * h
		rad = r.uniform(0.08, 0.35) * h
		col = PALETTE[k % len(PALETTE)]
		a0 = r.uniform(0, 6.28)
		neon(hdr, circle_pts(cx, cy, rad, 80, a0, a0 + r.uniform(2.0, 5.5)), r.uniform(2, 6), col, 1.0)
	return hdr


def panel_handprints(w, h, seed):
	"""Hands raised toward the surface - the community, not a crowd sim."""
	hdr = np.zeros((h, w, 3), np.float32)
	r = rng(seed)
	s = h / 300
	for k in range(7):
		bx = w * (0.1 + k * 0.13) + r.uniform(-10, 10)
		by = h * (0.95 - r.uniform(0.0, 0.2))
		col = PALETTE[k % len(PALETTE)]
		palm = circle_pts(bx, by - 30 * s, 16 * s, 30)
		neon(hdr, palm, 2.2, col, 1)
		for f in range(4):
			fx = bx - 12 * s + f * 8 * s
			neon(hdr, [(fx, by - 44 * s), (fx + (f - 1.5) * 2 * s, by - (66 + (f % 2) * 8) * s)], 2.2, col, 1)
		neon(hdr, [(bx + 14 * s, by - 34 * s), (bx + 26 * s, by - 48 * s)], 2.2, col, 1)
		neon(hdr, [(bx - 10 * s, by - 14 * s), (bx - 12 * s, by + 40 * s)], 2.2, col, 0.6)
	neon(hdr, circle_pts(w / 2, h * 0.15, 22 * s, 40), 3, np.array([2.2, 2, 1.4]), 1.4)
	return hdr


PANELS = [
	("tunnel", panel_tunnel), ("eye", panel_eye), ("mandala", panel_mandala), ("planet", panel_planet),
	("feb_cross", panel_feb_cross), ("waveform", panel_waveform), ("face", panel_face), ("kaleido", panel_kaleido),
	("glyph_rain", panel_glyph_rain), ("slogan", panel_slogan), ("route", panel_scan), ("storm", panel_storm),
	("rings", panel_rings), ("hands", panel_handprints), ("eye_alt", lambda w, h, s: panel_eye(w, h, s + 50)[:, ::-1] * np.array([0.6, 1.4, 1.0])),
	("mandala_alt", lambda w, h, s: panel_mandala(w, h, s + 3)),
]


def render_panel(fn, w, h, seed):
	hdr = fn(w, h, seed).astype(np.float32)
	return finish(hdr, seed, exposure=1.1, aberration=0.6, grain=0.012, vignette=0.2, bloom_strength=0.8)


def make_videowall_atlas(pw=512, ph=288):
	atlas = np.zeros((ph * 4, pw * 4, 3), np.float32)
	panels = {}
	for i, (name, fn) in enumerate(PANELS):
		img = render_panel(fn, pw, ph, 40 + i)
		panels[name] = img
		r, c = divmod(i, 4)
		atlas[r * ph:(r + 1) * ph, c * pw:(c + 1) * pw] = img
	return atlas, panels


# --------------------------------------------------------- disco orb

def make_orb(w=1024, h=512, seed=7):
	"""Equirectangular albedo + emission for the alien orb: irregular
	crystalline scales (Voronoi on the sphere), iridescent, with a band of
	inner-glow 'eyes' that the shader pulses on the beat."""
	r = rng(seed)
	n = 900
	v = r.standard_normal((n, 3))
	v /= np.linalg.norm(v, axis=1, keepdims=True)
	tree = cKDTree(v)
	lon = (np.arange(w) + 0.5) / w * 2 * math.pi - math.pi
	lat = math.pi / 2 - (np.arange(h) + 0.5) / h * math.pi
	LON, LAT = np.meshgrid(lon, lat)
	P = np.stack([np.cos(LAT) * np.cos(LON), np.sin(LAT), np.cos(LAT) * np.sin(LON)], -1)
	d, idx = tree.query(P.reshape(-1, 3), k=2)
	d = d.reshape(h, w, 2)
	idx = idx.reshape(h, w, 2)
	edge = d[..., 1] - d[..., 0]
	seam = 1 - smoothstep(0.0, 0.012 * (0.4 + 0.6 * np.cos(LAT)), edge)
	cell_rand = r.random(n)[idx[..., 0]]
	# Dark chrome facets with a thin-film sheen (cyan -> violet -> magenta).
	film = (cell_rand * 0.6 + np.abs(LAT) * 0.25) % 1.0
	sheen = np.stack([0.55 + 0.45 * np.cos(6.283 * (film * 0.5 + c)) for c in (0.62, 0.92, 0.12)], -1)
	chrome = 0.22 + 0.5 * cell_rand[..., None] ** 2
	albedo = chrome * (0.35 + 0.75 * sheen)
	albedo = albedo * (1 - seam[..., None]) + np.array([0.04, 0.03, 0.06]) * seam[..., None]
	eyes = r.random(n) < 0.05
	eye_mask = eyes[idx[..., 0]] * smoothstep(0.05, 0.0, d[..., 0])
	vein = seam * (0.35 + 0.65 * (fbm(w, h, 12, seed + 1, 3) > 0.55))
	emission = np.zeros((h, w, 3), np.float32)
	emission += eye_mask[..., None] * MAGENTA * 1.0
	emission += vein[..., None] * UV * 0.55
	# Channel-packed mask for the shader: R = facet id (random), G = eyes, B = veins.
	mask = np.stack([cell_rand, eye_mask, vein], -1)
	return np.clip(albedo, 0, 1), np.clip(emission, 0, 1), np.clip(mask, 0, 1)


def make_gobo(size=512, seed=11):
	"""Projected spot cookie: soft dots of mixed size plus a few glyph cut-outs."""
	r = rng(seed)
	hdr = np.zeros((size, size, 3), np.float32)
	for _ in range(70):
		disc(hdr, r.uniform(0, size), r.uniform(0, size), r.uniform(3, 11), np.ones(3), 2.0)
	for _ in range(6):
		for path in glyph_paths(int(r.integers(1, 63)), r.uniform(40, size - 60), r.uniform(40, size - 60), 1.8):
			neon(hdr, path, 3, np.ones(3) * 0.8, 0.0, core=0.7)
	xs, ys = grid(size, size)
	circ = smoothstep(size * 0.5, size * 0.44, np.hypot(xs - size / 2, ys - size / 2))
	return np.clip(hdr[..., 0] * circ, 0, 1)


def make_floor_masks(size=1024, seed=13):
	"""Hex dance floor. R/G/B = three tile groups the shader lights in
	sequence; A = grout/frame. Tileable."""
	hex_r = size / 16
	xs, ys = grid(size, size)
	qx = xs / (hex_r * math.sqrt(3))
	qy = ys / (hex_r * 1.5)
	# Axial rounding to nearest hex centre.
	q = (xs * math.sqrt(3) / 3 - ys / 3) / hex_r
	rr = (ys * 2 / 3) / hex_r
	cx_ = q
	cz_ = rr
	cy_ = -cx_ - cz_
	rx, ry, rz = np.round(cx_), np.round(cy_), np.round(cz_)
	dx, dy, dz = np.abs(rx - cx_), np.abs(ry - cy_), np.abs(rz - cz_)
	fix_x = (dx > dy) & (dx > dz)
	fix_y = (~fix_x) & (dy > dz)
	rx = np.where(fix_x, -ry - rz, rx)
	ry = np.where(fix_y, -rx - rz, ry)
	rz = np.where(~fix_x & ~fix_y, -rx - ry, rz)
	centre_x = hex_r * math.sqrt(3) * (rx + rz / 2)
	centre_y = hex_r * 1.5 * rz
	lx, ly = xs - centre_x, ys - centre_y
	# Hex distance (pointy-top).
	ax, ay = np.abs(lx), np.abs(ly)
	hexd = np.maximum(ax * math.sqrt(3) / 2 + ay / 2, ay) / hex_r
	group = ((rx.astype(int) - rz.astype(int)) % 3)
	inner = smoothstep(0.93, 0.86, hexd)
	glow = inner * (0.55 + 0.45 * smoothstep(0.9, 0.2, hexd))
	r = rng(seed)
	sparkle = (r.random(size * size).reshape(size, size) < 0.0015).astype(np.float32)
	sparkle = blur(sparkle, 1.0) * 6 * inner
	rgb = np.zeros((size, size, 3), np.float32)
	for g in range(3):
		rgb[..., g] = (group == g) * np.clip(glow + sparkle, 0, 1)
	grout = 1 - smoothstep(0.86, 0.95, hexd) * 0 - inner
	return rgb, np.clip(grout, 0, 1)


def make_fog(size=512, seed=17):
	n = fbm(size, size, 4, seed, 6, tile=True)
	return smoothstep(0.25, 0.85, n)


# ------------------------------------------------------------- flyers

def make_flyer(w, h, seed, variant):
	"""Narcean club flyers - all text is glyphs; Orac translates in-game."""
	hdr = np.zeros((h, w, 3), np.float32)
	xs, ys = grid(w, h)
	base = [UV, MAGENTA, CYAN][variant % 3]
	grad = (ys / h)[..., None]
	hdr += base * 0.10 * (1 - grad) + DEEP * 2
	s = w / 300
	if variant == 0:
		# Orb + rays: "TONIGHT BELOW".
		cx, cy = w / 2, h * 0.38
		for k in range(28):
			a = k / 28 * 2 * math.pi
			neon(hdr, [(cx + math.cos(a) * 60 * s, cy + math.sin(a) * 60 * s), (cx + math.cos(a) * 140 * s, cy + math.sin(a) * 140 * s)], 1.6, PALETTE[k % 6] * 0.8, 0.6)
		neon(hdr, circle_pts(cx, cy, 52 * s, 80), 4, np.array([1.8, 1.6, 2.2]), 1.2)
		neon_glyphs(hdr, [DIGITS[5], DIGITS[0], DIGITS[3]], w * 0.18, h * 0.70, 3.5 * s, np.array([2, 1.9, 1.6]), width=3.5)
	elif variant == 1:
		# Resistance mark, used openly inside the club.
		for st in resistance_mark_strokes(w / 2, h * 0.42, s * 0.95):
			neon(hdr, st, 5, MAGENTA, 1.2)
		neon_glyphs(hdr, [DIGITS[1], 63, DIGITS[8], DIGITS[4]], w * 0.08, h * 0.76, 2.8 * s, CYAN, width=3)
	else:
		# Waveform poster with a time code in glyph numerals.
		for i in range(30):
			x = w * 0.1 + i * w * 0.8 / 30
			hh = (abs(math.sin(i * 0.6)) * 0.7 + 0.3) * h * 0.18
			neon(hdr, [(x, h * 0.45 - hh), (x, h * 0.45 + hh)], 3, PALETTE[i % 6], 0.6)
		neon_glyphs(hdr, [DIGITS[2], DIGITS[5], DIGITS[5]], w * 0.18, h * 0.74, 3.5 * s, AMBER, width=3.5)
	img = finish(hdr, seed, exposure=1.0, aberration=0.4, grain=0.03, vignette=0.4, bloom_strength=0.7)
	# Paper wear: torn corner and fold creases.
	wear = fbm(w, h, 5, seed + 3, 5)
	img *= (0.75 + 0.25 * wear[..., None])
	img *= (1 - 0.12 * np.exp(-((xs - w / 2) / 2.5) ** 2))[..., None]
	alpha = np.ones((h, w), np.float32)
	tear = (xs + (h - ys)) < (w * 0.12 + wear * 40)
	alpha[tear] = 0
	return img, alpha


# ---------------------------------------------------------- concept art

def project_floor(xs, ys, horizon, f, cam_h):
	"""Screen -> floor plane (world x, z). Valid where ys > horizon."""
	dy = np.maximum(ys - horizon, 1e-3)
	z = f * cam_h / dy
	x = (xs - xs.shape[1] / 2) * z / f
	return x, z


def concept_interior(w=1920, h=1080, seed=101, panels=None, mark=None):
	"""Key art: the club at full power, viewed from the entrance landing."""
	r = rng(seed)
	xs, ys = grid(w, h)
	hdr = np.zeros((h, w, 3), np.float32)
	horizon = h * 0.47
	f = w * 0.62
	cam_h = 1.7
	# Back-wall and room shell: dark brick vault lit from below.
	brick = fbm(w, h, 40, seed, 3)
	mortar = ((np.abs((ys % 26) - 13) < 1.2) | (np.abs(((xs + (ys // 26 % 2) * 30) % 60) - 30) < 1.2)).astype(np.float32)
	wall = DEEP * 1.4 + np.array([0.03, 0.02, 0.04]) * brick[..., None] - mortar[..., None] * 0.012
	hdr += wall * (ys < horizon + 40)[..., None]
	# Vaulted ceiling arch.
	arch = ys < (h * 0.12 + (np.abs(xs - w / 2) / (w / 2)) ** 2 * h * 0.25)
	hdr[arch] *= 0.35
	for k in range(-6, 7):
		x0 = w / 2 + k * 150
		neon(hdr, [(x0, 0), (w / 2 + k * 90, h * 0.16)], 1.0, AMBER * 0.08, 0.05)
	# Video wall: 4x2 tiles of the atlas behind a DJ booth.
	vw_x0, vw_x1, vw_y0, vw_y1 = w * 0.28, w * 0.72, h * 0.15, h * 0.43
	tw, th = int((vw_x1 - vw_x0) / 4), int((vw_y1 - vw_y0) / 2)
	order = ["tunnel", "eye", "slogan", "mandala", "hands", "planet", "glyph_rain", "kaleido"]
	for i, name in enumerate(order):
		img = np.asarray(Image.fromarray((panels[name] * 255).astype(np.uint8)).resize((tw - 6, th - 6), Image.LANCZOS), np.float32) / 255
		img = np.power(img, 2.2) * 1.1
		ry, cx = divmod(i, 4)
		y0 = int(vw_y0 + ry * th + 3)
		x0 = int(vw_x0 + cx * tw + 3)
		# LED pixel grid.
		gy, gx = np.mgrid[0:th - 6, 0:tw - 6]
		led = 0.55 + 0.45 * ((gx % 4 < 3) & (gy % 4 < 3))
		hdr[y0:y0 + th - 6, x0:x0 + tw - 6] = img * led[..., None]
	neon(hdr, [(vw_x0 - 6, vw_y0 - 6), (vw_x1 + 6, vw_y0 - 6), (vw_x1 + 6, vw_y1 + 6), (vw_x0 - 6, vw_y1 + 6), (vw_x0 - 6, vw_y0 - 6)], 2, CYAN * 0.5, 0.5)
	# Video wall light spill onto room.
	spill = blur(hdr * (ys < vw_y1 + 8)[..., None], 80) * 0.45
	hdr += spill
	# Floor: hex dance floor in perspective with glossy reflections.
	fx, fz = project_floor(xs, ys, horizon, f, cam_h)
	below = ys > horizon + 1
	hex_r = 0.55
	q = (fx * math.sqrt(3) / 3 - fz / 3) / hex_r
	rz_ = (fz * 2 / 3) / hex_r
	rq, rr_ = np.round(q), np.round(rz_)
	ry_ = np.round(-q - rz_)
	dq, dr, dy_ = np.abs(rq - q), np.abs(rr_ - rz_), np.abs(ry_ + q + rz_)
	rq = np.where((dq > dr) & (dq > dy_), -ry_ - rr_, rq)
	rr_ = np.where(~((dq > dr) & (dq > dy_)) & (dr > dy_), -rq - ry_, rr_)
	ccx = hex_r * math.sqrt(3) * (rq + rr_ / 2)
	ccz = hex_r * 1.5 * rr_
	lx, lz = np.abs(fx - ccx), np.abs(fz - ccz)
	hexd = np.maximum(lx * math.sqrt(3) / 2 + lz / 2, lz) / hex_r
	group = ((rq.astype(np.int64) - rr_.astype(np.int64)) % 3)
	floor_zone = (np.abs(fx) < 4.5) & (fz > 3.0) & (fz < 11.5)
	tile_on = np.where(group == 0, 1.0, np.where(group == 1, 0.35, 0.08))
	tile_col = np.where((group == 0)[..., None], MAGENTA, np.where((group == 1)[..., None], CYAN, UV))
	inner = smoothstep(0.92, 0.86, hexd) * (0.35 + 0.9 * smoothstep(0.55, 0.88, hexd))
	dist_fade = 1 / (1 + (fz / 9) ** 2)
	floor = tile_col * (inner * tile_on * dist_fade)[..., None] * 0.9 * floor_zone[..., None]
	concrete = (DEEP * 1.5 + np.array([0.02, 0.02, 0.025]) * brick[..., None]) * (~floor_zone)[..., None]
	hdr[below] = (hdr[below] * 0.0) + floor[below] + concrete[below]
	# Reflections of the video wall on the polished floor.
	refl_src = np.flipud(hdr[: int(horizon)])
	refl = np.zeros_like(hdr)
	n = min(refl_src.shape[0], h - int(horizon))
	refl[int(horizon): int(horizon) + n] = refl_src[:n]
	ripple = fbm(w, h, 30, seed + 4, 2)
	refl = blur(refl, 5) * (0.22 * smoothstep(0.2, 0.9, ripple))[..., None]
	hdr += refl * below[..., None]
	# Orb + beams.
	ox, oy, orad = w * 0.5, h * 0.27, h * 0.085
	beams = np.zeros_like(hdr)
	fogn = fbm(w, h, 8, seed + 6, 5)
	for k in range(14):
		ang = math.radians(r.uniform(20, 160))
		length = r.uniform(0.6, 1.2) * w
		tx, ty = ox + math.cos(ang) * length, oy + math.sin(ang) * length
		col = PALETTE[k % len(PALETTE)]
		res = polyline_dist((h, w), [(ox, oy), (tx, ty)], 220)
		if res is None:
			continue
		sl, d = res
		along = np.hypot(xs[sl] - ox, ys[sl] - oy)
		spread = 4 + along * 0.06
		beam = np.exp(-(d / spread) ** 2) * np.exp(-along / (length * 0.9))
		beams[sl] += beam[..., None] * col * 0.5
		disc(hdr, tx, ty, r.uniform(8, 18), col * 0.7, 6)
	beams *= (0.15 + 1.1 * smoothstep(0.35, 0.85, fogn))[..., None]
	hdr += beams
	# Gobo spots on the walls.
	for _ in range(160):
		px, py = r.uniform(0, w), r.uniform(h * 0.05, h * 0.95)
		if vw_x0 < px < vw_x1 and vw_y0 < py < vw_y1:
			continue
		disc(hdr, px, py, r.uniform(2, 5) * (1.6 if py > horizon else 1), PALETTE[int(r.integers(0, 6))] * r.uniform(0.3, 0.9), 2.0)
	# The orb itself: faceted sphere.
	oy0, oy1, ox0, ox1 = int(oy - orad - 2), int(oy + orad + 2), int(ox - orad - 2), int(ox + orad + 2)
	sx, sy = xs[oy0:oy1, ox0:ox1] - ox, ys[oy0:oy1, ox0:ox1] - oy
	rr = np.hypot(sx, sy) / orad
	inside = rr < 1
	nz = np.sqrt(np.clip(1 - rr ** 2, 0, 1))
	n3 = np.stack([sx / orad, sy / orad, nz], -1)
	pts = r.standard_normal((300, 3))
	pts /= np.linalg.norm(pts, axis=1, keepdims=True)
	dd, ii = cKDTree(pts).query(n3.reshape(-1, 3), k=2)
	dd = dd.reshape(sx.shape + (2,))
	ii = ii.reshape(sx.shape + (2,))
	facet = r.random(300)[ii[..., 0]]
	seam = smoothstep(0.03, 0.0, dd[..., 1] - dd[..., 0])
	hue = (facet * 0.5 + 0.6) % 1
	irid = np.stack([0.5 + 0.5 * np.cos(6.283 * (hue + c)) for c in (0.0, 0.33, 0.67)], -1)
	spark = (facet > 0.93) * 4.0
	orb = irid * (0.25 + 1.2 * facet[..., None] ** 3) + spark[..., None]
	orb = orb * (1 - seam[..., None]) + UV * 0.8 * seam[..., None]
	orb *= (0.4 + 0.6 * nz)[..., None]
	region = hdr[oy0:oy1, ox0:ox1]
	region[inside] = orb[inside]
	neon(hdr, [(ox, 0), (ox, oy - orad)], 2, AMBER * 0.4, 0.1)
	neon(hdr, circle_pts(ox, oy, orad + 6, 90), 1.5, MAGENTA * 0.6, 0.8)
	# Speaker stacks: silhouettes rim-lit by the wall.
	for side in (-1, 1):
		bx = w / 2 + side * w * 0.33
		for k in range(3):
			y0 = h * 0.28 + k * h * 0.13
			box = [(bx - 70, y0), (bx + 70, y0), (bx + 70, y0 + h * 0.125), (bx - 70, y0 + h * 0.125)]
			yy0, yy1, xx0, xx1 = int(y0), int(y0 + h * 0.125), int(bx - 70), int(bx + 70)
			hdr[yy0:yy1, xx0:xx1] *= 0.12
			neon(hdr, box + [box[0]], 1.2, CYAN * 0.35, 0.2)
			neon(hdr, circle_pts(bx, y0 + h * 0.062, 42, 60), 2.0, MAGENTA * 0.6, 0.4)
			neon(hdr, circle_pts(bx, y0 + h * 0.062, 14, 40), 1.4, AMBER * 0.7, 0.4)
	# DJ booth: glyph LED strip and a console silhouette.
	by0, by1 = int(h * 0.44), int(h * 0.53)
	hdr[by0:by1, int(w * 0.36):int(w * 0.64)] *= 0.1
	neon(hdr, [(w * 0.36, by0), (w * 0.64, by0)], 2.5, AMBER, 0.8)
	neon_glyphs(hdr, [DIGITS[1], 63, DIGITS[8], DIGITS[4], 0, DIGITS[5], DIGITS[0], DIGITS[3]], w * 0.40, by0 + 14, 1.6, CYAN, width=2)
	# Side-wall graffiti: the resistance mark, UV-reactive.
	if mark is not None:
		mrgb, ma = mark
		for side, px in ((-1, int(w * 0.03)), (1, int(w * 0.83))):
			size = int(h * 0.26)
			im = Image.fromarray((np.dstack([mrgb, ma]) * 255).astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
			if side < 0:
				im = im.transform((size, size), Image.PERSPECTIVE, (1.0, 0.18, 0, 0, 1.0, 0, 0, 0.00035), Image.BICUBIC)
			arr = np.asarray(im, np.float32) / 255
			py = int(h * 0.30)
			reg = hdr[py:py + size, px:px + size]
			reg += np.power(arr[..., :3], 2.2) * arr[..., 3:4] * 1.6
	# Low fog over the floor, tinted by beams.
	fog_mask = smoothstep(horizon - 40, h, ys) * (0.25 + 0.75 * fbm(w, h, 6, seed + 8, 5))
	fog_col = blur(beams + spill, 30) * 0.8 + np.array([0.03, 0.02, 0.06])
	hdr = hdr * (1 - fog_mask[..., None] * 0.35) + fog_col * fog_mask[..., None] * 0.6
	return finish(hdr, seed, exposure=0.9, aberration=1.4, grain=0.02, vignette=0.5, bloom_strength=0.55)


def concept_tunnel(w=1920, h=1080, seed=202, mark=None):
	"""Raycast train tunnel: the final clue is the mark painted over the
	service-door sign, with warm light leaking under the door."""
	r = rng(seed)
	xs, ys = grid(w, h)
	f = w * 0.7
	cam = np.array([0.35, 1.65, 0.0])
	yaw = math.radians(-14)
	dx = (xs - w / 2) / f
	dy = -(ys - h / 2) / f
	dz = np.ones_like(dx)
	rx = dx * math.cos(yaw) + dz * math.sin(yaw)
	rz = -dx * math.sin(yaw) + dz * math.cos(yaw)
	ry = dy
	n = np.sqrt(rx * rx + ry * ry + rz * rz)
	rx, ry, rz = rx / n, ry / n, rz / n
	W, H0, R = 2.6, 2.6, 2.6
	inf = 1e9
	t_floor = np.where(ry < -1e-4, (0 - cam[1]) / np.minimum(ry, -1e-4), inf)
	t_left = np.where(rx < -1e-4, (-W - cam[0]) / np.minimum(rx, -1e-4), inf)
	t_right = np.where(rx > 1e-4, (W - cam[0]) / np.maximum(rx, 1e-4), inf)
	# Arched ceiling: cylinder along z centred (0, H0), radius R.
	ox, oy = cam[0], cam[1] - H0
	A = rx * rx + ry * ry
	B = 2 * (ox * rx + oy * ry)
	C = ox * ox + oy * oy - R * R
	disc_ = np.maximum(B * B - 4 * A * C, 0)
	t_arch = (-B + np.sqrt(disc_)) / np.maximum(2 * A, 1e-6)
	t_wall_l = np.where(cam[1] + ry * t_left <= H0, t_left, inf)
	t_wall_r = np.where(cam[1] + ry * t_right <= H0, t_right, inf)
	t_arch = np.where(cam[1] + ry * t_arch > H0, t_arch, inf)
	ts = np.stack([t_floor, t_wall_l, t_wall_r, t_arch], 0)
	kind = ts.argmin(0)
	t = ts.min(0)
	t = np.minimum(t, 400)
	px, py, pz = cam[0] + rx * t, cam[1] + ry * t, cam[2] + rz * t
	hdr = np.zeros((h, w, 3), np.float32)
	grime = fbm(w, h, 18, seed, 5)
	# Tile walls (left/right) and arch: glazed tiles, grout, water stains.
	u = np.where(kind == 3, np.arctan2(py - H0, px) * R, py)
	tile_u = (u * 4.2) % 1.0
	tile_v = (pz * 3.2) % 1.0
	grout = np.minimum(np.minimum(tile_u, 1 - tile_u), np.minimum(tile_v, 1 - tile_v))
	tile = smoothstep(0.02, 0.06, grout)
	stain = smoothstep(0.45, 0.9, fbm(w, h, 8, seed + 2, 4)) * (kind != 0)
	wall_col = np.array([0.30, 0.33, 0.31]) * (0.55 + 0.45 * tile)[..., None] * (1 - 0.6 * stain)[..., None]
	band = ((py > 1.05) & (py < 1.25) & (kind != 0) & (kind != 3))
	wall_col = np.where(band[..., None], np.array([0.40, 0.22, 0.06]), wall_col)
	# Floor: ballast, sleepers, two steel rails.
	ballast = 0.08 + 0.1 * value_noise(w, h, 300, seed + 4)
	floor_col = np.array([0.20, 0.19, 0.18]) * ballast[..., None] * 3
	sleeper = ((pz * 1.6) % 1.0 < 0.32) & (np.abs(px - 0.0) < 1.25)
	floor_col = np.where(sleeper[..., None], np.array([0.12, 0.09, 0.07]), floor_col)
	rail = (np.abs(np.abs(px) - 0.72) < 0.05)
	spec = np.exp(-((np.abs(px) - 0.72) / 0.02) ** 2)
	floor_col = np.where(rail[..., None], np.array([0.25, 0.26, 0.28]) + spec[..., None] * 0.9, floor_col)
	# Platform lip on the left.
	plat = (px < -1.6)
	floor_col = np.where(plat[..., None], np.array([0.22, 0.22, 0.24]) * (0.7 + 0.3 * grime[..., None]), floor_col)
	albedo = np.where((kind == 0)[..., None], floor_col, wall_col) * (0.6 + 0.5 * grime[..., None])
	# Hidden door on the left wall.
	dz0, dz1, dh = 7.0, 8.3, 2.2
	door = (kind == 1) & (pz > dz0) & (pz < dz1) & (py < dh)
	frame = (kind == 1) & (pz > dz0 - 0.08) & (pz < dz1 + 0.08) & (py < dh + 0.08) & ~door
	albedo = np.where(door[..., None], np.array([0.16, 0.17, 0.18]) * (0.6 + 0.6 * grime[..., None]), albedo)
	albedo = np.where(frame[..., None], np.array([0.06, 0.06, 0.07]), albedo)
	# Old amber service sign on the door, mark sprayed over it.
	sign = door & (py > 1.55) & (py < 1.9) & (pz > dz0 + 0.15) & (pz < dz1 - 0.15)
	albedo = np.where(sign[..., None], np.array([0.55, 0.36, 0.06]), albedo)
	emis = np.zeros_like(hdr)
	if mark is not None:
		mrgb, ma = mark
		mh, mw = ma.shape
		mu = (pz - (dz0 - 0.25)) / 1.8
		mv = 1 - (py - 0.75) / 1.8
		ok = (kind == 1) & (mu >= 0) & (mu < 1) & (mv >= 0) & (mv < 1)
		iu = np.clip((mu * mw).astype(int), 0, mw - 1)
		iv = np.clip((mv * mh).astype(int), 0, mh - 1)
		ma_s = np.where(ok, ma[iv, iu], 0)
		mc = mrgb[iv, iu]
		albedo = albedo * (1 - ma_s[..., None]) + np.power(mc, 2.2) * ma_s[..., None]
		emis += np.power(mc, 2.2) * ma_s[..., None] * 0.35
	# Lighting: suit lamp (spot along view), a distant amber service lamp,
	# and the warm leak under the door.
	dist = t
	to_cam = np.stack([-rx, -ry, -rz], -1)
	nrm = np.zeros_like(hdr)
	nrm[kind == 0] = [0, 1, 0]
	nrm[kind == 1] = [1, 0, 0]
	nrm[kind == 2] = [-1, 0, 0]
	ak = kind == 3
	nrm[ak, 0] = -px[ak] / R
	nrm[ak, 1] = -(py[ak] - H0) / R
	lam = np.clip((nrm * to_cam).sum(-1), 0, 1)
	lamp_axis = np.array([math.sin(yaw - 0.15), -0.18, math.cos(yaw - 0.15)])
	lamp_axis /= np.linalg.norm(lamp_axis)
	cone = smoothstep(0.80, 0.96, rx * lamp_axis[0] + ry * lamp_axis[1] + rz * lamp_axis[2])
	lamp = (0.25 + 2.6 * cone) * lam / (1 + 0.05 * dist * dist)
	light = lamp[..., None] * np.array([1.0, 0.97, 0.9])
	far = np.array([0.0, 2.2, 60.0])
	lx_, ly_, lz_ = far[0] - px, far[1] - py, far[2] - pz
	ld = np.sqrt(lx_ ** 2 + ly_ ** 2 + lz_ ** 2)
	far_l = np.clip((nrm[..., 0] * lx_ + nrm[..., 1] * ly_ + nrm[..., 2] * lz_) / ld, 0, 1) * 40 / (1 + ld * ld * 0.05)
	light += far_l[..., None] * AMBER
	leak_p = np.array([-W + 0.02, 0.02, (dz0 + dz1) / 2])
	qx, qy, qz = px - leak_p[0], py - leak_p[1], pz - leak_p[2]
	qd = np.sqrt(qx * qx + qy * qy * 6 + qz * qz * 0.6)
	leak = 1.6 / (1 + qd * qd * 7) * ((kind == 0) | (kind == 1))
	leak_col = np.array([1.0, 0.45, 0.85])
	light += leak[..., None] * leak_col
	hdr = albedo * light + emis
	slit = (kind == 1) & (pz > dz0) & (pz < dz1) & (py < 0.035)
	hdr[slit] = leak_col * 6
	# Distance fog and the amber glow at the vanishing point.
	fogf = 1 - np.exp(-dist * 0.045)
	fog_col = np.array([0.025, 0.028, 0.034]) + AMBER * 0.05 * np.exp(-np.abs(rx * 6))[..., None]
	hdr = hdr * (1 - fogf[..., None]) + fog_col * fogf[..., None]
	vx = w / 2 + math.tan(-yaw) * f
	vy = h / 2 - (2.2 - cam[1]) / 60 * f
	disc(hdr, vx, vy, 3, AMBER * 6, 2)
	# Dust motes in the suit lamp.
	for _ in range(700):
		qx_, qy_ = r.uniform(0, w), r.uniform(0, h)
		c_ = cone[int(qy_), int(qx_)]
		if c_ > 0.05:
			disc(hdr, qx_, qy_, r.uniform(0.5, 1.6), np.ones(3) * r.uniform(0.2, 0.9) * c_, 0.8)
	return finish(hdr, seed, exposure=1.35, aberration=0.9, grain=0.03, vignette=0.55, bloom_strength=0.7)


def concept_trail(marks, w=1920, h=640, seed=303):
	"""Sheet showing the five graffiti stages in clue order."""
	out = np.zeros((h, w, 3), np.float32)
	wall = fbm(w, h, 60, seed, 4)
	out += (np.array([0.11, 0.11, 0.12]) + wall[..., None] * 0.12)
	labels_col = np.array([0.8, 0.8, 0.85])
	slot = w // 5
	for i, (mrgb, ma) in enumerate(marks):
		size = int(min(slot, h) * 0.85)
		im = Image.fromarray((np.dstack([mrgb, ma]) * 255).astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
		arr = np.asarray(im, np.float32) / 255
		px, py = i * slot + (slot - size) // 2, (h - size) // 2
		reg = out[py:py + size, px:px + size]
		reg[:] = reg * (1 - arr[..., 3:4]) + arr[..., :3] * arr[..., 3:4]
		for path in glyph_paths(DIGITS[i + 1], i * slot + slot / 2 - 7 * 2, h - 50, 2):
			paint(out, None, path, 3, labels_col)
	return np.clip(out, 0, 1)


def concept_plan(w=1600, h=1000, seed=404):
	"""Top-down layout: tunnel, hidden door, stair, club, booth, telepad."""
	hdr = np.zeros((h, w, 3), np.float32)
	xs, ys = grid(w, h)
	hdr += ((np.abs((xs % 40) - 20) < 0.5) | (np.abs((ys % 40) - 20) < 0.5))[..., None] * CYAN * 0.06
	def rect(x0, y0, x1, y1, col, wd=2.5):
		neon(hdr, [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)], wd, col, 0.6)
	rect(40, 100, 1560, 230, np.array([0.5, 0.5, 0.55]))
	for x in range(60, 1560, 30):
		neon(hdr, [(x, 150), (x, 180)], 1, np.array([0.25, 0.25, 0.28]), 0)
	neon(hdr, [(40, 150), (1560, 150)], 1.5, np.array([0.4, 0.4, 0.45]), 0)
	neon(hdr, [(40, 180), (1560, 180)], 1.5, np.array([0.4, 0.4, 0.45]), 0)
	rect(560, 230, 680, 300, AMBER)
	neon(hdr, [(560, 230), (680, 230)], 4, MAGENTA, 1.2)
	rect(590, 300, 650, 420, np.array([0.6, 0.6, 0.65]))
	for y in range(310, 420, 14):
		neon(hdr, [(595, y), (645, y)], 1, np.array([0.4, 0.4, 0.45]), 0)
	rect(300, 420, 1300, 940, CYAN)
	rect(330, 450, 470, 560, UV)
	rect(1130, 450, 1270, 560, UV)
	rect(560, 860, 1040, 920, AMBER)
	rect(620, 800, 980, 850, AMBER * 0.7)
	cx, cy = 800, 640
	for k in range(6):
		a0 = k * math.pi / 3
		pts = [(cx + 150 * math.cos(a0 + j * math.pi / 3), cy + 150 * math.sin(a0 + j * math.pi / 3)) for j in range(7)]
	hexpts = [(cx + 170 * math.cos(math.pi / 6 + j * math.pi / 3), cy + 170 * math.sin(math.pi / 6 + j * math.pi / 3)) for j in range(7)]
	neon(hdr, hexpts, 3, MAGENTA, 1.0)
	disc(hdr, cx, cy, 14, np.array([2.4, 1.6, 2.6]))
	for a in np.linspace(0, 2 * math.pi, 10, endpoint=False):
		neon(hdr, [(cx, cy), (cx + math.cos(a) * 120, cy + math.sin(a) * 120)], 1, PALETTE[int(a * 2) % 6] * 0.5, 0.4)
	rect(1150, 760, 1270, 900, np.array([0.5, 0.5, 0.55]))
	neon(hdr, circle_pts(1210, 830, 40, 60), 3, UV, 1.3)
	neon(hdr, circle_pts(1210, 830, 24, 60), 2, CYAN, 1.0)
	rect(330, 760, 470, 900, np.array([0.5, 0.5, 0.55]))
	for i, (px, py) in enumerate([(200, 160), (1300, 160), (620, 265), (800, 640), (800, 890), (1210, 830), (400, 830)]):
		disc(hdr, px, py, 9, np.array([2, 2, 2]))
		for path in glyph_paths(DIGITS[i + 1], px + 16, py - 10, 1.0):
			neon(hdr, path, 1.4, np.array([1.6, 1.6, 1.6]), 0.2)
	return finish(hdr, seed, exposure=1.0, aberration=0.0, grain=0.01, vignette=0.15, bloom_strength=0.5)


# --------------------------------------------------------------------- main

def main(argv):
	textures_only = len(argv) > 1 and argv[1] == "textures"
	marks = []
	for stage in range(5):
		rgb, a = make_mark(stage, 1024, seed=500)
		save_rgba(rgb, a, os.path.join(TEX_DIR, "resistance_mark_%d.png" % stage))
		marks.append((rgb, a))
	atlas, panels = make_videowall_atlas()
	save_rgb(atlas, os.path.join(TEX_DIR, "videowall_atlas.png"))
	albedo, emission, mask = make_orb()
	save_rgb(albedo, os.path.join(TEX_DIR, "orb_albedo.png"))
	save_rgb(emission, os.path.join(TEX_DIR, "orb_emission.png"))
	save_rgb(mask, os.path.join(TEX_DIR, "orb_mask.png"))
	save_gray(make_gobo(), os.path.join(TEX_DIR, "gobo_spots.png"))
	frgb, fa = make_floor_masks()
	save_rgba(frgb, fa, os.path.join(TEX_DIR, "dancefloor_mask.png"))
	save_gray(make_fog(), os.path.join(TEX_DIR, "fog_noise.png"))
	for v in range(3):
		img, a = make_flyer(512, 768, 600 + v, v)
		save_rgba(img, a, os.path.join(TEX_DIR, "flyer_%d.png" % v))
	if textures_only:
		return
	save_rgb(concept_interior(panels=panels, mark=marks[0]), os.path.join(DOC_DIR, "club_interior_concept.png"))
	save_rgb(concept_tunnel(mark=marks[3]), os.path.join(DOC_DIR, "tunnel_entrance_concept.png"))
	save_rgb(concept_trail(marks), os.path.join(DOC_DIR, "graffiti_trail_stages.png"))
	save_rgb(concept_plan(), os.path.join(DOC_DIR, "club_layout_plan.png"))


if __name__ == "__main__":
	main(sys.argv)
