#!/usr/bin/env python3
"""
מייצר את כל צלילי המשחק (SFX) באופן פרוצדורלי, בלי תלות בקבצי אודיו
חיצוניים או סוגיות רישוי - רק גלי סינוס/משולש עם envelope, לפי מתכונים
פשוטים (רצף תדרים + משכים). מריצים פעם אחת ושומרים ל-assets/audio/*.wav.

הרצה:  python3 tool/generate_sfx.py
"""
import math
import os
import struct
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def note(freq, duration, volume=0.5, wave_shape="sine", fade=0.012):
    """מייצר מקטע טון בודד (רשימת samples בין -1..1) עם fade-in/out קצר
    כדי למנוע 'קליק' בתחילת/סוף הטון, ו-envelope שדועך בעדינות (ADSR פשוט)."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    fade_n = max(1, int(SAMPLE_RATE * fade))
    for i in range(n):
        t = i / SAMPLE_RATE
        if wave_shape == "sine":
            raw = math.sin(2 * math.pi * freq * t)
        elif wave_shape == "triangle":
            raw = 2 * abs(2 * ((freq * t) % 1) - 1) - 1
        elif wave_shape == "square":
            raw = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0
        else:
            raw = math.sin(2 * math.pi * freq * t)

        # envelope: fade-in, sustain עם decay עדין, fade-out בסוף
        decay = math.exp(-2.0 * t / max(duration, 0.001))
        env = decay
        if i < fade_n:
            env *= i / fade_n
        if i > n - fade_n:
            env *= (n - i) / fade_n
        samples.append(raw * env * volume)
    return samples


def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def mix(*tracks):
    """מערבב כמה 'רצועות' (רשימות samples) יחד - עבור אקורדים/שכבות."""
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    peak = max((abs(s) for s in out), default=1.0) or 1.0
    if peak > 1.0:
        out = [s / peak for s in out]
    return out


def save_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples
        )
        f.writeframes(frames)
    print(f"נכתב: {path} ({len(samples) / SAMPLE_RATE:.2f}s)")


# תדרי תווים (A4=440 בסיס, סולם דו-מז'ור בקירוב) לנוחות הרכבת מנגינות קטנות
C4, D4, E4, F4, G4, A4, B4 = 261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88
C5, D5, E5, F5, G5, A5, B5, C6 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 987.77, 1046.50


def make_success_word():
    """מציאת מילה תקינה: ארפג'יו קצר ועולה, שמח וקצבי."""
    seq = []
    for f in (E5, G5, C6):
        seq += note(f, 0.09, volume=0.55, wave_shape="triangle")
    return seq


def make_error_word():
    """מילה לא תקינה: שני טונים יורדים, קצרים וממוקדים - לא מציק."""
    seq = note(A4, 0.09, volume=0.4, wave_shape="square")
    seq += note(F4, 0.13, volume=0.35, wave_shape="square")
    return seq


def make_tile_tap():
    """נגיעה ראשונה באות - "טיק" רך וקצרצר."""
    return note(880, 0.035, volume=0.25, wave_shape="sine", fade=0.005)


def make_level_complete():
    """סיום שלב מוצלח: ריצת תווים עולה + אקורד סיום שמח."""
    seq = []
    for f in (C5, E5, G5, C6, E5, G5):
        seq += note(f, 0.11, volume=0.5, wave_shape="triangle")
    seq += silence(0.03)
    chord = mix(
        note(C5, 0.6, volume=0.35, wave_shape="triangle"),
        note(E5, 0.6, volume=0.3, wave_shape="triangle"),
        note(G5, 0.6, volume=0.3, wave_shape="triangle"),
        note(C6, 0.6, volume=0.25, wave_shape="sine"),
    )
    seq += chord
    return seq


def make_hint():
    """שימוש ברמז: "נצנוץ" קסום - סוויפ עולה מהיר עם המון תווים קצרים."""
    seq = []
    freqs = [C5, D5, E5, G5, A5, C6, D5 * 2]
    for f in freqs:
        seq += note(f, 0.05, volume=0.35, wave_shape="sine", fade=0.006)
    return seq


def make_coin():
    """קבלת/רכישת מטבעות: "צ'ינג" בהיר וקצר."""
    seq = mix(note(C6, 0.14, volume=0.45, wave_shape="sine"), note(E5 * 2, 0.14, volume=0.3, wave_shape="sine"))
    return seq


