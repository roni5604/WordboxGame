#!/usr/bin/env python3
"""
מייצר את מוזיקת התפריטים (assets/audio/music_loop.wav) - לופ קצבי ושמח שמתנגן
רק בין משחקים (מסך הבית, מפה, תוצאות). בזמן המשחק עצמו המוזיקה עוצרת.

סגנון: פופ קליל ומעורר, 116 BPM (קצב טיפוסי למוזיקת תפריט במשחקי קז'ואל,
100-120), דו מז'ור - אותו סולם כמו כל אפקטי הצליל. אקורדים C-G-Am-F
(ה"ארבעה אקורדים" של הפופ). שכבות:
  - בס קופצני בשמיניות (שורש-אוקטבה)
  - אקורדים "פלאקיים" על ה"וחצי" (סגנון יוקללה) - הקפיצה של השיר
  - בעיטה רכה, מחיאות כפיים על 2 ו-4, היי-האט בשש-עשריות
  - הוּק של מרימבה+פעמון שחוזר (הכי "נתקע בראש"), ובחצי השני קלימבה מעליו
  - בועות קטנות בסוף משפטים - החתימה של המשחק
העיבוד דליל באמצע הספקטרום כדי שצלילי הכפתורים יישמעו ברור מעליו.

הזנב של ההד בסוף "מתגלגל" לתחילת הקובץ כך שהלופ רציף. מונו 22.05kHz WAV
(בלי "קפיצה" בנקודת הלופ שיש ב-MP3/AAC).

הרצה (צריך numpy ו-scipy):  /tmp/sfx/bin/python tool/generate_music.py
"""
import os
import sys
import wave

import numpy as np
import scipy.signal as sg

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'sfx'))
import synth as S  # noqa: E402
from synth import SR, T, bandpass, bubble, glock, highpass, kalimba, ks_pluck, lowpass, marimba, midi, thud  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'music_loop.wav')

BPM = 116
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 16
LOOP = BARS * BAR
TAIL = 2.5

# אקורד לכל תיבה: (שורש הבס, צלילי האקורד הפלאקי)
CHORDS = [
    (36, (60, 64, 67)),  # C
    (31, (59, 62, 67)),  # G
    (33, (60, 64, 69)),  # Am
    (29, (60, 65, 69)),  # F
]

# ההוק - 4 תיבות (פעמה מתחילת המשפט, תו midi, משך בפעמות). פנטטוני ברובו.
HOOK = [
    (0, 76, .5), (1, 79, .5), (1.5, 76, .5), (2.5, 74, .5), (3, 72, 1),
    (4, 74, .5), (4.5, 74, .5), (5, 79, .5), (6, 79, .5), (6.5, 81, .5), (7, 79, 1),
    (8, 81, .5), (9, 84, .5), (9.5, 81, .5), (10.5, 79, .5), (11, 76, 1),
    (12, 72, .5), (13, 74, .5), (13.5, 76, .5), (14, 79, 1), (15.5, 76, .5),
]
# סיום משפט שני (תיבה 8 / 16) - נחיתה על דו
HOOK_END = [(12, 79, .5), (13, 76, .5), (13.5, 74, .5), (14, 72, 2)]


def nz(k):
    """רעש לבן באורך מדויק של k דגימות."""
    return S.rng.uniform(-1, 1, k)


def clap(v=1.0):
    """מחיאת כף: שלושה פרצי רעש צמודים (כמו כמה ידיים) + זנב קצר."""
    out = np.zeros(int(SR * 0.18))
    for i, d in enumerate((0.0, 0.009, 0.018)):
        k = int(SR * (0.012 if i < 2 else 0.15))
        b = bandpass(nz(k), 900, 3200) * np.exp(-np.arange(k) / (SR * (0.003 if i < 2 else 0.035)))
        s = int(SR * d)
        seg = b[: len(out) - s]
        out[s: s + len(seg)] += seg
    return out * v


def hat(v=1.0, open_=False):
    k = int(SR * (0.12 if open_ else 0.035))
    return highpass(nz(k), 7500, 4) * np.exp(-np.arange(k) / (SR * (0.035 if open_ else 0.007))) * v


def kick(v=1.0):
    return thud(150, 48, 0.22, 1.0) * v


def bass_note(f, dur, v=1.0):
    """בס "פלאקי": מסור מסונן עם פילטר שנפתח בהתחלה ונסגר - קופצני."""
    t = T(dur)
    x = np.zeros_like(t)
    for h in range(1, 9):
        x += np.sin(2 * np.pi * f * h * t) / h * np.exp(-t * (h - 1) * 9)
    env = np.clip(t / 0.004, 0, 1) * np.exp(-t / 0.22)
    return lowpass(x * env, 900) * v


