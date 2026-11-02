"""Synthesize the Ash Meridian intro audio: drone, servo jaw, robotic scream, tunnel dive, light swell.

Timed to render_video.py (16 s): mouth opens 4.8-6.4 s, dive 6.4-15.5 s, light 13.4-14.6 s,
menu fade 14.6-16 s. Usage: python3 scream.py out.wav
"""
import sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
DUR = 16.0
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)

def env(points):
    xs, ys = zip(*points); return np.interp(t, xs, ys)

def ss(a, b):
    x = np.clip((t - a) / (b - a), 0, 1); return x * x * (3 - 2 * x)

def bp(x, f, q):
    b, a = signal.iirpeak(min(f, SR / 2 - 100), q, SR); return signal.lfilter(b, a, x)

def lp(x, f):
    sos = signal.butter(2, f, "low", fs=SR, output="sos"); return signal.sosfilt(sos, x)

def hp(x, f):
    sos = signal.butter(2, f, "high", fs=SR, output="sos"); return signal.sosfilt(sos, x)

def osc(freq, shape="saw"):
    ph = np.cumsum(freq) / SR
    if shape == "saw": return 2 * (ph % 1) - 1
    if shape == "pulse": return np.where((ph % 1) < 0.28, 1.0, -1.0)
    return np.sin(2 * np.pi * ph)

def formant_sweep(src, f_tracks, gains):
    out = np.zeros(N); blk = 1024
    zi = [None] * len(f_tracks)
    for s in range(0, N, blk):
        e = min(N, s + blk)
        for k, ft in enumerate(f_tracks):
            b, a = signal.iirpeak(min(ft[s], SR / 2 - 200), 9, SR)
            if zi[k] is None: zi[k] = signal.lfilter_zi(b, a) * 0
            y, zi[k] = signal.lfilter(b, a, src[s:e], zi=zi[k])
            out[s:e] += y * gains[k]
    return out

L = np.zeros(N); R = np.zeros(N)

# 1. Machine drone (whole intro), mains hum + detuned low saws, slowly breathing.
hum = sum(np.sin(2 * np.pi * 50 * h * t) / h for h in (1, 2, 3, 5)) * 0.10
drone = lp(osc(np.full(N, 41.2)) + osc(np.full(N, 41.9)) + 0.5 * osc(np.full(N, 61.7)), 380) * 0.16
breath = 0.75 + 0.25 * np.sin(2 * np.pi * 0.23 * t)
d = (hum + drone) * breath * ss(0.0, 2.4) * (1 - 0.7 * ss(13.8, 16.0))
L += d; R += d

# 2. Data chirps while the face watches (2.4-4.8 s).
for c in np.arange(2.6, 4.7, 0.31) + rng.uniform(-0.05, 0.05, 7):
    i = int(c * SR); n = int(0.045 * SR)
    f = rng.uniform(1800, 4200)
    blip = np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.6, n)) / SR) * np.hanning(n) * 0.07
    pan = rng.uniform(0.2, 0.8)
    L[i:i + n] += blip * (1 - pan); R[i:i + n] += blip * pan

# 3. Jaw servo: grinding motor + latch clicks (4.6-6.4 s).
sv = np.clip((t - 4.6) / 1.8, 0, 1)
servo_f = 90 + 260 * sv + 25 * np.sin(2 * np.pi * 37 * t)
servo = np.sign(osc(servo_f, "sine")) * lp(rng.standard_normal(N), 900) * 0.5
servo = bp(servo, 700, 2) * env([(4.55, 0), (4.7, 0.35), (6.2, 0.3), (6.5, 0)])
L += servo; R += servo * 0.8
for c in (4.62, 4.8, 6.42):
    i = int(c * SR); n = int(0.03 * SR)
    k = rng.standard_normal(n) * np.exp(-np.linspace(0, 9, n)) * 0.5
    L[i:i + n] += k; R[i:i + n] += k