def make_daily_reward():
    """בונוס יומי: ג'ינגל קצר וחגיגי."""
    seq = []
    for f in (C5, E5, G5, C6):
        seq += note(f, 0.1, volume=0.5, wave_shape="triangle")
    seq += mix(
        note(C5, 0.35, volume=0.3, wave_shape="triangle"),
        note(G5, 0.35, volume=0.25, wave_shape="triangle"),
        note(C6, 0.35, volume=0.25, wave_shape="sine"),
    )
    return seq


def make_button_tap():
    """קליק UI כללי - עדין ולא פולשני."""
    return note(1200, 0.025, volume=0.18, wave_shape="sine", fade=0.004)


def make_timer_warning():
    """אזהרת זמן אוזל (כמה שניות אחרונות) - "טיק" חד יותר."""
    return note(660, 0.07, volume=0.4, wave_shape="square", fade=0.008)


def make_star_gained():
    """כוכב הושג במהלך השלב (לא סיום שלב) - "שאבב" זוהר וקצר, שמח יותר
    מ-success_word אך קצר בהרבה מ-level_complete, כדי לחגוג רגע ביניים
    (הגעה ליעד המילים, או לכוכב הבא) בלי להפריע לקצב המשחק."""
    seq = []
    for f in (G5, C6, D5 * 2):
        seq += note(f, 0.08, volume=0.5, wave_shape="sine")
    seq += mix(
        note(C6, 0.22, volume=0.35, wave_shape="sine"),
        note(G5, 0.22, volume=0.25, wave_shape="triangle"),
    )
    return seq


# --- תיבות מזל ודרגות נדירות -------------------------------------------------
import random as _random

_rng = _random.Random(7)  # קבוע - כדי שהקבצים ייווצרו זהים בכל הרצה


def sweep(f0, f1, duration, volume=0.4, fade=0.01):
    """גליסנדו (תדר שמשתנה בהדרגה) - "ווש" של עליית דרגה."""
    n = int(SAMPLE_RATE * duration)
    out, phase = [], 0.0
    fade_n = max(1, int(SAMPLE_RATE * fade))
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        phase += 2 * math.pi * f / SAMPLE_RATE
        env = math.sin(math.pi * t) ** 0.6
        if i < fade_n:
            env *= i / fade_n
        out.append(math.sin(phase) * env * volume)
    return out


def brass(freq, duration, volume=0.4):
    """צליל "חצוצרה" פשוט - כמה הרמוניות עם attack רך, לפנפרה אגדית."""
    n = int(SAMPLE_RATE * duration)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.03)
        decay = math.exp(-1.6 * t / max(duration, 0.001))
        v = sum(math.sin(2 * math.pi * freq * h * t) / h for h in (1, 2, 3, 4, 5))
        out.append(v * 0.45 * attack * decay * volume)
    tail = max(1, int(SAMPLE_RATE * 0.015))
    for i in range(tail):
        out[-1 - i] *= i / tail
    return out


def noise_burst(duration, volume=0.4, decay=18.0):
    """פיצוץ רעש קצר (זיקוק/פופ)."""
    n = int(SAMPLE_RATE * duration)
    out, last = [], 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        last = 0.6 * last + 0.4 * (_rng.random() * 2 - 1)  # מסנן נמוך פשוט
        out.append(last * math.exp(-decay * t) * volume)
    return out


def crackle(duration, volume=0.25, density=60):
    """נצנוצי "קרקל" של זיקוק - פולסים אקראיים קצרצרים."""
    out = [0.0] * int(SAMPLE_RATE * duration)
    for _ in range(int(density * duration)):
        start = _rng.randrange(0, max(1, len(out) - 400))
        f = _rng.uniform(2500, 5200)
        for j in range(300):
            out[start + j] += math.sin(2 * math.pi * f * j / SAMPLE_RATE) * math.exp(-j / 60) * volume * _rng.uniform(0.4, 1)
    return out


def offset(samples, seconds):
    return silence(seconds) + samples


def make_charge(step):
    """לחיצה על תיבה סגורה: "טוק" עמוק + צלצול שעולה עם כל לחיצה."""
    base = [C5, E5, G5, C6][step]
    return mix(
        sweep(180, 70, 0.12, volume=0.55),
        offset(note(base, 0.16, volume=0.35, wave_shape="triangle"), 0.01),
        offset(note(base * 2, 0.12, volume=0.12, wave_shape="sine"), 0.02),
    )


def make_rarity_up():
    """עליית דרגה: "ווש" עולה + אקורד נוצץ."""
    return mix(
        sweep(300, 1800, 0.32, volume=0.35),
        offset(mix(note(E5, 0.3, 0.25, "triangle"), note(G5, 0.3, 0.22, "triangle"), note(C6, 0.35, 0.22, "sine")), 0.22),
        offset(crackle(0.4, volume=0.08, density=40), 0.2),
    )


