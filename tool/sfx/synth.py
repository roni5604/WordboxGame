"""מנוע הצלילים של tool/generate_sfx.py: כלים בהשראה פיזיקלית (מרימבה, קלימבה,
פעמונים, בועות), "פשששש" של רעש מסונן, שירה בלי מילים (פורמנטים) והד.
הכל פרוצדורלי - בלי קבצי אודיו חיצוניים ובלי סוגיות רישוי. פלט: WAV סטריאו 44.1k."""
import math
import wave

import numpy as np
import scipy.signal as sg

SR = 44100
rng = np.random.default_rng(11)


def T(dur):
    return np.arange(int(SR * dur)) / SR


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


NOTES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def n(name):
    """'C5' -> Hz, 'F#4' supported."""
    base = NOTES[name[0]]
    rest = name[1:]
    if rest.startswith('#'):
        base += 1
        rest = rest[1:]
    elif rest.startswith('b'):
        base -= 1
        rest = rest[1:]
    return midi(12 * (int(rest) + 1) + base)


def fade_tail(x, ms=8):
    k = min(len(x), int(SR * ms / 1000))
    if k > 0:
        x[-k:] *= np.linspace(1, 0, k)
    return x


def lowpass(x, fc, order=2):
    sos = sg.butter(order, min(fc, SR * 0.45), 'low', fs=SR, output='sos')
    return sg.sosfilt(sos, x)


def highpass(x, fc, order=2):
    sos = sg.butter(order, fc, 'high', fs=SR, output='sos')
    return sg.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = sg.butter(order, [lo, min(hi, SR * 0.45)], 'band', fs=SR, output='sos')
    return sg.sosfilt(sos, x)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def pink(dur):
    w = rng.standard_normal(int(SR * dur))
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    p = sg.lfilter(b, a, w)
    return p / (np.max(np.abs(p)) + 1e-9)


# ---------------------------------------------------------------- instruments

def modal(f, dur, partials, vel=1.0, strike=0.0, strike_fc=3000, dec_scale=True, attack_ms=1.2):
    t = T(dur)
    out = np.zeros_like(t)
    ds = (440.0 / f) ** 0.45 if dec_scale else 1.0
    for ratio, amp, dec in partials:
        fr = f * ratio
        if fr > SR * 0.45:
            continue
        ph = rng.uniform(0, 0.3)
        out += amp * np.sin(2 * np.pi * fr * t + ph) * np.exp(-t / (dec * ds))
    out *= 1 - np.exp(-t / (attack_ms / 1000))
    if strike:
        k = min(len(t), int(SR * 0.012))
        s = lowpass(noise(k / SR), strike_fc) * np.exp(-np.arange(k) / (SR * 0.0025))
        out[:k] += s * strike
    return fade_tail(out * vel)


def marimba(f, dur=0.9, vel=1.0):
    return modal(f, dur, [(1, 1, 0.42), (4.0, 0.28, 0.06), (9.9, 0.07, 0.018), (2.0, 0.04, 0.2)], vel, strike=0.35, strike_fc=2200)


def marimba_muted(f, dur=0.25, vel=1.0):
    x = modal(f, dur, [(1, 1, 0.07), (4.0, 0.15, 0.02)], vel, strike=0.5, strike_fc=1200, dec_scale=False)
    return lowpass(x, 1800)


def kalimba(f, dur=1.4, vel=1.0):
    x = modal(f, dur, [(1, 1, 0.9), (2.0, 0.04, 0.4), (5.9, 0.22, 0.09), (13.6, 0.07, 0.03)], vel, strike=0.25, strike_fc=5000)
    # gentle tine "buzz": tiny amplitude wobble
    t = T(dur)
    return x * (1 + 0.04 * np.sin(2 * np.pi * 7 * t) * np.exp(-t / 0.3))


def glock(f, dur=1.6, vel=1.0):
    return modal(f, dur, [(1, 1, 1.3), (2.76, 0.3, 0.3), (5.4, 0.14, 0.1), (8.93, 0.07, 0.05)], vel, strike=0.15, strike_fc=8000)


def celesta(f, dur=1.4, vel=1.0):
    return modal(f, dur, [(1, 1, 1.0), (3.0, 0.1, 0.25), (4.05, 0.16, 0.16), (9.8, 0.04, 0.05)], vel, strike=0.08, strike_fc=7000)


