#!/usr/bin/env python3
"""Synthesizes Llama Village's music loops and sound effects.

Everything is generated from code (additive synthesis, shaped noise and an
FFT reverb); nothing is sampled or downloaded. Needs numpy and ffmpeg (with
libopus). From the repo root:

    python3 tool/audio/gen_audio.py                 # writes assets/audio/*.ogg
    python3 tool/audio/gen_audio.py --preview x.m4a # also a 20 s listening mix

The output is deterministic for a given numpy version.
"""

import argparse
import os
import shutil
import subprocess
import sys

import numpy as np

SR = 48000
# libopus prepends this many samples of encoder delay. A loop of k * 960 - 312
# samples decodes to exactly k whole 20 ms frames, so a decoder that trims
# only the pre-skip still gets a sample-exact loop.
OPUS_FRAME = 960
OPUS_PRESKIP = 312

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))


def loop_len(seconds):
    return int(round(seconds * SR / OPUS_FRAME)) * OPUS_FRAME - OPUS_PRESKIP


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def note(name):
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    n = names[name[0]]
    rest = name[1:]
    if rest.startswith('#'):
        n += 1
        rest = rest[1:]
    elif rest.startswith('b'):
        n -= 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + n


def t(seconds):
    return np.arange(int(seconds * SR)) / SR


def add(buf, at, sig, wrap=True):
    """Adds sig into buf at sample `at`, wrapping past the end for loops."""
    n = len(buf)
    at = int(at)
    if not wrap:
        end = min(n, at + len(sig))
        if end > at:
            buf[at:end] += sig[: end - at]
        return
    pos = 0
    while pos < len(sig):
        start = (at + pos) % n
        take = min(len(sig) - pos, n - start)
        buf[start:start + take] += sig[pos:pos + take]
        pos += take