def make_reveal_common():
    return mix(
        noise_burst(0.12, volume=0.35, decay=30),
        offset(note(G5, 0.1, 0.4, "triangle") + note(C6, 0.22, 0.38, "triangle"), 0.04),
    )


def make_reveal_rare():
    arp = []
    for f in (C5, E5, G5, C6):
        arp += note(f, 0.08, 0.42, "triangle")
    return mix(
        noise_burst(0.18, volume=0.4, decay=20),
        offset(arp, 0.05),
        offset(mix(note(C5, 0.6, 0.25, "triangle"), note(G5, 0.6, 0.22, "triangle"), note(E5 * 2, 0.6, 0.18, "sine")), 0.37),
        offset(crackle(0.6, volume=0.1, density=50), 0.3),
    )


def make_reveal_epic():
    arp = []
    for f in (A4, C5, E5, A5, C6, E5 * 2):
        arp += note(f, 0.075, 0.42, "triangle")
    chord = mix(
        note(A4, 1.0, 0.25, "triangle"), note(E5, 1.0, 0.22, "triangle"),
        note(A5, 1.0, 0.2, "sine"), note(C6 * 1.059, 1.0, 0.16, "sine"),  # C# - מז'ור
    )
    return mix(
        noise_burst(0.3, volume=0.5, decay=12),
        offset(arp, 0.06),
        offset(chord, 0.5),
        offset(crackle(1.0, volume=0.12, density=70), 0.45),
    )


def make_reveal_legendary():
    fanfare = []
    for f, d in ((G4, 0.12), (C5, 0.12), (E5, 0.12), (G5, 0.3), (E5, 0.12), (G5, 0.6)):
        fanfare += brass(f, d, volume=0.5)
    shimmer = []
    for i in range(14):
        shimmer += note([C6, E5 * 2, G5 * 2][i % 3], 0.05, 0.12, "sine", fade=0.004)
    chord = mix(
        brass(C5, 1.4, 0.35), brass(E5, 1.4, 0.3), brass(G5, 1.4, 0.28),
        note(C6, 1.4, 0.2, "sine"), note(C6 * 2, 1.4, 0.06, "sine"),
    )
    return mix(
        noise_burst(0.45, volume=0.55, decay=8),
        offset(fanfare, 0.08),
        offset(chord, 1.5),
        offset(shimmer, 1.5),
        offset(crackle(2.2, volume=0.13, density=80), 0.5),
    )


def make_firework():
    """זיקוק: "בום" עמום + קרקל נוצץ."""
    return mix(
        sweep(140, 45, 0.35, volume=0.55),
        noise_burst(0.5, volume=0.45, decay=9),
        offset(crackle(0.7, volume=0.14, density=90), 0.12),
    )


def make_wheel_tick():
    """קליק של המחוג בגלגל המזל."""
    return mix(note(1800, 0.02, 0.3, "square", fade=0.002), noise_burst(0.02, 0.2, 120))


def make_collect():
    """איסוף פרס: "צ'ינג" כפול עולה."""
    return note(E5 * 2, 0.09, 0.4, "sine") + mix(note(G5 * 2, 0.25, 0.4, "sine"), note(C6, 0.25, 0.25, "triangle"))


RECIPES = {
    "success_word.wav": make_success_word,
    "error_word.wav": make_error_word,
    "tile_tap.wav": make_tile_tap,
    "level_complete.wav": make_level_complete,
    "hint.wav": make_hint,
    "coin.wav": make_coin,
    "daily_reward.wav": make_daily_reward,
    "button_tap.wav": make_button_tap,
    "timer_warning.wav": make_timer_warning,
    "star_gained.wav": make_star_gained,
    "charge_0.wav": lambda: make_charge(0),
    "charge_1.wav": lambda: make_charge(1),
    "charge_2.wav": lambda: make_charge(2),
    "charge_3.wav": lambda: make_charge(3),
    "rarity_up.wav": make_rarity_up,
    "reveal_common.wav": make_reveal_common,
    "reveal_rare.wav": make_reveal_rare,
    "reveal_epic.wav": make_reveal_epic,
    "reveal_legendary.wav": make_reveal_legendary,
    "firework.wav": make_firework,
    "wheel_tick.wav": make_wheel_tick,
    "collect.wav": make_collect,
}


def main():
    import sys
    only = set(sys.argv[1:])  # אפשר לייצר רק קבצים מסוימים: generate_sfx.py firework.wav
    for filename, builder in RECIPES.items():
        if only and filename not in only:
            continue
        samples = builder()
        save_wav(os.path.join(OUT_DIR, filename), samples)


if __name__ == "__main__":
    main()
