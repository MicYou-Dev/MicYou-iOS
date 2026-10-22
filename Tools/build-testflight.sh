#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds an unsigned release IPA for TestFlight, it differs from the release IPA in its bundle identifier
# and, like release.yml, carries the commit count as its build number
# The identifiers are changed in the built bundles, so xtool.yml and the committed App Intents
# index keep the sideloaded identifier; the Xcode and SDK keys Xcode writes into every bundle and
# App Store Connect checks are added from the SDK the build used
# Usage: Tools/build-testflight.sh, TESTFLIGHT_BUNDLE_ID overrides the identifier, TESTFLIGHT_BUILD the build number,
# XCODE_DEVELOPER the Xcode Developer folder when it is not the selected Xcode or xtool's Darwin SDK
set -euo pipefail
cd "$(dirname "$0")/.."
BUNDLE_ID=${TESTFLIGHT_BUNDLE_ID:-com.nagishirazu.micyou}
# App Store Connect rejects an upload whose build number is not higher than the last one
BUILD=${TESTFLIGHT_BUILD:-$(git rev-list --count HEAD)}
if ! [[ "$BUILD" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "error: build number $BUILD is not up to three dot separated integers" >&2
    exit 1
fi

if [ -z "${XCODE_DEVELOPER:-}" ]; then
    if [ "$(uname)" = Darwin ]; then
        XCODE_DEVELOPER=$(xcode-select -p)
    else
        XCODE_DEVELOPER="$HOME/.swiftpm/swift-sdks/darwin.artifactbundle/Xcode.app/Contents/Developer"
    fi
fi
# Only macOS knows its own build, Xcode writes it as BuildMachineOSBuild
MACHINE_BUILD=$( [ "$(uname)" = Darwin ] && sw_vers -buildVersion || true)

xtool dev build -c release --ipa

payload=$(mktemp -d)
trap 'rm -rf "$payload"' EXIT
unzip -q xtool/MicYou.ipa -d "$payload"
python3 - "$payload/Payload/MicYou.app" "$BUNDLE_ID" "$BUILD" "$XCODE_DEVELOPER" "$MACHINE_BUILD" <<'EOF'
import json
import plistlib
import struct
import sys
from pathlib import Path

app, bundle_id, build, developer, machine_build = Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4]), sys.argv[5]
widget = app / "PlugIns/MicYouWidget.appex"


def fail(message):
    sys.exit(f"error: {message}")


def sdk_version(binary):
    """The SDK version in LC_BUILD_VERSION of a thin 64 bit Mach-O, as major.minor"""
    data = binary.read_bytes()
    if struct.unpack_from("<I", data)[0] != 0xFEEDFACF:
        fail(f"{binary.name} is not a thin 64 bit Mach-O")
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, offset)
        if cmd == 0x32:  # LC_BUILD_VERSION: platform, minos, sdk as xxxx.yy.zz in nibbles
            sdk = struct.unpack_from("<I", data, offset + 16)[0]
            return f"{sdk >> 16}.{(sdk >> 8) & 0xFF}"
        offset += size
    fail(f"{binary.name} has no LC_BUILD_VERSION")


# The keys Xcode writes into every bundle it builds, read from the SDK this build linked against
sdk = developer / "Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
if not sdk.is_dir():
    fail(f"no iPhoneOS SDK in {developer}, set XCODE_DEVELOPER")
settings = json.loads((sdk / "SDKSettings.json").read_text())
sdk_build = plistlib.loads((sdk / "System/Library/CoreServices/SystemVersion.plist").read_bytes())["ProductBuildVersion"]
xcode = plistlib.loads((developer.parent / "Info.plist").read_bytes())
build_keys = {
    "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
    "DTPlatformBuild": sdk_build,
    "DTPlatformName": "iphoneos",
    "DTPlatformVersion": settings["Version"],
    "DTSDKBuild": sdk_build,
    "DTSDKName": settings["CanonicalName"],
    "DTXcode": xcode["DTXcode"],
    "DTXcodeBuild": xcode["DTXcodeBuild"],
}
if machine_build:
    build_keys["BuildMachineOSBuild"] = machine_build

info = plistlib.loads((app / "Info.plist").read_bytes())
old_id = info["CFBundleIdentifier"]
ids = {old_id: bundle_id, f"{old_id}.MicYouWidget": f"{bundle_id}.MicYouWidget"}

for bundle, executable in [(app, "MicYou"), (widget, "MicYouWidget")]:
    # The keys would claim an SDK the binary was not linked against, see sdkVersion in Package.swift
    linked = sdk_version(bundle / executable)
    if linked != settings["Version"]:
        fail(f"{executable} records SDK {linked} but the SDK is {settings['Version']}, set MICYOU_IOS_SDK_VERSION")
    path = bundle / "Info.plist"
    plist = plistlib.loads(path.read_bytes())
    plist["CFBundleIdentifier"] = ids[plist["CFBundleIdentifier"]]
    # The widget must carry the same build number as the app
    plist["CFBundleVersion"] = build
    plist.update(build_keys)
    path.write_bytes(plistlib.dumps(plist))
    # The index names the bundles that may perform each intent
    index = bundle / "Metadata.appintents/extract.actionsdata"
    text = index.read_text()
    for old, new in ids.items():
        text = text.replace(f'"{old}"', f'"{new}"')
    if old_id in text:
        fail(f"{index} still names {old_id}")
    index.write_text(text)
    print(f"{bundle.name}: {plist['CFBundleIdentifier']} ({build}), {settings['CanonicalName']}, Xcode {xcode['DTXcodeBuild']}")
EOF

# Compressed like the release IPA
out="$PWD/xtool/MicYou-TestFlight.ipa"
rm -f "$out"
(cd "$payload" && zip -q -r -9 -y -X "$out" Payload)
ls -l "$out"
echo "Wrote $out"