def fmbell(f, dur=0.8, ratio=3.5, index=3.0, dec=0.35, vel=1.0):
    t = T(dur)
    I = index * np.exp(-t / (dec * 0.35))
    x = np.sin(2 * np.pi * f * t + I * np.sin(2 * np.pi * f * ratio * t)) * np.exp(-t / dec)
    x *= 1 - np.exp(-t / 0.0008)
    return fade_tail(x * vel)


def coin_ring(f, dur=0.6, vel=1.0):
    """bright metallic coin: inharmonic partials, fast shimmer."""
    return modal(f, dur, [(1, 1, 0.35), (2.32, 0.5, 0.25), (4.25, 0.3, 0.12), (6.63, 0.15, 0.06)], vel, strike=0.2, strike_fc=9000, dec_scale=False)


def bubble(f, dur=0.14, rise=1.9, dec=0.05, vel=1.0):
    """Minnaert-style bubble 'bloop' — the frequency glides up quickly."""
    t = T(dur)
    fr = f * (1 + (rise - 1) * (1 - np.exp(-t / 0.03)))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    x = np.sin(ph) * np.exp(-t / dec) * (1 - np.exp(-t / 0.002))
    return fade_tail(x * vel)


def drop(f0, f1, dur=0.18, dec=0.08, vel=1.0):
    """pitch glide down (cartoon 'bwop')."""
    t = T(dur)
    fr = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    x = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * np.exp(-t / dec) * (1 - np.exp(-t / 0.003))
    return fade_tail(x * vel)


def pop(vel=1.0):
    k = int(SR * 0.02)
    x = highpass(noise(k / SR), 900) * np.exp(-np.arange(k) / (SR * 0.0025))
    return x * vel


def ks_pluck(f, dur=0.6, damp=0.994, bright=2500, vel=1.0):
    N = max(2, int(round(SR / f)))
    buf = lowpass(rng.uniform(-1, 1, N * 4), bright)[-N:].tolist()
    out = np.zeros(int(SR * dur))
    idx = 0
    for i in range(len(out)):
        a = buf[idx]
        b = buf[(idx + 1) % N]
        buf[idx] = damp * 0.5 * (a + b)
        out[i] = a
        idx = (idx + 1) % N
    return fade_tail(out / (np.max(np.abs(out)) + 1e-9) * vel)


def thud(f0=160, f1=55, dur=0.22, vel=1.0):
    t = T(dur)
    fr = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    body = np.sin(ph) * np.exp(-t / 0.07)
    k = int(SR * 0.015)
    click = lowpass(noise(k / SR), 1500) * np.exp(-np.arange(k) / (SR * 0.003))
    body[:k] += 0.6 * click
    return fade_tail(body * vel)


def brass(f, dur, vel=1.0, vib=True):
    """additive brass: harmonic brightness opens on attack ('blat') then settles."""
    t = T(dur)
    fm = f * (1 + (0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.2, 0, 1) if vib else 0))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    bright = 0.35 + 0.65 * np.exp(-t / 0.08)
    x = np.zeros_like(t)
    for h in range(1, 14):
        if f * h > 9000:
            break
        x += np.sin(h * ph) / h * np.exp(-(h - 1) * (1.1 - bright))
    env = np.clip(t / 0.03, 0, 1) * np.exp(-t / (dur * 1.8))
    x = x * env
    return fade_tail(lowpass(x, 5000) * vel * 0.5, 30)


def pad(freqs, dur, vel=1.0, vowel='a', attack=0.15):
    """warm choir-ish pad: detuned saws through a static vowel formant."""
    t = T(dur)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-0.006, 0.0, 0.007):
            ff = f * (1 + det) * (1 + 0.003 * np.sin(2 * np.pi * (4.8 + det * 100) * t))
            ph = 2 * np.pi * np.cumsum(ff) / SR + rng.uniform(0, 6)
            for h in range(1, 18):
                if f * h > 7000:
                    break
                x += np.sin(h * ph) / h ** 1.1
    x = formant_static(x, vowel)
    env = np.clip(t / attack, 0, 1) * np.clip((dur - t) / (dur * 0.5), 0, 1)
    return fade_tail(x * env / (np.max(np.abs(x)) + 1e-9) * vel, 40)


