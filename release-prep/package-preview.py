#!/usr/bin/env python3
"""Package only the reviewed public copy and artwork, excluding release records."""
import argparse
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--artifacts", type=Path, default=Path("artifacts/app-store-release-2026-10-18"))
parser.add_argument("--build-number", required=True, help="The validated build selected in the draft")
args = parser.parse_args()
root = args.artifacts.resolve()
destination = root / "review-package"
if destination.exists():
    shutil.rmtree(destination)
destination.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root / "screenshots/asset-manifest.json").read_text())
families = manifest["families"]
selection = manifest["duoUploadSelection"]["selection"]
assert len(selection) <= 10, "The shared Duo slot allows at most ten images"


def copy(source: Path, relative: str | Path) -> None:
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


copy(root / "index.html", "index.html")
copy(root / "creative/header-3840x1646.png", "creative/header-3840x1646.png")
for family in families:
    for asset in family["assets"]:
        source = (root / asset["file"]).resolve()
        source.relative_to(root / "screenshots/en-US")
        assert hashlib.sha256(source.read_bytes()).hexdigest() == asset["sha256"], source
        copy(source, source.relative_to(root))
copy(root / "screenshots/asset-manifest.json", "screenshots/asset-manifest.json")
for name in ("contact-sheet.png", "iphone-contact-sheet.png"):
    source = root / "previews" / name
    if source.exists():
        copy(source, Path("previews") / name)
for name in ("built-with-phone.png", "settings-footer-phone.png", "other-apps-phone.png", "other-apps-ipad.png"):
    source = root / "previews" / name
    if source.exists():
        copy(source, Path("companion") / name)
for name in ("app-info-en-US.json", "version-en-US.json", "description-en-US.txt",
             "promotional-text-en-US.txt", "review-notes-en-US.txt", "validation.json"):
    copy(Path("release-prep/copy") / name, Path("listing") / name)
copy(Path("release-prep/design/header-prompt.md"), "header-prompt.md")
copy(Path("release-prep/design/duo-selection.json"), "duo-upload-selection.json")
copy(Path("docs/design-assets.md"), "design-assets.md")
for source in sorted(Path("docs/images").glob("keyboard-*.webp")):
    copy(source, Path("images") / source.name)

count = sum(len(family["assets"]) for family in families)
rows = "\n".join(f"| {family['label']} | {len(family['assets'])} | {family['slot']} |" for family in families)
(destination / "README.md").write_text(f"""# TabForge App Store preview

Open `index.html` to compare the full-size images. The listing text is under `listing/` and the separate product-page header is under `creative/`.

`companion/` contains native previews of the new Built with, creator and Other Apps sections. These are verification images, separate from the App Store screenshot sets.

This package contains **{count} listing images** across {len(families)} layout sets, plus the header and five README device figures. The Duo's closed, open and tabletop layouts share a single App Store slot. `duo-upload-selection.json` records their combined {len(selection)}-image upload order; the gallery groups them by pose.

| Layout | Images | App Store slot |
| --- | ---: | --- |
{rows}

Every keyboard and settings panel is a real native capture. Device frames come from Apple's installed Simulator resources or real Device Hub pose captures. Folded geometry is shown through actual Device Hub renders. Some iPhone and iPad captures are reused proportionally at another output size; that does not establish a separate device test. The asset manifest records the source family and final image hashes. The header is brand artwork; its prompt is included separately.

The App Store version is a draft and has not been submitted for review. Build {args.build_number} passed Apple's binary validation and was selected for that draft. Manual release is configured. Pricing is Free, private reviewer contact is saved, and public support email and the live privacy policy are in place. Publication of the saved privacy declaration remains pending explicit owner approval. Account requirements must also be checked before a future submission. Simulator captures do not certify physical touch, speech availability, memory-pressure survival, or every third-party host.

This preview excludes private account records, private contact details, credentials, signing resources, device inventories, logs, original captures, archives and IPA files. The approved public support email remains in the listing and policy materials.
""")

archive = root / "TabForge-App-Store-Preview.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
    for source in sorted(destination.rglob("*")):
        if source.is_file():
            bundle.write(source, source.relative_to(destination))
print(json.dumps({"directory": str(destination), "archive": str(archive),
                  "images": count, "families": len(families)}, indent=2))
