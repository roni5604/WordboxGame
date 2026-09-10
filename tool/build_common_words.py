#!/usr/bin/env python3
"""
בונה את assets/dictionaries/common_words.json - תת-קבוצה "מוכרת/נוחה" של
מילון המשחק, המשמשת את בונה הלוחות (lib/game_engine/level_board_builder.dart)
לעגן שלבים מוקדמים סביב מילים ידועות, ולדרג את איכות הלוחות (יחס מילים
מוכרות מתוך כל המילים שנמצאות בלוח).

מקור: tool/seed_words_raw.txt - הרשימה המאוצרת (curated) המקורית של
הפרויקט (משפחה, בעלי חיים, מקצועות, בית, אוכל וכו') - כל מילה בה נבחרה
במיוחד כדי להיות בסיסית ומוכרת, לפני שהמילון הורחב ל-65K מילים (כולל
הרבה נטיות/מילים נדירות יותר) בעזרת hebrew-words-db.

הרצה:
    python3 tool/build_common_words.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_WORDS_PATH = ROOT / "tool" / "seed_words_raw.txt"
OUT_PATH = ROOT / "assets" / "dictionaries" / "common_words.json"

SOFIT_TO_BASE = {"ך": "כ", "ם": "מ", "ן": "נ", "ף": "פ", "ץ": "צ"}
HEBREW_LETTERS = set("אבגדהוזחטיכלמנסעפצקרשתךםןףץ")


def normalize(word: str) -> str:
    return "".join(SOFIT_TO_BASE.get(ch, ch) for ch in word)


def is_valid_hebrew_word(word: str) -> bool:
    if not word or any(sep in word for sep in (" ", "'", '"', "-")):
        return False
    return all(ch in HEBREW_LETTERS for ch in word)


def read_raw_words(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


def main() -> None:
    raw_words = read_raw_words(RAW_WORDS_PATH)

    seen: set[str] = set()
    words: list[str] = []
    for word in raw_words:
        if not is_valid_hebrew_word(word):
            continue
        normalized = normalize(word)
        if normalized in seen:
            continue
        seen.add(normalized)
        words.append(normalized)

    words.sort()

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(words, ensure_ascii=False), encoding="utf-8")

    print(f"✅ {len(words)} מילים \"נוחות/מוכרות\" נכתבו ל-{OUT_PATH}")


if __name__ == "__main__":
    main()