VOWELS = {  # F1, F2, F3 (soprano-ish)
    'u': (330, 800, 2700),
    'o': (450, 830, 2800),
    'a': (800, 1150, 2900),
    'e': (420, 2000, 2800),
    'i': (300, 2400, 3200),
}


def formant_static(x, vowel):
    f1, f2, f3 = VOWELS[vowel]
    y = 1.0 * bandpass(x, f1 * 0.8, f1 * 1.25) + 0.6 * bandpass(x, f2 * 0.88, f2 * 1.12) + 0.25 * bandpass(x, f3 * 0.9, f3 * 1.1)
    return y + 0.08 * lowpass(x, 400)


def svf_bank(x, fcs, qs, gains):
    """time-varying parallel band-pass filters (TPT SVF). fcs: list of arrays."""
    out = np.zeros_like(x)
    for fc, q, gn in zip(fcs, qs, gains):
        g = np.tan(np.pi * np.clip(fc, 30, SR * 0.45) / SR)
        k = 1.0 / q
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        ic1 = ic2 = 0.0
        y = np.empty_like(x)
        for i in range(len(x)):
            v3 = x[i] - ic2
            v1 = a1[i] * ic1 + a2[i] * v3
            v2 = ic2 + a2[i] * ic1 + a3[i] * v3
            ic1 = 2 * v1 - ic1
            ic2 = 2 * v2 - ic2
            y[i] = v1
        out += gn * y
    return out


