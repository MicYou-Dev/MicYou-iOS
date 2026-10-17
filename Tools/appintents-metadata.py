#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Writes Metadata.appintents from the compiler's .swiftconstvalues files

Xcode runs the closed appintentsmetadataprocessor after linking, which only runs on macOS,
and iOS lists an app's App Intents only from the index it writes. The compiler records the
same input as JSON on Linux too, so this script writes the index itself in the format of
Xcode 26.6 (tools build 17F113), one for the app and one for the widget extension. It only
covers what MicYou uses, intents without parameters, the system protocols below and one
AppShortcutsProvider, and stops on anything else rather than writing a wrong index

Usage: Tools/appintents-metadata.py [--configuration Debug|Release] [--check]
Run it after xtool dev build; --check exits non-zero when the committed index is stale
"""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS_VERSION = "17F113"
APP_ID = "com.chouchiu.micyou"
SHARED_MODULE = "MicYouShared"
# Bundle executable to its bundle identifier and the modules linked into it
BUNDLES = {
    "MicYou": (APP_ID, [SHARED_MODULE, "MicYou"]),
    "MicYouWidget": (f"{APP_ID}.MicYouWidget", [SHARED_MODULE, "MicYouWidget"]),
}
OUTPUT = ROOT / "Resources/AppIntents"

# Conformances to identifiers, as Xcode writes them for LiveActivityIntent and
# AudioRecordingIntent; these make the system run the intent in the app's process
SYSTEM_PROTOCOLS = {
    "AppIntents.AudioRecordingIntent": "com.apple.link.systemProtocol.AudioRecording",
    "AppIntents.LiveActivityIntent": "com.apple.link.systemProtocol.SessionStarting",
}
# Conformances every intent has, they add nothing to the index
PLAIN_CONFORMANCES = {
    "AppIntents.AppIntent", "AppIntents.SystemIntent", "AppIntents.PersistentlyIdentifiable",
    "AppIntents._SupportsAppDependencies",
}
# Fields of a const values entry this script understands, others such as availability are refused
ENTRY_FIELDS = {"allConformances", "associatedTypeAliases", "conformances", "file", "kind", "line",
                "mangledTypeName", "properties", "typeName"}

# PerformResult protocols to outputFlags bits, only the ones seen in Xcode's output
OUTPUT_FLAGS = {"AppIntents.IntentResult": 0, "AppIntents.ProvidesDialog": 4}


class Unsupported(Exception):
    pass


def const_values_dirs(configuration, module):
    # Swift Build (Linux) keeps one file per source or a -primary file per module, SwiftPM's
    # native build (macOS CI) one file per module
    return [
        ROOT / ".build/out/Intermediates.noindex/MicYou.build" / f"{configuration}-iphoneos"
        / f"{module}-t.build/Objects-normal/arm64",
        ROOT / ".build/arm64-apple-ios" / configuration.lower() / f"{module}.build",
    ]


def const_values_files(configuration, module):
    # A checkout that used both build systems has both, the newest build is the one to index
    builds = [files for files in (sorted(directory.glob("*.swiftconstvalues"))
                                  for directory in const_values_dirs(configuration, module)) if files]
    return max(builds, key=lambda files: max(path.stat().st_mtime for path in files), default=[])


def conforms(entry, protocol):
    return f"AppIntents.{protocol}" in entry.get("conformances", [])


def prop(entry, label):
    return next((p for p in entry.get("properties", []) if p["label"] == label), None)


def literal(value, what):
    if value is None:
        return None
    if value.get("valueKind") != "RawLiteral":
        raise Unsupported(f"{what} is {value.get('valueKind')}, only literals can be indexed")
    return value["value"]


def localized(key):
    return {"alternatives": [], "key": key}


def availability():
    return {"LNPlatformNameWildcard": {"introducedVersion": "*"}}


def output_flags(entry):
    flags = 0
    for alias in entry.get("associatedTypeAliases", []):
        if alias["typeAliasName"] != "PerformResult":
            continue
        for protocol in alias["opaqueTypeProtocolRequirements"]:
            if protocol not in OUTPUT_FLAGS:
                raise Unsupported(f"{entry['typeName']} returns {protocol}")
            flags |= OUTPUT_FLAGS[protocol]
    return flags


def system_protocols(entry):
    result = []
    for conformance in entry["conformances"]:
        if conformance in SYSTEM_PROTOCOLS:
            result.append(SYSTEM_PROTOCOLS[conformance])
        elif conformance.startswith("AppIntents.") and conformance not in PLAIN_CONFORMANCES:
            raise Unsupported(f"{entry['typeName']} conforms to {conformance}")
    return sorted(result)


def action(entry, bundle_ids):
    name = entry["typeName"]
    identifier = name.split(".")[-1]
    for p in entry.get("properties", []):
        if "propertyWrappers" in p or p["label"].startswith("$"):
            raise Unsupported(f"{name} has parameters")
    if prop(entry, "supportedModes"):
        raise Unsupported(f"{name} sets supportedModes")
    title = literal(prop(entry, "title"), f"{name}.title")
    if title is None:
        raise Unsupported(f"{name} has no title")
    description = literal(prop(entry, "description"), f"{name}.description")
    opens_app = literal(prop(entry, "openAppWhenRun"), f"{name}.openAppWhenRun") == "true"
    discoverable = literal(prop(entry, "isDiscoverable"), f"{name}.isDiscoverable") != "false"
    protocols = system_protocols(entry)
    # Encoded like a dictionary with non-string keys, alternating identifier and metadata
    protocol_metadata = [item for protocol in protocols for item in (protocol, {"empty": {}})]
    # An intent from the shared module lives in several binaries, the system has to be told which
    by_bundle = {bundle_id: entry["mangledTypeName"] for bundle_id in bundle_ids}
    result = {
        "assistantDefinedSchemaTraits": [],
        "assistantDefinedSchemas": [],
        "authenticationPolicy": 0,
        "availabilityAnnotations": availability(),
        "effectiveBundleIdentifiers": [],
        "fullyQualifiedTypeName": name,
        "identifier": identifier,
        "isAuthPolExplicit": False,
        "isDiscoverable": discoverable,
        "mangledTypeName": entry["mangledTypeName"],
        "mangledTypeNameByBundleIdentifier": by_bundle,
        "mangledTypeNameByBundleIdentifierV2": by_bundle,
        "mangledTypeNameV2": entry["mangledTypeName"],
        "openAppWhenRun": opens_app,
        "outputFlags": output_flags(entry),
        "parameters": [],
        "presentationStyle": 0,
        "requiredCapabilities": [],
        # 1 runs in the background, 2 opens the app first
        "supportedModes": 2 if opens_app else 1,
        "systemProtocolMetadata": protocol_metadata,
        "systemProtocolMetadataV2": protocol_metadata,
        "systemProtocols": protocols,
        "title": localized(title),
        "typeSpecificMetadata": [],
        "visibilityMetadata": {"assistantOnly": False, "isDiscoverable": discoverable},
    }
    if description is not None:
        result["descriptionMetadata"] = {"descriptionText": localized(description), "searchKeywords": []}
    return identifier, result


def phrase(value):
    if value["valueKind"] == "RawLiteral":
        return value["value"]
    if value["valueKind"] != "InterpolatedStringLiteral":
        raise Unsupported(f"phrase is {value['valueKind']}")
    text = ""
    for segment in value["value"]["segments"]:
        if segment["valueKind"] == "RawLiteral":
            text += segment["value"]
        elif segment["valueKind"] == "Enum" and segment["value"]["name"] == "applicationName":
            text += "${applicationName}"
        else:
            raise Unsupported("phrases may only interpolate .applicationName")
    return text


def shortcuts(entry):
    builder = prop(entry, "appShortcuts")
    if builder is None or builder["valueKind"] != "Builder":
        raise Unsupported(f"{entry['typeName']}.appShortcuts is not a result builder")
    result = []
    for member in builder["value"]["members"]:
        element = member.get("element", {})
        if member.get("kind") != "buildExpression" or element.get("valueKind") != "InitCall":
            raise Unsupported("appShortcuts may only list AppShortcut(...) calls")
        args = {a["label"]: a for a in element["value"]["arguments"]}
        shortcut = {
            "actionIdentifier": args["intent"]["type"].split(".")[-1],
            "availabilityAnnotations": availability(),
            "phraseTemplates": [localized(phrase(p)) for p in args["phrases"]["value"]],
        }
        short_title = literal(args.get("shortTitle"), "shortTitle")
        if short_title is not None:
            shortcut["shortTitle"] = localized(short_title)
        image = literal(args.get("systemImageName"), "systemImageName")
        if image is not None:
            shortcut["systemImageName"] = image
        result.append(shortcut)
    return result


def metadata(entries, shared_bundle_ids=()):
    actions = {}
    providers = []
    for entry in entries:
        unknown = set(entry) - ENTRY_FIELDS
        if unknown and any(c.startswith("AppIntents.") for c in entry.get("conformances", [])):
            raise Unsupported(f"{entry['typeName']} has {', '.join(sorted(unknown))}")
        if conforms(entry, "AppIntent"):
            shared = entry["typeName"].startswith(f"{SHARED_MODULE}.")
            identifier, value = action(entry, shared_bundle_ids if shared else ())
            actions[identifier] = value
        elif conforms(entry, "AppShortcutsProvider"):
            providers.append(entry)
        elif any(c.startswith("AppIntents.") for c in entry.get("conformances", [])):
            raise Unsupported(f"{entry['typeName']} conforms to {entry['conformances']}")
    if len(providers) > 1:
        raise Unsupported("more than one AppShortcutsProvider")
    for shortcut in shortcuts(providers[0]) if providers else []:
        if shortcut["actionIdentifier"] not in actions:
            raise Unsupported(f"shortcut for unknown intent {shortcut['actionIdentifier']}")
    result = {
        "actions": actions,
        "assistantEntities": [],
        "assistantIntentNegativePhrases": [],
        "assistantIntents": [],
        "autoShortcuts": shortcuts(providers[0]) if providers else [],
        "entities": {},
        "enums": [],
        "generator": {"name": "xcode-tools", "version": TOOLS_VERSION},
        "negativePhrases": [],
        "queries": {},
        "shortcutTileColor": 14,
        "version": 1,
    }
    # Left out without a provider, as in Xcode's index of a widget extension
    if providers:
        result["autoShortcutProviderMangledName"] = providers[0]["mangledTypeName"]
    return result


def render(entries, shared_bundle_ids=()):
    actions = json.dumps(metadata(entries, shared_bundle_ids), indent=4, sort_keys=True, ensure_ascii=False) + "\n"
    version = '{\n  "version" : "3.0",\n  "toolsVersion" : "%s"\n}\n' % TOOLS_VERSION
    return {"extract.actionsdata": actions, "version.json": version}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--configuration", default="Debug", choices=["Debug", "Release"])
    parser.add_argument("--check", action="store_true", help="fail if the committed index differs")
    args = parser.parse_args()

    shared_bundle_ids = sorted(bundle_id for bundle_id, _ in BUNDLES.values())
    outputs = {}
    for bundle, (_, modules) in BUNDLES.items():
        files = []
        for module in modules:
            found = const_values_files(args.configuration, module)
            if not found:
                searched = " or ".join(str(path.relative_to(ROOT)) for path in const_values_dirs(args.configuration, module))
                sys.exit(f"No .swiftconstvalues for {module} in {searched}, run xtool dev build first")
            files += found
        entries = [entry for path in files for entry in json.loads(path.read_text(encoding="utf-8"))]
        try:
            rendered = render(entries, shared_bundle_ids)
        except Unsupported as error:
            sys.exit(f"Cannot index App Intents of {bundle}: {error}")
        for name, text in rendered.items():
            outputs[OUTPUT / bundle / "Metadata.appintents" / name] = text

    if args.check:
        stale = [path for path, text in outputs.items()
                 if not path.exists() or path.read_text(encoding="utf-8") != text]
        if stale:
            names = ", ".join(str(path.relative_to(ROOT)) for path in stale)
            sys.exit(f"App Intents index is out of date, run Tools/appintents-metadata.py: {names}")
        print(f"OK: {OUTPUT.relative_to(ROOT)} is up to date")
        return
    for path, text in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    for bundle in BUNDLES:
        actions = json.loads(outputs[OUTPUT / bundle / "Metadata.appintents/extract.actionsdata"])["actions"]
        print(f"Wrote {bundle}: {', '.join(sorted(actions))}")


if __name__ == "__main__":
    main()
