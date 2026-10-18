#!/usr/bin/env python3
"""Validate local build IDs and write an ignored Xcode configuration.

The .env file is parsed as a small data format, never sourced or evaluated.
No credentials, provisioning profiles, or account access are required.
"""

import argparse
import os
from pathlib import Path
import re
import sys
import tempfile


KEYS = {
    "TABFORGE_DEVELOPMENT_TEAM",
    "TABFORGE_BUNDLE_IDENTIFIER",
}
IDENTIFIER = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+\Z")
TEAM = re.compile(r"[A-Z0-9]{10}\Z")


class ConfigurationError(ValueError):
    """A local configuration is missing or unsafe to use."""


def read_configuration(path: Path) -> dict[str, str]:
    try:
        content = path.read_text(encoding="utf-8")
    except OSError as error:
        raise ConfigurationError("Cannot read the env file. Copy .env.example to .env first.") from error
    values = {}
    for number, raw_line in enumerate(content.splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if not separator or key not in KEYS:
            raise ConfigurationError(f"Line {number}: use one of the two documented KEY=value settings.")
        if key in values:
            raise ConfigurationError(f"Line {number}: duplicate setting.")
        # Quotes are optional conveniences only; no escapes or interpolation.
        if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
            value = value[1:-1]
        values[key] = value

    if set(values) != KEYS:
        raise ConfigurationError("The env file must contain both settings from .env.example.")
    team = values["TABFORGE_DEVELOPMENT_TEAM"]
    bundle = values["TABFORGE_BUNDLE_IDENTIFIER"]
    if team and not TEAM.fullmatch(team):
        raise ConfigurationError("The development team must be empty or a 10-character uppercase Apple team ID.")
    if not IDENTIFIER.fullmatch(bundle) or bundle.startswith("group."):
        raise ConfigurationError("The app bundle identifier must use reverse-DNS letters, digits, periods and hyphens.")
    return values


def render_configuration(values: dict[str, str]) -> str:
    return (
        "// Local build configuration. Generated from .env; do not commit.\n"
        f"TABFORGE_BUNDLE_IDENTIFIER = {values['TABFORGE_BUNDLE_IDENTIFIER']}\n"
        f"DEVELOPMENT_TEAM = {values['TABFORGE_DEVELOPMENT_TEAM']}\n"
    )


def write_configuration(path: Path, content: str) -> None:
    if path.is_symlink():
        raise ConfigurationError("Refusing to replace a symlink with local configuration.")
    if not path.parent.is_dir():
        raise ConfigurationError("The output directory does not exist.")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            os.chmod(temporary, 0o600)
            stream.write(content)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main() -> int:
    repository = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env", type=Path, default=repository / ".env", help="Input env file (default: repository .env)")
    parser.add_argument("--output", type=Path, default=repository / "Configuration/Signing.local.xcconfig", help="Ignored local xcconfig output")
    parser.add_argument("--check", action="store_true", help="Validate without writing any file")
    arguments = parser.parse_args()
    try:
        values = read_configuration(arguments.env)
        if not arguments.check:
            # Custom output is for isolated verification, but keep the local
            # suffix so an override is not mistaken for a public config file.
            if not arguments.output.name.endswith(".local.xcconfig"):
                raise ConfigurationError("The output filename must end with .local.xcconfig.")
            write_configuration(arguments.output, render_configuration(values))
    except (ConfigurationError, UnicodeError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        return 1
    print("Build configuration validated." if arguments.check else "Local build configuration written. The checked-in project remains unchanged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
