#!/usr/bin/env python3
"""
מייצר את כל צלילי המשחק (SFX) באופן פרוצדורלי - בלי קבצי אודיו חיצוניים
ובלי סוגיות רישוי. המנוע (כלים, הד, "פשששש", קולות) נמצא ב-tool/sfx/synth.py.

הצלילים נבחרו במעבדת הצלילים מתוך שלוש חבילות, וכל אחד מגיע מהחבילה שנבחרה לו:
  - בועות: משחק עצמו (אותיות, מילים, שגיאה, כוכב, סיום שלב, כפתורים), פרס אגדי, זיקוק
  - קריסטל (קלימבה/צ'לסטה): רמז, טיימר, בונוס יומי, פתיחת פרס רגיל/נדיר/אפי, איסוף
  - עץ (מרימבה): מטבעות, לחיצות על התיבה, עליית דרגה, גלגל המזל
כל הצלילים בסולם פנטטוני של דו - כך שגם כשהם מתנגנים יחד הם נשמעים הרמוניים.

לכל צליל יש אורך מקסימלי (MAX) שמתאים לאנימציה שהוא מלווה במסך: למשל מילה
נמצאה = באנר של 900ms, שגיאה = הבהוב של 260ms, לחיצה על תיבה = כל 230ms לפחות.

הרצה (צריך numpy ו-scipy):
    python3 -m venv /tmp/sfx && /tmp/sfx/bin/pip install numpy scipy
    /tmp/sfx/bin/python tool/generate_sfx.py               # הכל
    /tmp/sfx/bin/python tool/generate_sfx.py hint coin     # רק חלק
"""
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'sfx'))
import synth as S  # noqa: E402
from synth import (  # noqa: E402
    SR, T, Mix, brass, bubble, celesta, coin_ring, drop, fmbell, glock, highpass, kalimba,
    lowpass, marimba, midi, modal, n, noise, pad, penta_note, pop, save, shhh, thud, voice, whoosh,
)

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


# --- הכלים של כל חבילה ---------------------------------------------------------

def bubble_note(f, v=1.0):
    """"בלופ" של בועה עם נצנוץ פעמון עדין מעליו - הכלי המלודי של חבילת הבועות."""
    x = bubble(f, 0.22, 1.35, 0.09, v) * 0.8
    return x + glock(f * 2, 0.5, 0.18 * v)[: len(x)]


def crystal_note(f, v=1.0):
    return kalimba(f, 1.4, v)


def crystal_hi(f, d=0.6, v=1.0):
    return celesta(f, max(d, 0.9), v)


def wood_note(f, v=1.0):
    return marimba(f, 1.0, v)


def wood_hi(f, d=0.6, v=1.0):
    return glock(f, d, v)


def coins_wood(m, at=0.0, g=1.0):
    m.add(coin_ring(n('B6'), 0.35), at, 0.55 * g, -0.2)
    m.add(coin_ring(n('E7'), 0.6), at + 0.07, 0.7 * g, 0.2)
    m.add(marimba(n('E6'), 0.4), at + 0.07, 0.25 * g)


def coins_crystal(m, at=0.0, g=1.0):
    m.add(fmbell(n('B6'), 0.4, ratio=2.0, index=1.5, dec=0.15), at, 0.5 * g, -0.2)
    m.add(fmbell(n('E7'), 0.9, ratio=2.0, index=1.8, dec=0.3), at + 0.07, 0.7 * g, 0.2)
    m.add(celesta(n('B7'), 0.5), at + 0.09, 0.15 * g)


def v_wow():
    return voice(0.8, [(0, 330), (0.25, 480), (0.6, 440), (1, 300)],
                 [(0, 'u'), (0.18, 'a'), (0.55, 'a'), (0.8, 'o'), (1, 'u')])


def v_woohoo():
    a = voice(0.3, [(0, 400), (1, 520)], [(0, 'u'), (1, 'u')])
    b = voice(0.55, [(0, 520), (0.4, 720), (1, 640)], [(0, 'u'), (0.3, 'o'), (1, 'u')])
    out = np.zeros(int(SR * 0.9))
    out[: len(a)] += a
    s = int(SR * 0.32)
    out[s: s + len(b)] += b
    return out


