#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Checks that every language has the same string keys and format arguments

Also verifies that each key used in Sources/MicYouShared/L10n.swift exists and
that no key in the tables is left unused. Exits non-zero on any problem
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALIZATION = ROOT / "Support/Localization"
L10N = ROOT / "Sources/MicYouShared/L10n.swift"
# App Intents spell their keys out as literals so the compiler can record them
SOURCES = ROOT / "Sources"
BASE = "en"

ENTRY = re.compile(r'^"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
# Positional or plain specifiers such as %@, %1$@, %lld, %+.0f
SPEC = re.compile(r"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(ll|l|h)?([@dDuUxXoOfFeEgGcCsSp])")


def parse(path):
    entries = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("/*") or line.startswith("//"):
            continue
        match = ENTRY.match(line)
        if not match:
            raise SystemExit(f"{path.relative_to(ROOT)}:{number}: cannot parse: {line}")
        key, value = match.groups()
        if key in entries:
            raise SystemExit(f"{path.relative_to(ROOT)}:{number}: duplicate key {key}")
        entries[key] = value
    return entries


def specifiers(value):
    """Argument types by position, so reordered positional arguments still match"""
    found = {}
    for index, match in enumerate(SPEC.finditer(value.replace("%%", ""))):
        position = int(match.group(1)) if match.group(1) else index + 1
        found[position] = (match.group(2) or "") + match.group(3)
    return found


def main():
    problems = []
    languages = sorted(p.stem for p in LOCALIZATION.glob("*.lproj"))
    tables = sorted({p.name for p in LOCALIZATION.glob("*.lproj/*.strings")})

    for table in tables:
        base = parse(LOCALIZATION / f"{BASE}.lproj" / table)
        for language in languages:
            path = LOCALIZATION / f"{language}.lproj" / table
            if not path.exists():
                problems.append(f"{language}: missing {table}")
                continue
            entries = parse(path)
            for key in sorted(base.keys() - entries.keys()):
                problems.append(f"{language}/{table}: missing {key}")
            for key in sorted(entries.keys() - base.keys()):
                problems.append(f"{language}/{table}: extra {key}")
            for key in sorted(base.keys() & entries.keys()):
                if specifiers(base[key]) != specifiers(entries[key]):
                    problems.append(f"{language}/{table}: format arguments of {key} differ from {BASE}")

    used = set(re.findall(r'(?:string|format|resource)\("([^"]+)"', L10N.read_text(encoding="utf-8")))
    for path in SOURCES.rglob("*.swift"):
        used |= set(re.findall(r'"(intent\.[a-z0-9.-]+)"', path.read_text(encoding="utf-8")))
    strings = parse(LOCALIZATION / f"{BASE}.lproj/Localizable.strings")
    for key in sorted(used - strings.keys()):
        problems.append(f"L10n.swift: {key} is not in Localizable.strings")
    for key in sorted(strings.keys() - used):
        problems.append(f"Localizable.strings: {key} is never used")

    for problem in problems:
        print(problem)
    if problems:
        return 1
    print(f"OK: {len(strings)} keys, {len(languages)} languages, {len(tables)} tables")
    return 0


if __name__ == "__main__":
    sys.exit(main())
