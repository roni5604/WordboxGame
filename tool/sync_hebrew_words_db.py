#!/usr/bin/env python3
"""
מסנכרן את tool/vendor/hebrew_words_db_words.txt מתוך המאגר הפתוח
https://github.com/roni5604/hebrew-words-db (רישיון CC0 - נחלת הכלל).

שימוש:
    # מסנכרן מ-checkout מקומי (לפיתוח, כשהריפו קיים ליד WordboxGame):
    python3 tool/sync_hebrew_words_db.py --local ../hebrew-words-db

    # מסנכרן מ-GitHub (אחרי שהריפו פורסם):
    python3 tool/sync_hebrew_words_db.py --url \
        https://raw.githubusercontent.com/roni5604/hebrew-words-db/main/data/words.txt

לאחר הסנכרון, הריצו:
    python3 tool/build_dictionary.py
    flutter test
"""

from __future__ import annotations

import argparse
import datetime
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENDOR_PATH = ROOT / "tool" / "vendor" / "hebrew_words_db_words.txt"
DEFAULT_URL = (
    "https://raw.githubusercontent.com/roni5604/hebrew-words-db/main/"
    "data/words.txt"
)

HEADER = """# קובץ מנוהל אוטומטית - אל תערכו אותו ידנית!
#
# זהו עותק מוקפא (vendored snapshot) של data/words.txt מתוך המאגר הפתוח
# https://github.com/roni5604/hebrew-words-db (רישיון CC0 - נחלת הכלל,
# ללא צורך בייחוס). מקור: {source}
# סונכרן בתאריך: {date}
#
# להוספת מילים חדשות: הוסיפו אותן ל-hebrew-words-db (ראו CONTRIBUTING.md
# שם), ואז הריצו את הסקריפט הזה מחדש. תוספות ספציפיות רק למשחק הזה
# (שלא מתאימות למאגר הכללי) - הוסיפו ל-tool/seed_words_raw.txt במקום.
"""


def fetch_from_url(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as response:  # noqa: S310
        return response.read().decode("utf-8")


def fetch_from_local(local_repo: Path) -> str:
    words_file = local_repo / "data" / "words.txt"
    if not words_file.exists():
        raise SystemExit(f"❌ לא נמצא {words_file} - הריצו שם python3 scripts/build.py קודם")
    return words_file.read_text(encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--local",
        type=Path,
        default=None,
        help="נתיב לתיקיית checkout מקומית של hebrew-words-db",
    )
    parser.add_argument(
        "--url",
        type=str,
        default=None,
        help=f"URL ל-words.txt גולמי (ברירת מחדל: {DEFAULT_URL})",
    )
    args = parser.parse_args()

    if args.local:
        content = fetch_from_local(args.local)
        source = str(args.local / "data" / "words.txt")
    else:
        url = args.url or DEFAULT_URL
        content = fetch_from_url(url)
        source = url

    VENDOR_PATH.parent.mkdir(parents=True, exist_ok=True)
    header = HEADER.format(
        source=source,
        date=datetime.date.today().isoformat(),
    )
    VENDOR_PATH.write_text(header + "\n" + content, encoding="utf-8")

    word_count = sum(1 for line in content.splitlines() if line.strip())
    print(f"✅ {word_count} מילים סונכרנו מ-{source} אל {VENDOR_PATH}")
    print("➡️  הריצו כעת: python3 tool/build_dictionary.py")


if __name__ == "__main__":
    main()
