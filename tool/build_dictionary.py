#!/usr/bin/env python3
"""
בונה את קבצי ה-assets (מילון + תדירות אותיות) מתוך tool/seed_words_raw.txt.

הרצה:
    python3 tool/build_dictionary.py

ראו docs/DICTIONARY_LICENSING.md להסבר על מקור רשימת המילים ואיך להרחיב
אותה בבטחה מבחינת רישוי.
"""

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_WORDS_PATH = ROOT / "tool" / "seed_words_raw.txt"
DICTIONARY_OUT_PATH = ROOT / "assets" / "dictionaries" / "he_words.json"
FREQUENCY_OUT_PATH = ROOT / "assets" / "config" / "letter_frequency.json"

# אותיות סופיות -> צורתן הרגילה. הלוח מציג תמיד את הצורה הרגילה כדי
# למנוע בלבול חזותי (ראו lib/game_engine/dictionary/hebrew_trie.dart).
SOFIT_TO_BASE = {"ך": "כ", "ם": "מ", "ן": "נ", "ף": "פ", "ץ": "צ"}
HEBREW_LETTERS = set("אבגדהוזחטיכלמנסעפצקרשתךםןףץ")


def normalize(word: str) -> str:
    return "".join(SOFIT_TO_BASE.get(ch, ch) for ch in word)


def is_valid_hebrew_word(word: str) -> bool:
    if not word or any(sep in word for sep in (" ", "'", '"', "-")):
        return False
    return all(ch in HEBREW_LETTERS for ch in word)


def main() -> None:
    raw_words = [
        line.strip()
        for line in RAW_WORDS_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]

    seen_normalized = set()
    final_words = []
    for word in raw_words:
        if not is_valid_hebrew_word(word):
            continue
        if not (2 <= len(word) <= 9):
            continue
        normalized = normalize(word)
        if normalized in seen_normalized:
            continue
        seen_normalized.add(normalized)
        final_words.append(normalized)

    final_words.sort()

    DICTIONARY_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    DICTIONARY_OUT_PATH.write_text(
        json.dumps(final_words, ensure_ascii=False), encoding="utf-8"
    )

    letter_counts = Counter(ch for word in final_words for ch in word)
    total = sum(letter_counts.values())
    frequency = {
        letter: round(count / total, 5)
        for letter, count in letter_counts.most_common()
    }

    FREQUENCY_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    FREQUENCY_OUT_PATH.write_text(
        json.dumps(frequency, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"✅ {len(final_words)} מילים ייחודיות נכתבו ל-{DICTIONARY_OUT_PATH}")
    print(f"✅ תדירות {len(frequency)} אותיות נכתבה ל-{FREQUENCY_OUT_PATH}")


if __name__ == "__main__":
    main()
