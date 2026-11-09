#!/usr/bin/env python3
"""Generates Auction XI's original music and sound effects (no samples, no licences needed).

    python3 tools/audio/make_audio.py        # writes ios/Resources/Audio/*.m4a (needs numpy, ffmpeg)

Everything is synthesised here, deterministically (fixed seeds), so the repo owns every sound:
  theme.m4a   hub music: 40 s seamless loop, 96 bpm, D major. Drone, pads, plucked pentatonic
              melody, bass, soft kick, tabla-like taps and a shaker.
  crowd.m4a   match-day stadium ambience: 30 s seamless loop.
  bat.m4a     bat on ball.      four.m4a  crowd cheer.     six.m4a  dhol + roar.
  wicket.m4a  stumps + roar.    win.m4a   victory sting.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "ios", "Resources", "Audio")
rng = np.random.default_rng(2027)


# ---------------------------------------------------------------- building blocks

def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    """Envelope of n samples with attack, decay, sustain level and release (seconds)."""
    env = np.full(n, s)
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    a_n = max(1, min(a_n, n))
    env[:a_n] = np.linspace(0, 1, a_n)
    d_end = min(n, a_n + d_n)
    if d_end > a_n:
        env[a_n:d_end] = np.linspace(1, s, d_end - a_n)
    if r_n > 0 and n > r_n:
        env[-r_n:] *= np.linspace(1, 0, r_n)
    return env


def spectral_filter(x, lo=None, hi=None, tilt=0.0):
    """Zero-phase band filter in the frequency domain with soft edges; tilt in dB/octave."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        g *= 1 / (1 + (f / hi) ** 4)
    if tilt:
        g *= (np.maximum(f, 20) / 1000) ** (tilt / 6.02)
    return np.fft.irfft(X * g, n)