def strum(notes, v=1.0):
    """אקורד יוקללה קצר: מיתרים שנפרטים ב-12ms אחד אחרי השני, מושתקים מהר."""
    out = np.zeros(int(SR * 0.3))
    for i, m in enumerate(notes):
        p = ks_pluck(midi(m), 0.28, damp=0.985, bright=4000, vel=1.0)
        s = int(SR * 0.012 * i)
        seg = p[: len(out) - s]
        out[s: s + len(seg)] += seg * (0.9 - 0.1 * i)
    out *= np.exp(-T(0.3) / 0.1)[: len(out)]
    return highpass(out, 250) * v


def lead(m, dur, v=1.0):
    """המרימבה של ההוק עם פעמון באוקטבה מעליה - ברור ובהיר בכל רמקול."""
    x = marimba(midi(m), max(0.5, dur * BEAT + 0.35), v)
    return x + glock(midi(m + 12), len(x) / SR, 0.22 * v)[: len(x)]


def main():
    S.rng = np.random.default_rng(116)
    rng = S.rng
    n_total = int(SR * (LOOP + TAIL))
    dry = np.zeros(n_total)

    def add(sig, at, gain=1.0):
        if gain == 0:
            return
        if at < 0:  # מתחיל לפני תחילת הלופ - החלק המוקדם נכנס לסוף הלופ
            k = int(SR * -at)
            add(sig[:k], LOOP + at, gain)
            sig, at = sig[k:], 0.0
        s = int(SR * at)
        e = min(n_total, s + len(sig))
        if s < n_total:
            dry[s:e] += sig[: e - s] * gain

    def hum():  # תזוזה אנושית קטנה בתזמון
        return rng.uniform(-0.005, 0.005)

    for bar in range(BARS):
        root, chord = CHORDS[bar % 4]
        t0 = bar * BAR
        b_section = bar >= 8

        # תופים
        for beat in (0, 2):
            add(kick(), t0 + beat * BEAT, 0.5)
        if bar % 2:  # סינקופה כל תיבה שנייה
            add(kick(0.7), t0 + 2.5 * BEAT, 0.35)
        for beat in (1, 3):
            add(clap(), t0 + beat * BEAT + hum(), 0.32)
        for i in range(16):
            if not b_section and i % 2:  # בחצי הראשון שמיניות, בשני שש-עשריות
                continue
            accent = 1.0 if i % 4 == 2 else (0.6 if i % 2 == 0 else 0.4)
            add(hat(accent), t0 + i * BEAT / 4 + hum(), 0.12)
        if bar % 4 == 3:
            add(hat(0.8, open_=True), t0 + 3.5 * BEAT, 0.12)

        # בס: שורש-אוקטבה בשמיניות
        for i in range(8):
            m = root + (12 if i % 2 else 0)
            v = 1.0 if i % 4 == 0 else 0.75
            add(bass_note(midi(m), BEAT * 0.55, v), t0 + i * BEAT / 2 + hum(), 0.42)

        # אקורדים פלאקיים על ה"וחצי" של כל פעמה
        for beat in range(4):
            add(strum(chord, 1.0 if beat != 3 else 0.8), t0 + (beat + 0.5) * BEAT + hum(), 0.16)

    # ההוק: פעמיים בכל חצי (תיבות 1-4, 5-8, 9-12, 13-16)
    for phrase in range(4):
        p0 = phrase * 4 * BAR
        notes = HOOK if phrase % 2 == 0 else [n for n in HOOK if n[0] < 12] + HOOK_END
        for beat, m, dur in notes:
            add(lead(m, dur, rng.uniform(0.85, 1.0)), p0 + beat * BEAT + hum(), 0.3)
            if phrase >= 2:  # בחצי השני קלימבה מכפילה באוקטבה - יותר אנרגיה
                add(kalimba(midi(m + 12), 0.6, 0.7), p0 + beat * BEAT + hum(), 0.09)

    # בועות בסוף כל משפט + ריצת בועות שמובילה חזרה לתחילת הלופ
    for phrase in range(4):
        end = (phrase + 1) * 4 * BAR
        runs = (84, 88, 91, 96) if phrase == 3 else (88, 91)
        for j, m in enumerate(runs):
            add(bubble(midi(m), 0.12, 1.7, 0.04, 0.8), end - (len(runs) - j) * BEAT / 4, 0.1)

    m = S.Mix(LOOP + TAIL)
    m.buf[:, :n_total] = dry
    st = m.render(rt=1.2, wet=0.14)
    mono = st.mean(axis=0)
    mono = np.pad(mono, (0, max(0, n_total - len(mono))))[:n_total]

    # לופ רציף: זנב ההד שאחרי סוף הלופ מתווסף לתחילת הקובץ
    n_loop = int(SR * LOOP)
    out = mono[:n_loop].copy()
    out[: n_total - n_loop] += mono[n_loop:]
    out *= 0.7 / (np.max(np.abs(out)) + 1e-9)

    out22 = sg.resample_poly(out, 1, 2)
    data = (np.clip(out22, -1, 1) * 32000).astype('<i2')
    with wave.open(OUT, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR // 2)
        f.writeframes(data.tobytes())
    print(f'נכתב: {OUT} ({len(out22) / (SR / 2):.1f}s)')


if __name__ == '__main__':
    main()
