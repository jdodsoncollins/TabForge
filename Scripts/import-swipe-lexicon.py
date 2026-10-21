#!/usr/bin/env python3
"""Regenerate the bundled English swipe lexicon from pinned ESDB sources.

Development tool only. The keyboard never downloads or builds a dictionary.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path, PurePosixPath
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile


REVISION = "1e5b7d3a72f47a71da5d28686c1dd4b397178485"
SOURCE_URL = f"https://codeload.github.com/en-wl/wordlist/tar.gz/{REVISION}"
ARCHIVE_SHA256 = "aaecc7a54af576057e30b22a19b78bad011f2181f7e368ff3b736fbecbdfd4d0"
EXPECTED_WORD_COUNT = 38_604
REQUIRED_WORDS = {"testing", "programming", "developer", "morning", "repeat"}
HEADER = (
    "# Copyright 2000-2026 by Kevin Atkinson\n"
    "# English Speller Database (ESDB), American English, size 35.\n"
    "# Source, filtering, and permission notice: docs/swipe-lexicon.md\n"
)
QUERY = """
    SELECT word, MIN(size)
    FROM scowl_v0
    WHERE size <= 35
      AND spelling IN ('_', 'A')
      AND region IN ('', 'US')
      AND variant_level <= 1
      AND pos_class IN ('', 'number', 'ordinal')
      AND base_pos != 'abbr'
      AND pos_category = ''
      AND category = ''
      AND word NOT IN (
          SELECT word FROM words JOIN groups USING (group_id)
          WHERE usage_note LIKE 'offensive-%'
             OR usage_note LIKE 'vulgar-%'
      )
    GROUP BY word
"""


def extract_source(archive: Path, destination: Path) -> Path:
    """Extract only ordinary files/directories below the expected root."""
    expected_root = f"wordlist-{REVISION}"
    with tarfile.open(archive, "r:gz") as source:
        ordinary_members = []
        for member in source.getmembers():
            # PostgreSQL-only convenience links are not used by SQLite generation.
            if member.issym() and member.name in {
                f"{expected_root}/postgresql/scowl.sql",
                f"{expected_root}/postgresql/views.sql",
            }:
                continue
            parts = PurePosixPath(member.name).parts
            if (
                not parts
                or parts[0] != expected_root
                or PurePosixPath(member.name).is_absolute()
                or ".." in parts
                or not (member.isfile() or member.isdir())
            ):
                raise ValueError(f"Unexpected source archive member: {member.name!r}")
            ordinary_members.append(member)
        source.extractall(destination, members=ordinary_members)
    return destination / expected_root


def generate(source: Path) -> bytes:
    result = subprocess.run(
        [sys.executable, "combine.py", "create-db", "scowl.db"],
        cwd=source,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"ESDB generation failed:\n{result.stdout[-8000:]}")
    with sqlite3.connect(source / "scowl.db") as database:
        words = sorted(
            word
            for word, _ in database.execute(QUERY)
            if re.fullmatch(r"[a-z]{2,24}", word)
        )
    if len(words) != EXPECTED_WORD_COUNT or len(set(words)) != len(words):
        raise ValueError(f"Unexpected word count: {len(words)}")
    if not REQUIRED_WORDS.issubset(words):
        raise ValueError("Required regression vocabulary is missing")
    return (HEADER + "\n".join(words) + "\n").encode("ascii")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--archive", type=Path,
        help="Use an already downloaded source tarball; its checksum is still verified.",
    )
    parser.add_argument(
        "--check", action="store_true",
        help="Verify that the checked-in lexicon exactly matches regeneration.",
    )
    args = parser.parse_args()
    output = root / "Sources/KeyboardCore/Resources/swipe-english.txt"
    with tempfile.TemporaryDirectory(prefix="tabforge-esdb-") as temporary:
        temporary_path = Path(temporary)
        archive = temporary_path / "source.tar.gz"
        if args.archive:
            shutil.copyfile(args.archive, archive)
        else:
            subprocess.run(
                ["curl", "--fail", "--silent", "--show-error", "--location",
                 "--proto", "=https", "--tlsv1.2", SOURCE_URL, "--output", str(archive)],
                check=True,
            )
        if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
            raise ValueError("ESDB source archive checksum does not match the pinned revision")
        content = generate(extract_source(archive, temporary_path))
    if args.check:
        if output.read_bytes() != content:
            raise ValueError("Bundled swipe lexicon differs from the pinned generation")
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(content)
    print(
        f"{'Verified' if args.check else 'Generated'} {EXPECTED_WORD_COUNT:,} words; "
        f"{len(content):,} bytes; SHA-256 {hashlib.sha256(content).hexdigest()}"
    )


if __name__ == "__main__":
    main()