def additive(freq, seconds, harmonics=10, bright=0.35, detune=0.0):
    """Band-limited saw-like tone; bright controls how fast upper harmonics fall."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for h in range(1, harmonics + 1):
        if freq * h > SR / 2.2:
            break
        amp = (1 / h) * np.exp(-(h - 1) * (1 - bright))
        out += amp * np.sin(2 * np.pi * freq * h * (1 + detune) * t + rng.uniform(0, 2 * np.pi))
    return out


def pluck(freq, seconds, damping=0.996, bright=0.6):
    """Karplus-Strong plucked string (harp/sitar-like)."""
    n = int(seconds * SR)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period) * bright + rng.uniform(-1, 1, period) * (1 - bright) * 0.3
    out = np.empty(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = damping * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out * adsr(n, a=0.002, d=0.05, s=1.0, r=min(0.3, seconds / 3))


def kick(seconds=0.35):
    t = t_axis(seconds)
    f = 50 + 70 * np.exp(-t * 30)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t * 9)


def tabla(freq=620, seconds=0.25, bend=1.15):
    """Resonant tabla-like 'na': a pitched ping that bends up slightly, plus a tiny slap."""
    t = t_axis(seconds)
    f = freq * (1 + (bend - 1) * (1 - np.exp(-t * 25)))
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) * np.exp(-t * 18) + 0.35 * np.sin(2.01 * phase) * np.exp(-t * 30)
    slap = spectral_filter(rng.normal(0, 1, len(t)), lo=2000) * np.exp(-t * 120) * 0.25
    return tone + slap


def dhol(seconds=0.6, low=True):
    t = t_axis(seconds)
    if low:
        f = 70 + 40 * np.exp(-t * 20)
        phase = 2 * np.pi * np.cumsum(f) / SR
        return np.sin(phase) * np.exp(-t * 6) + 0.3 * np.sin(1.5 * phase) * np.exp(-t * 10)
    slap = spectral_filter(rng.normal(0, 1, len(t)), lo=900, hi=6000) * np.exp(-t * 40)
    ring = np.sin(2 * np.pi * 380 * t) * np.exp(-t * 25) * 0.6
    return slap + ring


def shaker(seconds=0.06):
    t = t_axis(seconds)
    return spectral_filter(rng.normal(0, 1, len(t)), lo=5000, hi=12000) * np.exp(-t * 60)


def reverb_ir(seconds=1.8, decay=3.2, seed=1):
    r = np.random.default_rng(seed)
    t = t_axis(seconds)
    ir = r.normal(0, 1, len(t)) * np.exp(-t * decay)
    ir = spectral_filter(ir, lo=200, hi=7000)
    ir[0] = 1.0
    return ir / np.sqrt(np.sum(ir ** 2))


def convolve(x, ir):
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def place(track, sound, at, gain=1.0):
    """Adds sound into track starting at `at` seconds (clipped at the end)."""
    i = int(at * SR)
    if i >= len(track):
        return
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i] * gain


def wrap_tail(x, length):
    """Folds everything past `length` back onto the start: a seamless loop with reverb tails."""
    out = x[:length].copy()
    tail = x[length:]
    out[: len(tail)] += tail[: length]
    return out


def crossfade_loop(x, fade):
    """Seamless loop by blending the last `fade` seconds into the start (equal power)."""
    n = int(fade * SR)
    body = x[:-n].copy()
    end = x[-n:]
    w = np.linspace(0, np.pi / 2, n)
    body[:n] = body[:n] * np.sin(w) + end * np.cos(w)
    return body


def master(x, target_rms=0.12, peak=0.89):
    # Remove rumble below 30 Hz (phones can't play it; it only eats headroom).
    x = np.vstack([spectral_filter(c, lo=30) for c in x]) if x.ndim > 1 else spectral_filter(x, lo=30)
    rms = np.sqrt(np.mean(x ** 2))
    x = x * (target_rms / max(rms, 1e-9))
    x = np.tanh(x * 1.1) / np.tanh(1.1)          # gentle saturation, no hard clipping
    m = np.max(np.abs(x))
    if m > peak:
        x *= peak / m
    return x


def write(name, x, channels, bitrate):
    os.makedirs(OUT, exist_ok=True)
    data = x.T if channels == 2 else x
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dest = os.path.join(OUT, name)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "aac", "-b:a", bitrate, dest], check=True)
    os.remove(path)
    seconds = len(x[0] if channels == 2 else x) / SR
    print(f"{name:12s} {seconds:5.1f}s  rms {np.sqrt(np.mean(x ** 2)):.3f}  peak {np.max(np.abs(x)):.2f}  "
          f"{os.path.getsize(dest) // 1024} KB")


# ---------------------------------------------------------------- the theme

def theme():
    bpm = 96
    beat = 60 / bpm
    bar = 4 * beat
    bars = 16
    length = int(bars * bar * SR)
    total = length + int(3 * SR)
    L = np.zeros(total)
    R = np.zeros(total)

    D, E, Fs, G, A, B = 62, 64, 66, 67, 69, 71
    # D | Bm | G | A | D | Bm | Em | A  (twice)
    chords = [[D, Fs, A], [B - 12, D, Fs], [G - 12, B - 12, D], [A - 12, 61, E],
              [D, Fs, A], [B - 12, D, Fs], [E - 12, G - 12, B - 12], [A - 12, 61, E]] * 2
    roots = [D - 24, B - 36, G - 36, A - 36, D - 24, B - 36, E - 24, A - 36] * 2

    # Drone (tanpura-like): D and A, slowly breathing.
    t = np.arange(total) / SR
    drone = (0.5 * additive(midi(38), total / SR, 8, 0.5) + 0.35 * additive(midi(45), total / SR, 8, 0.5))
    drone *= 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * t / (2 * bar)))
    L += drone * 0.10
    R += drone * 0.10

    for i, ch in enumerate(chords):
        start = i * bar
        # Pad: detuned soft saws, slow attack.
        pad = sum(additive(midi(n), bar + 0.6, 9, 0.3, d) for n in ch for d in (-0.003, 0.003))
        pad *= adsr(len(pad), a=0.45, d=0.4, s=0.8, r=0.6)
        place(L, pad, start, 0.05)
        place(R, pad, start, 0.05)
        # Bass on 1, the "and" of 2, and 3.
        for k, at in enumerate((0, 1.5, 2)):
            bass = pluck(midi(roots[i] + (12 if k == 1 else 0)), beat * 1.2, 0.993, 0.4)
            place(L, bass, start + at * beat, 0.32)
            place(R, bass, start + at * beat, 0.32)
        # Kick on 1 and 3; tabla taps on the off-beats; shaker in eighths.
        for at in (0, 2):
            place(L, kick(), start + at * beat, 0.34)
            place(R, kick(), start + at * beat, 0.34)
        for at, f in ((0.5, 640), (1.5, 700), (2.75, 640), (3.5, 760)):
            g = 0.16 if i % 2 == 0 or at != 2.75 else 0.0
            place(L, tabla(f), start + at * beat, g * 0.8)
            place(R, tabla(f), start + at * beat, g)
        for e in range(8):
            place(L, shaker(), start + e * beat / 2, 0.05 if e % 2 else 0.03)
            place(R, shaker(), start + e * beat / 2 + 0.012, 0.05 if e % 2 else 0.03)

    # Melody: a D-major pentatonic motif, answered and varied; rests leave space for the crowd.
    scale = [D + 12, E + 12, Fs + 12, A + 12, B + 12, D + 24]
    motif = [(0, 2, 1), (1, 3, 1), (2, 4, 2), (4, 2, 1), (5, 1, 1), (6, 0, 2)]   # (eighth, degree, eighths)
    answer = [(0, 4, 1), (1, 3, 1), (2, 2, 1), (3, 1, 1), (4, 2, 3)]
    for phrase in range(bars // 2):
        start = phrase * 2 * bar
        notes = motif if phrase % 2 == 0 else answer
        lift = 1 if phrase in (2, 6) else 0
        for eighth, deg, dur in notes:
            n = scale[min(len(scale) - 1, deg + lift)]
            p = pluck(midi(n), dur * beat / 2 + 0.6, 0.9965, 0.7)
            pan = 0.35 + 0.3 * (deg / 5)
            place(L, p, start + bar + eighth * beat / 2, 0.20 * (1 - pan) * 2)
            place(R, p, start + bar + eighth * beat / 2, 0.20 * pan * 2)

    # Room: a short stereo reverb, then fold the tail back for a seamless loop.
    L = L + 0.28 * convolve(L, reverb_ir(seed=1))[:total]
    R = R + 0.28 * convolve(R, reverb_ir(seed=2))[:total]
    L = wrap_tail(L, length)
    R = wrap_tail(R, length)
    st = master(np.vstack([L, R]), target_rms=0.11)
    write("theme.m4a", st, 2, "128k")


# ---------------------------------------------------------------- crowd and effects

def crowd_bed(seconds, seed, brightness=0.0):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    murmur = spectral_filter(r.normal(0, 1, n), lo=180, hi=2600 + brightness, tilt=-3)
    # Syllable-rate texture: many voices give a 3-7 Hz flutter.
    flutter = spectral_filter(r.normal(0, 1, n), lo=3, hi=7)
    flutter = 0.75 + 0.25 * flutter / (np.max(np.abs(flutter)) + 1e-9)
    voices = spectral_filter(r.normal(0, 1, n), lo=500, hi=1800) * flutter
    return murmur + 0.6 * voices


def claps(seconds, seed, rate=6.0, gain=0.25):
    r = np.random.default_rng(seed)
    out = np.zeros(int(seconds * SR))
    for at in np.sort(r.uniform(0, seconds, int(seconds * rate))):
        c = spectral_filter(r.normal(0, 1, int(0.03 * SR)), lo=900, hi=5000) * np.exp(-np.arange(int(0.03 * SR)) / SR * 140)
        place(out, c, at, gain * r.uniform(0.4, 1.0))
    return out


def crowd():
    seconds = 32
    L = crowd_bed(seconds, 11)
    R = crowd_bed(seconds, 12)
    t = np.arange(len(L)) / SR
    swell = 0.8 + 0.2 * np.sin(2 * np.pi * t / 9.0) + 0.1 * np.sin(2 * np.pi * t / 4.3 + 1)
    L *= swell
    R *= swell[::-1]
    # A distant clapping chant now and then: clap-clap, clap-clap-clap.
    for start in (6.0, 19.5):
        for rep in range(3):
            for at in (0, 0.33, 0.9, 1.15, 1.4):
                c = claps(0.05, int(start * 10 + rep * 7 + at * 100), rate=40, gain=0.6)
                place(L, c, start + rep * 2.0 + at, 0.5)
                place(R, c, start + rep * 2.0 + at + 0.01, 0.5)
    L = crossfade_loop(L, 2.0)
    R = crossfade_loop(R, 2.0)
    write("crowd.m4a", master(np.vstack([L, R]), target_rms=0.10), 2, "112k")


def bat():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    click = spectral_filter(rng.normal(0, 1, n), lo=3000) * np.exp(-t * 400)
    wood = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((1150, 45), (1780, 60), (2650, 80)))
    thock = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 35)
    x = 0.6 * click + 0.5 * wood + 0.6 * thock
    x = x + 0.15 * convolve(x, reverb_ir(0.6, 9, seed=5))[:n]
    write("bat.m4a", master(x, target_rms=0.10, peak=0.95), 1, "96k")


def cheer(seconds, seed, peak_at=0.25, bright=1500):
    bed = crowd_bed(seconds, seed, brightness=bright)
    t = np.arange(len(bed)) / SR
    env = np.minimum(1, t / peak_at) * np.exp(-np.maximum(0, t - peak_at) * (2.2 / seconds * 2))
    return bed * env + claps(seconds, seed + 1, rate=14, gain=0.35) * env


def four():
    x = cheer(2.4, 21)
    write("four.m4a", master(x, target_rms=0.12), 1, "96k")


def six():
    x = cheer(3.4, 31, peak_at=0.35, bright=2500)
    for at, low in ((0.0, True), (0.18, False), (0.36, False), (0.54, True), (0.9, True), (1.08, False), (1.26, True)):
        place(x, dhol(0.6, low), at, 0.9 if low else 0.6)
    write("six.m4a", master(x, target_rms=0.13), 1, "96k")


def wicket():
    n = int(2.8 * SR)
    x = np.zeros(n)
    for at in (0.0, 0.035, 0.07, 0.12):
        tt = t_axis(0.18)
        f = rng.uniform(650, 1500)
        knock = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 40) + spectral_filter(rng.normal(0, 1, len(tt)), lo=2000) * np.exp(-tt * 150) * 0.4
        place(x, knock, at, 0.8)
    place(x, cheer(2.5, 41, peak_at=0.3, bright=2000), 0.15, 1.0)
    write("wicket.m4a", master(x, target_rms=0.12), 1, "96k")


def win():
    seconds = 3.6
    n = int(seconds * SR)
    x = np.zeros(n)
    chord = [62, 66, 69, 74]
    pad = sum(additive(midi(m), seconds, 9, 0.35, d) for m in chord for d in (-0.003, 0.003))
    pad *= adsr(n, a=0.3, d=0.5, s=0.7, r=1.2)
    x += 0.06 * pad
    for i, m in enumerate([62, 66, 69, 74, 78, 81]):
        place(x, pluck(midi(m), 1.6, 0.9965, 0.8), 0.05 + i * 0.11, 0.35)
    place(x, kick(), 0.05, 0.5)
    x = x + 0.3 * convolve(x, reverb_ir(seed=7))[:n]
    write("win.m4a", master(x, target_rms=0.11), 1, "112k")


if __name__ == "__main__":
    theme()
    crowd()
    bat()
    four()
    six()
    wicket()
    win()