def fft_filter(x, lo=None, hi=None, slope=None):
    """Circular band shaping in the frequency domain (seamless for loops)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = np.ones_like(f)
    if lo is not None:
        gain *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi is not None:
        gain *= 1 / (1 + (f / hi) ** 4)
    if slope is not None:
        gain *= (np.maximum(f, 20) / 1000.0) ** slope
    return np.fft.irfft(spec * gain, len(x))


def reverb_ir(seconds, rng, decay=2.2, lo=200, hi=6000):
    n = int(seconds * SR)
    env = np.exp(-np.arange(n) / SR * decay * 3)
    ir = rng.standard_normal(n) * env
    ir = fft_filter(ir, lo=lo, hi=hi)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    return ir / np.sqrt(np.sum(ir ** 2))


def conv_circular(x, ir):
    n = len(x)
    h = np.zeros(n)
    h[: len(ir)] = ir[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), n)


def conv_linear(x, ir):
    n = len(x) + len(ir)
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)


# ------------------------------------------------------------ instruments


def marimba(freq, dur=1.2, vel=1.0):
    x = t(dur)
    # Bar partials of a tuned marimba bar (1 : 3.93 : 9.2) with faster upper decay.
    s = (np.sin(2 * np.pi * freq * x) * np.exp(-x * 4.5)
         + 0.22 * np.sin(2 * np.pi * freq * 3.93 * x) * np.exp(-x * 14)
         + 0.06 * np.sin(2 * np.pi * freq * 9.2 * x) * np.exp(-x * 30))
    s *= np.minimum(1, x / 0.003)
    return s * vel


def bell(freq, dur=2.5, vel=1.0):
    x = t(dur)
    s = (np.sin(2 * np.pi * freq * x) * np.exp(-x * 1.6)
         + 0.35 * np.sin(2 * np.pi * freq * 2.76 * x) * np.exp(-x * 3.5)
         + 0.12 * np.sin(2 * np.pi * freq * 5.4 * x) * np.exp(-x * 7))
    s *= np.minimum(1, x / 0.004)
    return s * vel


def pad(freqs, dur, attack=0.9, release=1.2, bright=1.0, phase_rng=None):
    """Soft additive pad, stereo, with slow detune drift."""
    total = dur + release
    x = t(total)
    env = np.minimum(1, x / attack) * np.clip((total - x) / release, 0, 1)
    env = env ** 1.5
    out = np.zeros((2, len(x)))
    for i, f in enumerate(freqs):
        for ch, det in enumerate((-0.0025, 0.0025)):
            ph = 0 if phase_rng is None else phase_rng.uniform(0, 2 * np.pi)
            s = np.zeros(len(x))
            for h in range(1, 6):
                amp = (1 / h ** 1.8) * (bright if h > 1 else 1)
                s += amp * np.sin(2 * np.pi * f * (1 + det * (1 + 0.3 * i)) * h * x + ph * h)
            out[ch] += s
    trem = 1 + 0.08 * np.sin(2 * np.pi * 0.23 * x)
    return out * env * trem / max(1, len(freqs))


def soft_bass(freq, dur, vel=1.0):
    x = t(dur)
    s = np.sin(2 * np.pi * freq * x) + 0.18 * np.sin(4 * np.pi * freq * x)
    env = np.minimum(1, x / 0.012) * np.exp(-x * 1.4) * np.clip((dur - x) / 0.08, 0, 1)
    return s * env * vel


def thump(vel=1.0):
    x = t(0.25)
    f = 48 + 40 * np.exp(-x * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-x * 18) * np.minimum(1, x / 0.002) * vel


def shaker(rng, vel=1.0):
    x = t(0.07)
    n = fft_filter(rng.standard_normal(len(x)), lo=5000, hi=11000)
    return n * np.exp(-x * 70) * np.minimum(1, x / 0.004) * vel / (np.max(np.abs(n)) + 1e-9)


def stereo(sig, pan=0.0):
    left = np.cos((pan + 1) * np.pi / 4)
    right = np.sin((pan + 1) * np.pi / 4)
    return np.vstack([sig * left, sig * right])


def add2(buf, at, sig2):
    add(buf[0], at, sig2[0])
    add(buf[1], at, sig2[1])


# ------------------------------------------------------------ music

PENTA = [0, 2, 4, 7, 9]  # C major pentatonic


def chord_notes(name):
    """Chord name to (root midi, list of pitch classes)."""
    table = {
        'Cmaj7': (note('C3'), [0, 4, 7, 11]),
        'Cadd9': (note('C3'), [0, 4, 7, 2]),
        'Dm7': (note('D3'), [2, 5, 9, 0]),
        'Em7': (note('E3'), [4, 7, 11, 2]),
        'Fmaj7': (note('F2'), [5, 9, 0, 4]),
        'G6': (note('G2'), [7, 11, 2, 4]),
        'G7sus': (note('G2'), [7, 0, 2, 5]),
        'Am7': (note('A2'), [9, 0, 4, 7]),
        'Am9': (note('A2'), [9, 0, 4, 11]),
    }
    return table[name]


def voicing(pcs, low=note('F3')):
    out = []
    for pc in pcs:
        n = low + ((pc - low) % 12)
        out.append(n)
    return sorted(out)


def melody_bar(rng, pcs, prev, density):
    """Eight eighth-note slots; returns [(slot, midi, length_slots)] and last note."""
    pattern_bank = [
        [0, 2, 3, 4, 6],
        [0, 3, 4, 6],
        [0, 1, 2, 4, 6, 7],
        [0, 2, 4, 5, 6],
        [0, 4, 6],
        [1, 2, 4, 6],
        [0, 2, 4],
    ]
    pattern = pattern_bank[rng.integers(len(pattern_bank))]
    if density < 0.5:
        pattern = [s for s in pattern if s % 2 == 0][:3]
    pool = [n for n in range(note('C5'), note('A6') + 1) if n % 12 in PENTA]
    events = []
    cur = prev
    for i, slot in enumerate(pattern):
        strong = slot in (0, 4)
        candidates = [n for n in pool if abs(n - cur) <= 5 and n != cur] or pool
        if strong:
            chordy = [n for n in candidates if n % 12 in pcs]
            if chordy:
                candidates = chordy
        weights = np.array([1.0 / (1 + abs(n - cur)) for n in candidates])
        # Gentle pull back toward the middle of the range.
        weights *= np.array([1.0 / (1 + abs(n - note('A5')) / 6) for n in candidates])
        cur = candidates[rng.choice(len(candidates), p=weights / weights.sum())]
        nxt = pattern[i + 1] if i + 1 < len(pattern) else 8
        events.append((slot, cur, nxt - slot))
    return events, cur


def day_loop(rng):
    bars = 32
    n = loop_len(72)
    bar = n / bars
    eighth = bar / 8
    prog_a = ['Fmaj7', 'Em7', 'Dm7', 'Cmaj7', 'Fmaj7', 'Em7', 'Dm7', 'G7sus']
    prog_b = ['Am7', 'Fmaj7', 'Cadd9', 'G6', 'Am7', 'Fmaj7', 'Dm7', 'G7sus']
    prog = prog_a + prog_a + prog_b + prog_a
    pad_buf = np.zeros((2, n))
    mel_buf = np.zeros((2, n))
    low_buf = np.zeros((2, n))
    perc_buf = np.zeros((2, n))
    prng = np.random.default_rng(7)

    # Two-bar motifs reused across sections so the tune has a shape.
    motifs = {}
    last = note('E5')
    for b, ch in enumerate(prog):
        root, pcs = chord_notes(ch)
        at = b * bar
        add2(pad_buf, at, pad([midi(m) for m in voicing(pcs)], bar / SR + 0.05, bright=0.7, phase_rng=prng))
        add2(low_buf, at, stereo(soft_bass(midi(root), bar / SR * 0.55, 0.55)))
        add2(low_buf, at + 5 * eighth, stereo(soft_bass(midi(root + 7 if root + 7 < note('C3') else root - 5), bar / SR * 0.3, 0.32)))

        section = b // 8
        key = (section if section != 3 else 0, b % 8)
        if key in motifs and section in (1, 3) and b % 8 not in (6, 7):
            events = motifs[key]
            if section == 3:
                events = [(s, m + (2 if m % 12 == 0 and rng.random() < 0.3 else 0), ln) for s, m, ln in events]
        else:
            density = 0.4 if section == 0 and b < 2 else (0.9 if section == 2 else 0.7)
            events, last = melody_bar(rng, pcs, last, density)
            motifs.setdefault(key, events)
        if b == bars - 1:
            events = [(0, note('G5'), 2), (2, note('E5'), 2), (4, note('D5'), 4)]
        for slot, m, ln in events:
            vel = 0.55 + 0.25 * (slot in (0, 4)) + 0.1 * rng.random()
            add2(mel_buf, at + slot * eighth, stereo(marimba(midi(m), dur=min(1.6, 0.35 + ln * eighth / SR * 1.2), vel=vel), pan=-0.15))
        # A quiet sparkle an octave up now and then.
        if b % 4 == 3:
            m = voicing(pcs, low=note('C6'))[rng.integers(3)]
            add2(mel_buf, at + 6 * eighth, stereo(bell(midi(m), 1.8, 0.16), pan=0.5))

        # Light pulse: soft thump on 1 and 3, shaker on the off-beats.
        if section > 0 or b >= 4:
            for beat in (0, 4):
                add2(perc_buf, at + beat * eighth, stereo(thump(0.5 if beat == 0 else 0.35)))
            for s in range(8):
                v = 0.10 if s % 2 else 0.05
                add2(perc_buf, at + s * eighth + rng.normal(0, 40), stereo(shaker(rng, v), pan=0.3))

    ir = reverb_ir(2.4, np.random.default_rng(3))
    wet_src = mel_buf * 0.9 + pad_buf * 0.5
    wet = np.vstack([conv_circular(wet_src[0], ir), conv_circular(wet_src[1], np.roll(ir, 37))])
    mix = pad_buf * 0.55 + mel_buf * 0.85 + low_buf * 0.6 + perc_buf * 0.5 + wet * 0.22
    mix = np.vstack([fft_filter(mix[0], hi=9000), fft_filter(mix[1], hi=9000)])
    return normalize(mix, -14)


def night_loop(rng):
    bars = 20
    n = loop_len(78)
    bar = n / bars
    prog = ['Am9', 'Fmaj7', 'Cmaj7', 'G6', 'Am9', 'Fmaj7', 'Dm7', 'Em7', 'Fmaj7', 'Cmaj7'] * 2
    pad_buf = np.zeros((2, n))
    mel_buf = np.zeros((2, n))
    low_buf = np.zeros((2, n))
    prng = np.random.default_rng(11)
    pool = [m for m in range(note('E5'), note('E6') + 1) if m % 12 in PENTA]
    for b, ch in enumerate(prog):
        root, pcs = chord_notes(ch)
        at = b * bar
        add2(pad_buf, at, pad([midi(m - 12) for m in voicing(pcs)], bar / SR + 0.4, attack=1.8, release=2.2, bright=0.45, phase_rng=prng))
        add2(low_buf, at, stereo(soft_bass(midi(root - 12 if root >= note('C3') else root), bar / SR * 0.9, 0.4)))
        # Sparse bell notes, a few per bar, chord tones first.
        count = rng.integers(1, 4)
        slots = sorted(rng.choice(8, size=count, replace=False))
        for slot in slots:
            choices = [m for m in pool if m % 12 in pcs] or pool
            m = choices[rng.integers(len(choices))]
            add2(mel_buf, at + slot * bar / 8, stereo(bell(midi(m), 3.0, 0.28 + 0.1 * rng.random()), pan=rng.uniform(-0.5, 0.5)))
    ir = reverb_ir(3.5, np.random.default_rng(5), decay=1.4, hi=4500)
    wet_src = mel_buf + pad_buf * 0.4
    wet = np.vstack([conv_circular(wet_src[0], ir), conv_circular(wet_src[1], np.roll(ir, 53))])
    mix = pad_buf * 0.6 + mel_buf * 0.55 + low_buf * 0.45 + wet * 0.35
    mix = np.vstack([fft_filter(mix[0], hi=5000), fft_filter(mix[1], hi=5000)])
    return normalize(mix, -19)


def rain_loop(rng):
    n = loop_len(32)
    out = np.zeros((2, n))
    for ch in range(2):
        hiss = fft_filter(rng.standard_normal(n), lo=900, hi=9000, slope=-0.4)
        body = fft_filter(rng.standard_normal(n), lo=120, hi=1200, slope=-0.8)
        # Slow swells, periodic over the loop.
        k = np.arange(n) / n
        swell = 1 + 0.18 * np.sin(2 * np.pi * 3 * k + ch) + 0.1 * np.sin(2 * np.pi * 7 * k + 2 * ch)
        out[ch] = (hiss / np.std(hiss) * 0.6 + body / np.std(body) * 0.45) * swell
    drop_t = t(0.025)
    for _ in range(900):
        f = rng.uniform(1800, 5200)
        d = np.sin(2 * np.pi * f * drop_t * (1 - drop_t * 8)) * np.exp(-drop_t * 260) * rng.uniform(0.3, 1.2)
        pan = rng.uniform(-0.9, 0.9)
        add2(out, rng.integers(n), stereo(d, pan))
    return normalize(out, -20)


# ------------------------------------------------------------ effects


def flap(rng):
    out = np.zeros(int(0.42 * SR))
    for i, at in enumerate((0.0, 0.11, 0.22)):
        x = t(0.09)
        burst = fft_filter(rng.standard_normal(len(x)), lo=250, hi=2400)
        burst /= np.max(np.abs(burst))
        env = np.sin(np.pi * np.minimum(1, x / 0.09)) ** 2
        add(out, at * SR, burst * env * (1 - 0.22 * i), wrap=False)
    return fade_out(out)


def tweet(f0, f1, dur, vib=0.0, vib_rate=40.0):
    x = t(dur)
    f = f0 + (f1 - f0) * (x / dur) + vib * np.sin(2 * np.pi * vib_rate * x)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * x / dur) ** 1.5
    return (np.sin(ph) + 0.12 * np.sin(2 * ph)) * env


def chirp():
    out = np.zeros(int(0.42 * SR))
    add(out, 0, tweet(2600, 4200, 0.07), wrap=False)
    add(out, 0.1 * SR, tweet(2900, 4600, 0.06), wrap=False)
    add(out, 0.19 * SR, tweet(4300, 2700, 0.14, vib=180, vib_rate=35), wrap=False)
    return fade_out(out)


def step(rng, pitch):
    x = t(0.16)
    f = pitch * (1 + 0.5 * np.exp(-x * 60))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 38)
    grit = fft_filter(rng.standard_normal(len(x)), lo=300, hi=1800) * np.exp(-x * 70)
    grit /= np.max(np.abs(grit)) + 1e-9
    s = body * 0.8 + grit * 0.35
    s *= np.minimum(1, x / 0.003)
    return fade_out(s)


def hum():
    """A closed-mouth "mm-hm", voiced through a nasal formant shape."""
    dur = 0.48
    x = t(dur)
    syll = np.where(x < 0.2, 1.0, 0.0)
    f0 = np.where(x < 0.2, 200 + 25 * (x / 0.2), 205 + 45 * np.sin(np.pi * np.clip((x - 0.24) / 0.24, 0, 1)) - 20 * (x > 0.36))
    ph = 2 * np.pi * np.cumsum(f0 * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * x))) / SR
    s = np.zeros(len(x))
    for h in range(1, 18):
        fh = 210 * h
        formant = np.exp(-((fh - 260) / 140) ** 2) + 0.35 * np.exp(-((fh - 1100) / 260) ** 2) + 0.12 * np.exp(-((fh - 2300) / 400) ** 2)
        s += np.sin(h * ph) * formant / h ** 0.3
    a = np.clip(x / 0.03, 0, 1) * np.clip((0.2 - x) / 0.035, 0, 1) * syll
    b = np.clip((x - 0.24) / 0.03, 0, 1) * np.clip((dur - x) / 0.08, 0, 1) * (1 - syll)
    return fade_out(s * (a * 0.9 + b))


def pop():
    x = t(0.09)
    f = 300 + 900 * np.exp(-x * 70)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 55)
    s[: int(0.0015 * SR)] += np.hanning(int(0.0015 * SR)) * 0.6
    return fade_out(s)


def click():
    x = t(0.05)
    s = 0.6 * np.sin(2 * np.pi * 2200 * x) * np.exp(-x * 400) + np.sin(2 * np.pi * 720 * x) * np.exp(-x * 130)
    return fade_out(s * np.minimum(1, x / 0.0008))


def sparkle(rng):
    out = np.zeros(int(1.9 * SR))
    for i, name in enumerate(['C6', 'E6', 'G6', 'C7', 'E7']):
        add(out, i * 0.065 * SR, bell(midi(note(name)), 1.5, 0.55 - 0.05 * i), wrap=False)
    shimmer = fft_filter(rng.standard_normal(len(out)), lo=6000, hi=12000)
    x = np.arange(len(out)) / SR
    shimmer *= np.exp(-((x - 0.45) / 0.35) ** 2) * 0.05 / (np.std(shimmer) + 1e-9)
    ir = reverb_ir(1.2, np.random.default_rng(9), decay=3)
    wet = conv_linear(out, ir)[: len(out)]
    return fade_out(out + shimmer + wet * 0.25)


def birds(rng, calls):
    out = np.zeros(int(2.6 * SR))
    at = 0.05
    for _ in range(calls):
        kind = rng.integers(3)
        base = rng.uniform(2800, 4200)
        if kind == 0:
            for k in range(rng.integers(3, 6)):
                add(out, (at + k * 0.075) * SR, tweet(base, base * 1.25, 0.05) * 0.7, wrap=False)
            at += 0.5
        elif kind == 1:
            add(out, at * SR, tweet(base * 1.3, base * 0.8, 0.22, vib=220, vib_rate=28), wrap=False)
            at += 0.4
        else:
            add(out, at * SR, tweet(base * 0.8, base * 1.1, 0.12), wrap=False)
            add(out, (at + 0.15) * SR, tweet(base * 1.1, base * 0.75, 0.16), wrap=False)
            at += 0.45
        at += rng.uniform(0.05, 0.25)
    ir = reverb_ir(0.8, np.random.default_rng(13), decay=4, lo=1000)
    return fade_out(out + conv_linear(out, ir)[: len(out)] * 0.2)


def crickets(rng):
    out = np.zeros(int(2.6 * SR))
    for f, start, gap in ((4400, 0.0, 0.62), (4950, 0.3, 0.78)):
        at = start
        while at < 2.3:
            for p in range(4):
                x = t(0.018)
                pulse = np.sin(2 * np.pi * f * x) * np.sin(np.pi * x / 0.018) ** 2
                add(out, (at + p * 0.032) * SR, pulse * rng.uniform(0.6, 1.0), wrap=False)
            at += gap + rng.uniform(-0.05, 0.05)
    return fade_out(out)


# ------------------------------------------------------------ animals


def voice(f0, formants, env, harmonics=24, breath=0.0, rng=None):
    """Additive voiced sound: harmonics of the f0 contour weighted by moving
    formants. Each formant is (centre Hz contour, bandwidth Hz, gain)."""
    ph = 2 * np.pi * np.cumsum(f0) / SR
    s = np.zeros(len(f0))
    for h in range(1, harmonics + 1):
        fh = f0 * h
        w = np.zeros(len(f0))
        for centre, bw, gain in formants:
            w += gain * np.exp(-((fh - centre) / bw) ** 2)
        s += np.sin(h * ph) * w * (fh < SR / 2 - 500)
    if breath and rng is not None:
        n = fft_filter(rng.standard_normal(len(f0)), lo=1500, hi=7000)
        s += n / (np.std(n) + 1e-9) * breath * np.std(s)
    return s * env


def glide(points, dur):
    """A smooth contour through (time, value) points over dur seconds."""
    x = t(dur)
    ts, vs = zip(*points)
    return np.interp(x, ts, vs)


def meow(rng):
    dur = 0.62
    x = t(dur)
    f0 = glide([(0, 520), (0.14, 760), (0.34, 700), (dur, 430)], dur) * (1 + 0.012 * np.sin(2 * np.pi * 6 * x))
    f1 = glide([(0, 350), (0.18, 900), (0.4, 750), (dur, 480)], dur)
    f2 = glide([(0, 2300), (0.18, 1500), (0.4, 1200), (dur, 900)], dur)
    env = np.clip(x / 0.04, 0, 1) * np.clip((dur - x) / 0.16, 0, 1) ** 1.3
    s = voice(f0, [(f1, 220, 1.0), (f2, 300, 0.55), (f2 * 1.9, 500, 0.15)], env, breath=0.06, rng=rng)
    return fade_out(s)


def cluck(rng):
    out = np.zeros(int(0.62 * SR))
    for i, (at, pitch) in enumerate(((0.0, 1.0), (0.13, 1.08), (0.27, 0.96), (0.4, 1.18))):
        dur = 0.075 if i < 3 else 0.16
        x = t(dur)
        f0 = 330 * pitch * (1 + 0.25 * np.exp(-x * 40)) * (1 + (0.35 * x / dur if i == 3 else 0))
        env = np.clip(x / 0.006, 0, 1) * np.exp(-x * (38 if i < 3 else 14))
        s = voice(f0, [(780, 260, 1.0), (1600, 380, 0.5), (2900, 500, 0.15)], env, harmonics=20, breath=0.12, rng=rng)
        add(out, at * SR, s * (0.8 if i < 3 else 1.0), wrap=False)
    return fade_out(out)


def quack(rng):
    out = np.zeros(int(0.62 * SR))
    for at, pitch in ((0.0, 1.0), (0.26, 0.93)):
        dur = 0.2
        x = t(dur)
        f0 = 230 * pitch * glide([(0, 1.05), (0.06, 1.0), (dur, 0.86)], dur)
        env = np.clip(x / 0.012, 0, 1) * np.clip((dur - x) / 0.07, 0, 1)
        nasal = glide([(0, 1200), (0.08, 1500), (dur, 1250)], dur)
        s = voice(f0, [(700, 200, 0.9), (nasal, 260, 1.0), (2600, 500, 0.35)], env, harmonics=30, breath=0.1, rng=rng)
        add(out, at * SR, s, wrap=False)
    return fade_out(out)


def woof(rng):
    dur = 0.3
    x = t(dur)
    f0 = glide([(0, 300), (0.04, 340), (dur, 170)], dur)
    env = np.clip(x / 0.008, 0, 1) * np.exp(-x * 11)
    s = voice(f0, [(560, 220, 1.0), (1100, 300, 0.6), (2400, 600, 0.2)], env, harmonics=26, breath=0.3, rng=rng)
    burst = fft_filter(rng.standard_normal(len(x)), lo=300, hi=2500) * np.exp(-x * 60)
    s += burst / (np.max(np.abs(burst)) + 1e-9) * 0.25 * np.max(np.abs(s))
    return fade_out(s)


# ------------------------------------------------------------ output


def fade_out(x, ms=6):
    n = int(ms / 1000 * SR)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def normalize(x, lufs_like_db):
    """Scales to an RMS target and keeps peaks under -1 dBFS."""
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    x = x * (10 ** (lufs_like_db / 20) / rms)
    peak = np.max(np.abs(x))
    if peak > 0.89:
        x *= 0.89 / peak
    return x


def peak_normalize(x, db=-3):
    return x * (10 ** (db / 20) / (np.max(np.abs(x)) + 1e-12))


def encode(path, x, bitrate):
    """Writes x (mono 1-D or 2 x n stereo) as Ogg Opus through ffmpeg."""
    data = x if x.ndim == 1 else x.T
    channels = 1 if x.ndim == 1 else 2
    pcm = (np.clip(data, -1, 1) * 32767).astype('<i2').tobytes()
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', str(channels), '-i', '-',
           '-c:a', 'libopus', '-b:a', bitrate, '-vbr', 'on', '-application', 'audio', '-map_metadata', '-1', path]
    subprocess.run(cmd, input=pcm, check=True)


def preview(path, day, sfx):
    """A 20 s mix of the day loop with effects dropped in, as AAC."""
    n = 20 * SR
    mix = day[:, :n] * 0.5
    cues = [(1.0, 'click'), (2.0, 'flap'), (2.6, 'flap'), (3.4, 'chirp'), (4.2, 'hum', 1.0), (6.5, 'pop'), (7.0, 'hum', 1.25),
            (9.2, 'pop'), (10.0, 'step1'), (10.45, 'step2'), (10.9, 'step1'), (11.35, 'step2'), (12.5, 'birds1'),
            (15.0, 'sparkle'), (17.0, 'hum', 0.82), (18.6, 'pop'), (19.0, 'click')]
    for cue in cues:
        at, name = cue[0], cue[1]
        s = sfx[name]
        if len(cue) > 2:
            idx = np.arange(0, len(s) - 1, cue[2])
            s = np.interp(idx, np.arange(len(s)), s)
        gain = {'step1': 0.25, 'step2': 0.25, 'birds1': 0.35}.get(name, 0.6)
        add(mix[0], at * SR, s * gain, wrap=False)
        add(mix[1], at * SR, s * gain, wrap=False)
    mix = mix * (0.89 / max(0.89, np.max(np.abs(mix))))
    pcm = (mix.T * 32767).astype('<i2').tobytes()
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-',
           '-c:a', 'aac', '-b:a', '160k', path]
    subprocess.run(cmd, input=pcm, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', default=os.path.join(ROOT, 'assets', 'audio'))
    parser.add_argument('--preview', help='also write a 20 s listening mix (.m4a) here')
    parser.add_argument('--only', help='comma-separated names to write, leaving the other files alone')
    args = parser.parse_args()
    if shutil.which('ffmpeg') is None:
        sys.exit('ffmpeg (with libopus) is required')
    os.makedirs(args.out, exist_ok=True)

    rng = np.random.default_rng(2026)
    day = day_loop(np.random.default_rng(42))
    music = {
        'music_day': (day, '96k'),
        'music_night': (night_loop(np.random.default_rng(43)), '80k'),
        'rain': (rain_loop(np.random.default_rng(44)), '64k'),
    }
    sfx = {
        'flap': peak_normalize(flap(rng), -4),
        'chirp': peak_normalize(chirp(), -6),
        'step1': peak_normalize(step(rng, 70), -6),
        'step2': peak_normalize(step(rng, 82), -6),
        'hum': peak_normalize(hum(), -5),
        'pop': peak_normalize(pop(), -6),
        'click': peak_normalize(click(), -8),
        'sparkle': peak_normalize(sparkle(rng), -4),
        'birds1': peak_normalize(birds(rng, 4), -6),
        'birds2': peak_normalize(birds(rng, 3), -6),
        'crickets': peak_normalize(crickets(rng), -8),
        'meow': peak_normalize(meow(np.random.default_rng(61)), -5),
        'cluck': peak_normalize(cluck(np.random.default_rng(62)), -6),
        'quack': peak_normalize(quack(np.random.default_rng(63)), -6),
        'woof': peak_normalize(woof(np.random.default_rng(64)), -5),
    }
    if args.only:
        only = set(args.only.split(','))
        music = {k: v for k, v in music.items() if k in only}
        sfx = {k: v for k, v in sfx.items() if k in only}
    for name, (x, rate) in music.items():
        encode(os.path.join(args.out, f'{name}.ogg'), x, rate)
        print(f'{name}.ogg  {x.shape[1] / SR:.2f} s ({x.shape[1]} samples)')
    for name, x in sfx.items():
        encode(os.path.join(args.out, f'{name}.ogg'), x, '48k')
        print(f'{name}.ogg  {len(x) / SR:.2f} s')
    if args.preview:
        preview(args.preview, day, sfx)
        print(f'preview: {args.preview}')


if __name__ == '__main__':
    main()
