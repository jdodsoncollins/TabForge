#!/usr/bin/env python3
"""Build local canonical copy and report field limits without remote writes."""

import json
from pathlib import Path
import re
import argparse

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--staging-dir", type=Path, help="Also write canonical metadata localization files here.")
args = parser.parse_args()


def read_text(name):
    return (ROOT / name).read_text(encoding="utf-8").rstrip("\n")


app_info = json.loads(read_text("app-info-en-US.json"))
version = {
    "description": read_text("description-en-US.txt"),
    "keywords": "script,shell,indent,snippets,braces,brackets,arrows,escape,remote,desktop,syntax,editor,punctuation",
    "marketingUrl": "https://github.com/jdodsoncollins/TabForge",
    "supportUrl": "https://github.com/jdodsoncollins/TabForge/blob/main/docs/SUPPORT.md",
    "promotionalText": read_text("promotional-text-en-US.txt"),
}
(ROOT / "version-en-US.json").write_text(
    json.dumps(version, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
)

limits = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "description": 4000,
    "promotionalText": 170,
    "reviewNotes": 4000,
}
fields = {}
for name, maximum in limits.items():
    value = read_text("review-notes-en-US.txt") if name == "reviewNotes" else app_info.get(name, version.get(name))
    byte_count = len(value.encode("utf-8"))
    fields[name] = {
        "characters": len(value),
        "utf8Bytes": byte_count,
        "limit": maximum,
        "limitUnit": "UTF-8 bytes" if name == "keywords" else "characters",
        "valid": (byte_count if name == "keywords" else len(value)) <= maximum,
    }

indexed_words = set(re.findall(r"[a-z]+", (app_info["name"] + " " + app_info["subtitle"]).lower()))
keywords = version["keywords"].split(",")
overlap = sorted(indexed_words.intersection(keywords))
duplicates = sorted({word for word in keywords if keywords.count(word) > 1})
all_keywords_described = {
    word: word in version["description"].lower() for word in keywords
}
checks = {
    "withinLimits": all(field["valid"] for field in fields.values()),
    "keywordIndexedFieldOverlap": overlap,
    "duplicateKeywords": duplicates,
    "keywordFormatValid": not re.search(r",\s|;|\|", version["keywords"]),
    "keywordTermsOverTwoCharacters": all(len(word) > 2 for word in keywords),
    "keywordCoverageInDescription": all_keywords_described,
    "keywordUtilizationAtLeast90Percent": len(version["keywords"].encode("utf-8")) >= 90,
    "subtitleAtLeast20Characters": len(app_info["subtitle"]) >= 20,
}
report = {
    "locale": "en-US",
    "version": "1.0",
    "scope": "offline content validation; remote state is not queried",
    "fields": fields,
    "checks": checks,
    "whatsNew": "Intentionally omitted: unavailable for an initial App Store version.",
    "supportUrl": version["supportUrl"],
    "supportUrlStatus": "Confirm the public page and approved support contact before submission.",
    "keywordIntelligence": {
        "astroAvailable": False,
        "measuredPopularity": False,
        "measuredDifficulty": False,
        "measuredRankings": False,
        "basis": "Feature relevance and comparable public listings only.",
    },
}
(ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
if args.staging_dir:
    app_info_file = args.staging_dir / "app-info" / "en-US.json"
    version_file = args.staging_dir / "version" / "1.0" / "en-US.json"
    for destination, contents in [(app_info_file, app_info), (version_file, version)]:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(contents, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
assert checks["withinLimits"]
assert checks["keywordFormatValid"]
assert checks["keywordTermsOverTwoCharacters"]
assert not overlap
assert not duplicates