# 4. Robotic scream (5.0-14.2 s): formant-synth voice, pitch climbs with jitter,
#    tritone second voice, ring mod, stutter, bitcrush rising as we fall in.
sc = np.clip((t - 5.0) / 7.0, 0, 1)
jit = lp(rng.standard_normal(N), 9) * 40
f0 = (150 + 470 * sc ** 0.7 + jit + 30 * np.sin(2 * np.pi * 6.3 * t) * sc) * (1 - 0.55 * ss(11.5, 14.0))
src = osc(f0) * 0.6 + osc(f0 * 1.414, "pulse") * 0.35 + osc(f0 * 0.5) * 0.25
vow = ss(5.0, 9.0)  # "AAH" -> "EEE"
F1 = 800 + (300 - 800) * vow; F2 = 1150 + (2300 - 1150) * vow; F3 = 2900 + (3100 - 2900) * vow
voice = formant_sweep(src, (F1, F2, F3), (1.0, 0.7, 0.35))
voice *= 0.6 + 0.4 * np.sin(2 * np.pi * (35 + 40 * sc) * t)
crush = (1 + 5 * sc).astype(int)
idx = np.arange(N); voice = voice[idx - idx % np.maximum(crush, 1)]
bits = 2 ** (11 - 4 * sc)
voice = np.round(voice * bits) / bits
v = voice.copy()
for c in np.sort(rng.uniform(5.6, 13.0, 18)):
    i = int(c * SR); n = int(rng.uniform(0.02, 0.06) * SR); reps = rng.integers(2, 5)
    for r in range(1, reps + 1):
        j = i + r * n
        if j + n < N: v[j:j + n] = voice[i:i + n]
voice = np.tanh(v * 1.8) * 0.5
vol = env([(5.0, 0), (5.25, 1.0), (9.5, 1.0), (13.4, 0.8), (14.3, 0)])
inside = ss(7.0, 9.0)
muffled = lp(voice, 1800)
voice = voice * (1 - 0.35 * inside) + muffled * 0.35 * inside
wob = 0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * t) * inside
L += voice * vol * (0.6 + 0.4 * wob); R += voice * vol * (1.0 - 0.4 * wob)

# 5. Dive: rising filtered wind + ring-pass whooshes timed to the video's pulse rings.
air = rng.standard_normal(N)
dive = ss(6.4, 15.5)
wind = np.zeros(N); blk = 1024; zi = None
for s in range(0, N, blk):
    b, a = signal.iirpeak(200 + 2600 * dive[s], 1.4, SR)
    if zi is None: zi = signal.lfilter_zi(b, a) * 0
    wind[s:s + blk], zi = signal.lfilter(b, a, air[s:s + blk], zi=zi)
wind = lp(wind, 6000) * env([(6.3, 0), (7.5, 0.05), (13.0, 0.1), (14.6, 0.02), (16, 0)])
L += wind; R += np.roll(wind, 900)
cam = dive * 26.0 * 0.6
passes = np.where(np.diff(np.floor((cam - 2.5) / 5.0)) > 0)[0]
for i in passes:
    n = int(0.6 * SR); seg = air[i:i + n] if i + n < N else air[-n:]
    w = bp(seg, 900, 1.5) * np.hanning(n) * 0.35
    j = min(i, N - n)
    L[j:j + n] += w * np.linspace(1, 0.3, n); R[j:j + n] += w * np.linspace(0.3, 1, n)

# 6. Light swell (13.4-14.6 s): shimmer cluster, then sub impact and blue cool-down tail.
sw = env([(13.2, 0), (14.4, 1), (16.0, 0)])
shim = sum(np.sin(2 * np.pi * f * t + p) for f, p in ((880, 0), (1318.5, 1), (1975.5, 2), (2637, 3)))
shim *= (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t)) * 0.05 * sw
L += shim; R += np.roll(shim, 300)
i = int(14.45 * SR); n = int(1.5 * SR)
boom = np.sin(2 * np.pi * np.cumsum(np.linspace(70, 28, n)) / SR) * np.exp(-np.linspace(0, 5, n)) * 0.55
L[i:i + n] += boom; R[i:i + n] += boom
pad = (osc(np.full(N, 110), "sine") + osc(np.full(N, 164.8), "sine") + osc(np.full(N, 233.1), "sine")) * 0.04
pad *= env([(14.3, 0), (14.9, 1), (16, 0)])
L += pad; R += pad

# Metallic room reverb, master, fades.
ir_n = int(1.8 * SR)
ir = rng.standard_normal((2, ir_n)) * np.exp(-np.linspace(0, 7, ir_n))
ir = np.array([hp(x, 300) for x in ir]) * 0.06
L = L + signal.fftconvolve(L, ir[0])[:N]
R = R + signal.fftconvolve(R, ir[1])[:N]
mix = np.stack([L, R], 1)
mix = hp(mix.T, 25).T
mix *= np.minimum(1, np.minimum(t / 0.05, (DUR - t) / 0.4))[:, None]
mix = np.tanh(mix * 1.1)
mix /= np.max(np.abs(mix)) / 0.89
wavfile.write(sys.argv[1], SR, (mix * 32767).astype(np.int16))
print("peak ok", mix.shape)
