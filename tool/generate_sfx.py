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
}


def main():
    for filename, builder in RECIPES.items():
        samples = builder()
        save_wav(os.path.join(OUT_DIR, filename), samples)


if __name__ == "__main__":
    main()
