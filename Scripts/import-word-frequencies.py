#!/usr/bin/env python3
"""Regenerate bundled English word frequencies from a pinned SymSpell list.

Development tool only. The keyboard never downloads or updates frequencies.
Each bundled ESDB word that SymSpell also lists receives a Zipf value: the
base-10 logarithm of its occurrences per billion words, multiplied by 10 and
rounded. Words missing from SymSpell keep a low default chosen at run time.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


WHEEL_URL = (
    "https://files.pythonhosted.org/packages/54/07/"
    "c903a3a42222a4bb6aedf620a63554f577f3020b4f56f339889718126c1c/"
    "symspellpy-6.9.0-py3-none-any.whl"
)
WHEEL_SHA256 = "b6dba96275fdbedc240491854160bbe596dda930f2d58567ad55faf82a4e4b43"
DICTIONARY_MEMBER = "symspellpy/frequency_dictionary_en_82_765.txt"
DICTIONARY_SHA256 = "68e9dc81c7e73bd7310b57e516ecaea0d8b6387ff71344a57c04174650a407a7"
EXPECTED_ENTRY_COUNT = 35_129
REQUIRED_WORDS = {"the", "their", "there", "receive", "letter", "better", "print", "return"}
HEADER = (
    "# English word frequencies: SymSpell frequency_dictionary_en_82_765 (MIT),\n"
    "# derived from Google Books Ngram data (CC BY 3.0) and SCOWL.\n"
    "# Values are Zipf x 10. Source, filtering, and notices: docs/word-frequency.md\n"
)


def read_dictionary(wheel: bytes) -> dict[str, int]:
    with zipfile.ZipFile(io.BytesIO(wheel)) as archive:
        data = archive.read(DICTIONARY_MEMBER)
    if hashlib.sha256(data).hexdigest() != DICTIONARY_SHA256:
        raise ValueError("SymSpell frequency dictionary checksum does not match the pinned file")
    counts: dict[str, int] = {}
    for line in data.decode("utf-8").splitlines():
        word, count = line.split()
        counts[word] = int(count)
    return counts


def generate(counts: dict[str, int], lexicon: Path) -> bytes:
    total = sum(counts.values())
    words = [
        line.strip() for line in lexicon.read_text(encoding="ascii").splitlines()
        if line.strip() and not line.startswith("#")
    ]
    rows = []
    for word in words:
        count = counts.get(word)
        if count is None:
            continue
        zipf = math.log10(count / total * 1e9)
        rows.append(f"{word}\t{round(zipf * 10)}")
    found = {row.split("\t")[0] for row in rows}
    if len(rows) != EXPECTED_ENTRY_COUNT:
        raise ValueError(f"Unexpected entry count: {len(rows)}")
    if not REQUIRED_WORDS.issubset(found):
        raise ValueError("Required regression vocabulary is missing")
    return (HEADER + "\n".join(rows) + "\n").encode("ascii")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--wheel", type=Path,
        help="Use an already downloaded symspellpy 6.9.0 wheel; its checksum is still verified.",
    )
    parser.add_argument(
        "--check", action="store_true",
        help="Verify that the checked-in frequencies exactly match regeneration.",
    )
    args = parser.parse_args()
    lexicon = root / "Sources/KeyboardCore/Resources/swipe-english.txt"
    output = root / "Sources/KeyboardCore/Resources/english-frequency.txt"
    with tempfile.TemporaryDirectory(prefix="tabforge-frequency-") as temporary:
        wheel = Path(temporary) / "symspellpy.whl"
        if args.wheel:
            shutil.copyfile(args.wheel, wheel)
        else:
            subprocess.run(
                ["curl", "--fail", "--silent", "--show-error", "--location",
                 "--proto", "=https", "--tlsv1.2", WHEEL_URL, "--output", str(wheel)],
                check=True,
            )
        data = wheel.read_bytes()
    if hashlib.sha256(data).hexdigest() != WHEEL_SHA256:
        raise ValueError("symspellpy wheel checksum does not match the pinned release")
    content = generate(read_dictionary(data), lexicon)
    if args.check:
        if output.read_bytes() != content:
            raise ValueError("Bundled word frequencies differ from the pinned generation")
    else:
        output.write_bytes(content)
    print(
        f"{'Verified' if args.check else 'Generated'} {EXPECTED_ENTRY_COUNT:,} entries; "
        f"{len(content):,} bytes; SHA-256 {hashlib.sha256(content).hexdigest()}"
    )


if __name__ == "__main__":
    main()
