#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Rewrites the bundle ID for an App Store build

The App Store workflow runs this on the checked out upstream commit, so the
repository itself keeps the upstream bundle ID and there is no long-lived
App Store branch to keep in sync. The generated App Intents indexes are
rewritten too, because their keys are bundle identifiers.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BUNDLE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z0-9][A-Za-z0-9.-]*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_id", help="new bundle ID, for example com.example.app")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="repository root (defaults to the script's repository)",
    )
    return parser.parse_args()


def read_old_bundle_id(root: Path) -> str:
    text = (root / "xtool.yml").read_text(encoding="utf-8")
    match = re.search(r"(?m)^bundleID:\s*(\S+)\s*$", text)
    if not match:
        sys.exit("xtool.yml has no bundleID line")
    return match.group(1)


def replace_in(path: Path, old: str, new: str) -> int:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        return 0
    path.write_text(text.replace(old, new), encoding="utf-8")
    return text.count(old)


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    new = args.bundle_id.strip()
    if not BUNDLE_ID_RE.match(new):
        sys.exit(f"invalid bundle ID: {new!r}")

    old = read_old_bundle_id(root)
    if old == new:
        print(f"bundle ID is already {new}")
        return

    xtool = root / "xtool.yml"
    text = xtool.read_text(encoding="utf-8")
    text, count = re.subn(
        r"(?m)^bundleID:\s*\S+\s*$", f"bundleID: {new}", text, count=1
    )
    if count != 1:
        sys.exit("could not rewrite the bundleID line in xtool.yml")
    xtool.write_text(text, encoding="utf-8")

    generator = root / "Tools/appintents-metadata.py"
    if replace_in(generator, f'APP_ID = "{old}"', f'APP_ID = "{new}"') != 1:
        sys.exit(f"could not rewrite APP_ID in {generator}")

    info = root / "Support/App-Info.plist"
    if replace_in(info, f"<string>{old}</string>", f"<string>{new}</string>") != 1:
        sys.exit(f"could not rewrite CFBundleURLName in {info}")

    changed = 0
    for path in sorted((root / "Resources/AppIntents").rglob("*")):
        if not path.is_file():
            continue
        changed += replace_in(path, old, new)

    if changed == 0:
        sys.exit("no App Intents index mentioned the old bundle ID")

    leftovers = []
    for path in [
        xtool,
        generator,
        info,
        *(p for p in (root / "Resources/AppIntents").rglob("*") if p.is_file()),
    ]:
        if old in path.read_text(encoding="utf-8"):
            leftovers.append(str(path.relative_to(root)))
    if leftovers:
        sys.exit("old bundle ID still present in: " + ", ".join(leftovers))

    print(f"Rewrote {old} to {new}")
    print(f"  xtool.yml, Tools/appintents-metadata.py, Support/App-Info.plist")
    print(f"  {changed} App Intents index entries")


if __name__ == "__main__":
    main()