def choir(dur):
    """מקהלת "אההה" - אקורד דו מז'ור רחב שמתנפח לאט."""
    return pad([n('C4'), n('E4'), n('G4'), n('C5')], dur, 1.0, 'a', 0.25)


def pshhh_up(dur=0.6):
    """"פשששיו" - רעש שעולה למעלה ומתפוגג."""
    return whoosh(dur, 500, 7000, 1.4, 1.0, 0.75)


def sparkle_pshhh(m, at=0.0, g=1.0, inst=glock):
    """"פששש עם נצנצים" - שכבה קסומה למילה ארוכה."""
    m.add(whoosh(0.7, 800, 9000, 1.2, 0.6, 0.6), at, g)
    m.add(shhh(0.6, 0.35, 7000, 0.25), at + 0.3, g)
    m.sparkle(at + 0.15, 0.6, 12, inst=inst, gain=0.3 * g)


# --- משחק: בועות ---------------------------------------------------------------

def tile(k):
    """חיבור אות: כל אות נוספת עולה צליל אחד בסולם (k = מיקום האות במילה).
    האצבע עוברת אות כל ~120ms, אז הצליל קצר וכמעט בלי הד."""
    return Mix(0.4).add(bubble(penta_note(k, 67), 0.16, 1.6, 0.05, 0.95), 0).render(0.5, 0.07, max_dur=0.35)


def success(combo):
    """מילה נמצאה. כל מילה ברצף (combo 0..4) מתחילה גבוה יותר - כמו קנדי קראש.
    הבאנר "מילה נמצאה" מוצג 900ms."""
    r = 72 + [0, 2, 4, 5, 7][combo]
    m = Mix(1.0)
    m.add(pop(0.18), 0)
    for i, iv in enumerate((0, 4, 7, 12)):
        m.add(bubble_note(midi(r + iv), 0.6 + 0.12 * i), 0.045 * i, 0.8, (i - 1.5) * 0.25)
    m.add(glock(midi(r + 24), 0.8, 0.5), 0.17, 0.25, 0.4)
    m.add(glock(midi(r + 19), 0.8, 0.4), 0.2, 0.18, -0.4)
    m.add(shhh(0.35, 0.25, 6000, 0.1), 0.14)
    return m.render(0.8, 0.12, max_dur=0.9)


def success_long():
    """מילה ארוכה (5 אותיות ומעלה): ארפג'יו ארוך, "פששש עם נצנצים" ו"וואו"."""
    m = Mix(1.5)
    for i, iv in enumerate((0, 4, 7, 12, 16)):
        m.add(bubble_note(midi(72 + iv), 0.6 + 0.08 * i), 0.05 * i, 0.75, (i - 2) * 0.2)
    for iv in (12, 16, 19, 24):
        m.add(bubble_note(midi(72 + iv), 0.7), 0.3, 0.5)
    sparkle_pshhh(m, 0.0, 0.6)
    m.add(v_wow(), 0.32, 0.5)
    return m.render(1.0, 0.15, max_dur=1.4)


def error_word():
    """מילה שגויה/כפולה: "בּוֹפּ" כפול יורד, רך ולא מעניש. הלוח מהבהב 260ms."""
    m = Mix(0.5)
    m.add(drop(520, 230, 0.2, 0.09), 0.0, 0.9)
    m.add(drop(330, 150, 0.22, 0.1), 0.12, 0.7)
    return m.render(0.4, 0.07, max_dur=0.45)


def star_gained():
    """כוכב חדש: הכוכב בפאנל מתמלא מיד (350ms) - נצנוץ עולה מעל צליל המילה."""
    m = Mix(1.1)
    for i in range(6):
        m.add(glock(penta_note(5 + i, 72), 0.7, 0.8), 0.04 * i, 0.45, -0.6 + 0.24 * i)
    m.add(bubble_note(n('C5'), 0.7), 0, 0.5)
    m.add(bubble_note(n('G5'), 0.7), 0.2, 0.45)
    m.add(shhh(0.45, 0.25, 6500, 0.18), 0.2)
    return m.render(0.8, 0.13, max_dur=1.0)


