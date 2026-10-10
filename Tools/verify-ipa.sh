#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Checks the IPAs from build-livecontainer.sh, needs macOS for PlistBuddy and vtool
# The widget must survive linking (see docs/DEVELOPMENT.md), carry the app's version,
# the binary must record an SDK with Liquid Glass, and the LiveContainer IPA must have no extensions
set -euo pipefail
cd "$(dirname "$0")/.."
MIN_SDK_MAJOR=${MIN_SDK_MAJOR:-26}

fail() {
    echo "::error::$1"
    exit 1
}

check=$(mktemp -d)
trap 'rm -rf "$check"' EXIT
unzip -q xtool/MicYou.ipa -d "$check"
app="$check/Payload/MicYou.app"
widget="$app/PlugIns/MicYouWidget.appex"

test -d "$widget" || fail "Widget extension missing"
for key in CFBundleShortVersionString CFBundleVersion; do
    a=$(/usr/libexec/PlistBuddy -c "Print :$key" "$app/Info.plist")
    w=$(/usr/libexec/PlistBuddy -c "Print :$key" "$widget/Info.plist")
    [ "$a" = "$w" ] || fail "$key differs: app $a, widget $w"
done

xcrun vtool -show-build "$app/MicYou"
sdk=$(xcrun vtool -show-build "$app/MicYou" | awk '/sdk/ { print $2; exit }')
[ "${sdk%%.*}" -ge "$MIN_SDK_MAJOR" ] || fail "Binary records SDK $sdk, the app would run without Liquid Glass"

if unzip -l xtool/MicYou-LiveContainer.ipa | grep -q 'PlugIns/'; then
    fail "LiveContainer IPA still contains extensions"
fi
echo "IPAs OK: SDK $sdk, version $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