def interp_path(points, n_samples):
    """points: [(time_fraction, value)] -> smooth array."""
    xs = np.array([p[0] for p in points])
    ys = np.array([p[1] for p in points], dtype=float)
    u = np.linspace(0, 1, n_samples)
    v = np.interp(u, xs, ys)
    return sg.savgol_filter(v, min(2001, (n_samples // 4) * 2 + 1), 2) if n_samples > 50 else v


def voice(dur, pitch_pts, vowel_pts, vel=1.0, breath=0.12, voices=3, bright=1.0):
    """Wordless sung exclamation ('woo', 'wow', 'yay') via glottal source + moving formants."""
    N = int(SR * dur)
    t = np.arange(N) / SR
    f0 = interp_path(pitch_pts, N)
    vowel_track = [(p, VOWELS[v]) for p, v in vowel_pts]
    fcs = [interp_path([(p, f[i]) for p, f in vowel_track], N) for i in range(3)]
    src = np.zeros(N)
    for vi in range(voices):
        det = 1 + (vi - (voices - 1) / 2) * 0.009
        jitter = 1 + 0.004 * lowpass(rng.standard_normal(N), 8)
        vib = 1 + 0.012 * np.sin(2 * np.pi * (5.2 + vi * 0.3) * t + vi) * np.clip((t - 0.1) / 0.15, 0, 1)
        ph = 2 * np.pi * np.cumsum(f0 * det * jitter * vib) / SR
        delay = int(SR * 0.008 * vi)
        s = np.zeros(N)
        for h in range(1, 30):
            if np.max(f0) * h > 6000:
                break
            s += np.sin(h * ph) / h ** (1.35 / bright)
        src += np.roll(s, delay)
    src += breath * pink(dur) * 3
    y = svf_bank(src, fcs, [6, 9, 10], [1.0, 0.55, 0.22])
    env = np.clip(t / 0.04, 0, 1) * np.clip((dur - t) / 0.12, 0, 1)
    y = y * env
    return fade_tail(y / (np.max(np.abs(y)) + 1e-9) * vel, 30)


def whoosh(dur, f0, f1, q=1.6, vel=1.0, shape=0.5):
    """'pshhh' — noise swept through a band-pass; shape=peak position 0..1."""
    N = int(SR * dur)
    x = pink(dur) * 0.5 + noise(dur) * 0.5
    u = np.linspace(0, 1, N)
    fc = f0 * (f1 / f0) ** u
    y = svf_bank(x, [fc], [q], [1.0])
    env = np.where(u < shape, (u / shape) ** 1.5, ((1 - u) / (1 - shape)) ** 1.2)
    y = y * env
    return fade_tail(y / (np.max(np.abs(y)) + 1e-9) * vel, 15)


def shhh(dur=0.5, vel=1.0, hp=5000, dec=0.18):
    """bright airy 'pshhh' spray (sparkle air)."""
    t = T(dur)
    x = highpass(noise(dur), hp, 4) * np.exp(-t / dec) * np.clip(t / 0.01, 0, 1)
    return fade_tail(x / (np.max(np.abs(x)) + 1e-9) * vel)


PENTA = [0, 2, 4, 7, 9]


def penta_note(i, base=72):
    return midi(base + 12 * (i // 5) + PENTA[i % 5])


# ---------------------------------------------------------------- mixing

class Mix:
    def __init__(self, dur):
        self.buf = np.zeros((2, int(SR * dur) + 1))

    def add(self, sig, at=0.0, gain=1.0, pan=0.0):
        s = int(SR * at)
        if s >= self.buf.shape[1]:
            return self
        e = min(self.buf.shape[1], s + len(sig))
        seg = sig[: e - s] * gain
        l = math.cos((pan + 1) * math.pi / 4)
        r = math.sin((pan + 1) * math.pi / 4)
        self.buf[0, s:e] += seg * l * 1.414
        self.buf[1, s:e] += seg * r * 1.414
        return self

    def sparkle(self, at, dur, count, lo=84, hi=103, inst=None, gain=0.25, rise=True):
        inst = inst or glock
        pool = [m for m in range(lo, hi + 1) if (m % 12) in PENTA]
        for i in range(count):
            u = i / max(1, count - 1)
            tt = at + dur * (u ** 0.8) + rng.uniform(-0.01, 0.01)
            if rise:
                idx = int(u * (len(pool) - 1) * 0.8 + rng.integers(0, max(1, len(pool) // 5)))
            else:
                idx = int(rng.integers(0, len(pool)))
            f = midi(pool[min(idx, len(pool) - 1)])
            self.add(inst(f, 0.6, rng.uniform(0.5, 1.0)), tt, gain * (1 - 0.5 * u), rng.uniform(-0.8, 0.8))
        return self

    def render(self, rt=1.2, wet=0.18, tail=None, predelay=0.012, damp=6000, max_dur=None):
        """max_dur: אורך מקסימלי בשניות (כולל זנב ההד) - הצליל לא יימשך יותר מהאנימציה שהוא מלווה."""
        dry = self.buf
        tail = rt if tail is None else tail
        out_len = dry.shape[1] + int(SR * min(tail, rt))
        out = np.zeros((2, out_len))
        out[:, : dry.shape[1]] = dry
        if wet > 0:
            for ch in range(2):
                L = int(SR * rt)
                tt = np.arange(L) / SR
                ir = rng.standard_normal(L) * np.exp(-6.9 * tt / rt)
                ir = lowpass(ir, damp, 1)
                pd = int(SR * (predelay + 0.004 * ch))
                ir = np.concatenate([np.zeros(pd), ir])
                ir /= np.sqrt(np.sum(ir ** 2))
                src = dry[ch] * 0.7 + dry[1 - ch] * 0.3
                w = sg.fftconvolve(src, ir)[:out_len]
                out[ch, : len(w)] += w * wet * 2.2
        # gentle glue: soft-clip then peak normalize to -1 dBFS
        peak = np.max(np.abs(out)) + 1e-9
        out = np.tanh(out / peak * 1.1) / np.tanh(1.1)
        out *= 0.89 / (np.max(np.abs(out)) + 1e-9)
        # trim trailing silence below -60 dB
        env = np.max(np.abs(out), axis=0)
        idx = np.where(env > 0.001)[0]
        end = (idx[-1] + int(SR * 0.02)) if len(idx) else out.shape[1]
        out = out[:, : min(end, out.shape[1])]
        if max_dur is not None and out.shape[1] > int(SR * max_dur):
            out = out[:, : int(SR * max_dur)]
            k = min(out.shape[1], int(SR * 0.12))
            out[:, -k:] *= np.linspace(1, 0, k) ** 2
        k = min(out.shape[1], int(SR * 0.02))
        out[:, -k:] *= np.linspace(1, 0, k)
        return out


def save(path, stereo):
    data = (np.clip(stereo.T, -1, 1) * 32000).astype('<i2')
    with wave.open(path, 'w') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