def level_complete():
    """סיום שלב: מנגינה קצרה, אקורד, נצנצים ו"ווהוו" - יחד עם הקונפטי (2 שניות)."""
    m = Mix(2.4)
    for f, at, v in (('G4', 0, .7), ('C5', .11, .75), ('E5', .22, .8), ('G5', .33, .85), ('E5', .5, .75), ('G5', .61, .85)):
        m.add(bubble_note(n(f), v), at, 0.8)
    for f in ('C5', 'E5', 'G5', 'C6'):
        m.add(bubble_note(n(f), 0.9), 0.74, 0.55)
    m.add(pad([n('C4'), n('G4'), n('C5'), n('E5')], 1.5, 1.0, 'a', 0.2), 0.7, 0.35)
    m.add(whoosh(0.5, 600, 7000, 1.4, 0.3, 0.8), 0.32)
    m.sparkle(0.76, 0.9, 14, inst=glock, gain=0.2)
    m.add(v_woohoo(), 0.8, 0.5)
    return m.render(1.0, 0.14, max_dur=2.4)


def button_tap():
    """לחיצה על כפתור - הצליל שנשמע הכי הרבה, אז קצרצר ויבש."""
    x = bubble(n('C6'), 0.08, 1.7, 0.018, 0.9) + np.pad(pop(0.3), (0, int(SR * 0.06)))
    return Mix(0.2).add(x, 0).render(0.4, 0.05, max_dur=0.12)


def shuffle():
    """ערבוב האותיות: מפל בועות קטן בגבהים אקראיים, כמו אותיות שמתערבלות."""
    m = Mix(0.7)
    for i, k in enumerate((7, 3, 9, 5, 1, 8, 4)):
        m.add(bubble(penta_note(k, 67), 0.12, 1.6, 0.04, 0.8), 0.05 * i + S.rng.uniform(0, 0.015), 0.7, S.rng.uniform(-0.7, 0.7))
    m.add(whoosh(0.4, 3000, 600, 1.6, 0.25, 0.4), 0.0)
    return m.render(0.6, 0.1, max_dur=0.6)


def firework():
    """זיקוק: מתנגן ברגע ההתפוצצות (ההבזק), אז ה"בום" בהתחלה ואחריו קרקל
    שנמשך כמו הניצוצות (~1.1-1.8 שניות)."""
    m = Mix(1.4)
    boom = thud(95, 32, 0.6, 1.0) + lowpass(noise(0.6), 900) * np.exp(-T(0.6) / 0.12) * 0.6
    m.add(boom, 0.0, 0.9)
    for _ in range(55):
        at = 0.04 + S.rng.uniform(0, 0.9) ** 1.4
        k = int(SR * 0.006)
        c = highpass(noise(k / SR), 2500) * np.exp(-np.arange(k) / (SR * 0.0012))
        m.add(c, at, S.rng.uniform(0.15, 0.4) * (1.3 - at), S.rng.uniform(-0.9, 0.9))
    m.sparkle(0.08, 0.7, 8, inst=glock, gain=0.08, rise=False)
    return m.render(1.4, 0.22, max_dur=1.2)


def reveal_legendary():
    """פרס אגדי: פנפרה, ובדיוק ב-1.4 שניות (כשתותחי הקונפטי השניים יורים)
    אקורד גדול עם מקהלת "אההה", נצנצים ו"וואו"."""
    m = Mix(3.0)
    m.add(thud(110, 35, 0.6, 1.0), 0).add(whoosh(0.5, 4000, 250, 1.4, 0.55, 0.1), 0)
    for f, at, d in (('G4', .05, .12), ('C5', .16, .12), ('E5', .27, .12), ('G5', .38, .35), ('E5', .76, .12), ('G5', .87, .45)):
        m.add(brass(n(f), d + 0.1, 0.9), at, 0.55)
        m.add(bubble_note(n(f), 0.6), at, 0.3)
    for f in ('C4', 'G4', 'C5', 'E5', 'G5'):
        m.add(brass(n(f), 1.5, 0.6), 1.4, 0.22)
    m.add(choir(1.6), 1.3, 0.55)
    m.sparkle(1.4, 1.2, 22, inst=glock, gain=0.2, rise=False)
    m.add(shhh(1.0, 0.2, 7000, 0.45), 1.4)
    m.add(v_wow(), 1.45, 0.4)
    return m.render(2.0, 0.26, max_dur=3.0)


# --- קריסטל --------------------------------------------------------------------

def hint():
    """רמז: "פשששיו" שעולה למעלה + נצנוץ צ'לסטה, בזמן שהאותיות נדלקות על הלוח."""
    m = Mix(1.3)
    m.add(pshhh_up(0.6), 0, 0.6)
    m.sparkle(0.12, 0.45, 10, lo=79, hi=100, inst=crystal_hi, gain=0.3)
    m.add(crystal_hi(n('E7'), 1.0, 0.7), 0.58, 0.35)
    return m.render(2.0, 0.24, max_dur=1.3)


def timer_warning():
    """שניות אחרונות: מתנגן פעם בשנייה, אז קצר וברור."""
    return Mix(0.3).add(lowpass(kalimba(n('A5'), 0.25, 1.0), 4000), 0).render(0.4, 0.06, max_dur=0.25)


def daily_reward():
    m = Mix(1.6)
    for i, f in enumerate(('C5', 'E5', 'G5', 'C6')):
        m.add(crystal_note(n(f), 0.75), 0.09 * i, 0.8)
    for f in ('C5', 'G5', 'C6', 'E6'):
        m.add(crystal_note(n(f), 0.8), 0.4, 0.5)
    for j in range(6):
        coins_crystal(m, 0.42 + j * 0.09 + S.rng.uniform(0, 0.03), 0.45 - j * 0.04)
    m.add(pad([n('C4'), n('G4'), n('E5')], 1.0, 1.0, 'a'), 0.38, 0.3)
    return m.render(2.0, 0.28, max_dur=1.6)


def reveal_common():
    """פרס רגיל: כפתור האיסוף נדלק אחרי 650ms."""
    m = Mix(0.8)
    m.add(pop(0.7), 0).add(thud(200, 90, 0.12, 0.6), 0)
    m.add(crystal_note(n('G5'), 0.8), 0.04, 0.7).add(crystal_note(n('C6'), 0.9), 0.14, 0.75)
    m.add(shhh(0.3, 0.2, 6000, 0.1), 0.03)
    return m.render(1.6, 0.22, max_dur=0.8)


def reveal_rare():
    m = Mix(1.3)
    m.add(thud(180, 60, 0.25, 0.9), 0).add(pop(0.6), 0)
    for i, f in enumerate(('C5', 'E5', 'G5', 'C6')):
        m.add(crystal_note(n(f), 0.8), 0.05 + 0.08 * i, 0.7)
    for f in ('C5', 'G5', 'E6'):
        m.add(crystal_note(n(f), 0.8), 0.38, 0.45)
    m.sparkle(0.36, 0.5, 9, inst=crystal_hi, gain=0.2)
    return m.render(2.0, 0.26, max_dur=1.3)


def reveal_epic():
    """פרס אפי: גשם קונפטי מתחיל ב-0.5 שניות - שם נוחת האקורד."""
    m = Mix(1.9)
    m.add(thud(130, 40, 0.45, 1.0), 0).add(whoosh(0.4, 3000, 300, 1.5, 0.5, 0.1), 0)
    for i, f in enumerate(('A4', 'C#5', 'E5', 'A5', 'C#6', 'E6')):
        m.add(crystal_note(n(f), 0.8), 0.05 + 0.065 * i, 0.7, (i - 2.5) * 0.2)
    m.add(pad([n('A3'), n('E4'), n('A4'), n('C#5'), n('E5')], 1.3, 1.0, 'a', 0.1), 0.45, 0.4)
    for f in ('A5', 'C#6', 'E6'):
        m.add(crystal_note(n(f), 0.9), 0.47, 0.45)
    m.sparkle(0.47, 0.9, 16, inst=crystal_hi, gain=0.2, rise=False)
    return m.render(2.2, 0.28, max_dur=1.9)


def collect():
    """איסוף פרס: המסך נסגר 180ms אחרי הלחיצה, הצליל ממשיך עוד רגע אחריו."""
    m = Mix(0.7)
    for j in range(4):
        coins_crystal(m, j * 0.07, 0.6)
    for f in ('G5', 'C6', 'E6'):
        m.add(crystal_note(n(f), 0.8), 0.28, 0.5)
    m.add(shhh(0.4, 0.2, 6000, 0.15), 0.28)
    return m.render(2.0, 0.24, max_dur=0.7)


# --- עץ ------------------------------------------------------------------------

def coin():
    m = Mix(0.6)
    coins_wood(m)
    return m.render(0.8, 0.13, max_dur=0.6)


def charge(k):
    """לחיצה על תיבה סגורה ([k] 0..3, עולה עם כל לחיצה). לחיצות מגיעות כל
    230ms לפחות, אז הצליל קצר כדי שלא יתערבב עם הבא."""
    m = Mix(0.5)
    m.add(thud(170, 60, 0.2, 1.0), 0, 0.8)
    f = n(('C5', 'E5', 'G5', 'C6')[k])
    m.add(wood_note(f, 0.8), 0.01, 0.55)
    m.add(wood_hi(f * 2, 0.4, 0.5), 0.02, 0.15 + 0.05 * k)
    m.add(shhh(0.2 + 0.05 * k, 0.12 + 0.05 * k, 6000, 0.08), 0.0)
    return m.render(0.6, 0.12, max_dur=0.45)


def rarity_up():
    """התיבה עלתה דרגה: "ווש" עולה שנוחת באקורד בסוף המורפינג (420ms)."""
    m = Mix(1.0)
    m.add(whoosh(0.4, 350, 6500, 1.6, 0.7, 0.85), 0)
    for f in ('E5', 'G5', 'C6', 'E6'):
        m.add(wood_note(n(f), 0.8), 0.35, 0.45)
    m.sparkle(0.35, 0.4, 8, inst=wood_hi, gain=0.2)
    return m.render(1.1, 0.19, max_dur=0.95)


def wheel_tick():
    """"קליק" של המחוג בגלגל המזל - יכול להגיע כמה פעמים בשנייה."""
    k = int(SR * 0.008)
    c = S.bandpass(noise(k / SR), 1800, 5000) * np.exp(-np.arange(k) / (SR * 0.0015))
    tone = modal(1700, 0.04, [(1, 1, 0.008)], 0.4, dec_scale=False)
    x = np.zeros(int(SR * 0.05))
    x[:k] += c
    x[: len(tone)] += tone
    return Mix(0.1).add(x, 0).render(0.3, 0.03, max_dur=0.05)


RECIPES = {
    **{f'tile_{k}.wav': (lambda k=k: tile(k)) for k in range(12)},
    **{f'success_{c}.wav': (lambda c=c: success(c)) for c in range(5)},
    'success_long.wav': success_long,
    'error_word.wav': error_word,
    'star_gained.wav': star_gained,
    'level_complete.wav': level_complete,
    'button_tap.wav': button_tap,
    'shuffle.wav': shuffle,
    'firework.wav': firework,
    'reveal_legendary.wav': reveal_legendary,
    'hint.wav': hint,
    'timer_warning.wav': timer_warning,
    'daily_reward.wav': daily_reward,
    'reveal_common.wav': reveal_common,
    'reveal_rare.wav': reveal_rare,
    'reveal_epic.wav': reveal_epic,
    'collect.wav': collect,
    'coin.wav': coin,
    **{f'charge_{k}.wav': (lambda k=k: charge(k)) for k in range(4)},
    'rarity_up.wav': rarity_up,
    'wheel_tick.wav': wheel_tick,
}


def main():
    only = {a if a.endswith('.wav') else a + '.wav' for a in sys.argv[1:]}
    for filename, builder in RECIPES.items():
        if only and filename not in only:
            continue
        # זרע קבוע לכל קובץ - אותו פלט בכל הרצה, גם כשמייצרים רק חלק מהקבצים.
        S.rng = np.random.default_rng(zlib.crc32(filename.encode()))
        stereo = builder()
        save(os.path.join(OUT_DIR, filename), stereo)
        print(f'נכתב: {filename} ({stereo.shape[1] / SR:.2f}s)')


if __name__ == '__main__':
    main()
