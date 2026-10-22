#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Signs the IPA from Tools/build-testflight.sh for App Store Connect with the distribution
# certificate and the two App Store provisioning profiles in signing/profiles, needs macOS
set -euo pipefail
cd "$(dirname "$0")/.."

IPA_IN="${IPA_IN:-xtool/MicYou-TestFlight.ipa}"
IPA_OUT="${IPA_OUT:-xtool/MicYou-AppStore.ipa}"
CERT_P12="${CERT_P12:-signing/distribution.p12}"
MAIN_PROFILE="${MAIN_PROFILE:-signing/profiles/MicYou-AppStore.mobileprovision}"
WIDGET_PROFILE="${WIDGET_PROFILE:-signing/profiles/MicYouWidget-AppStore.mobileprovision}"

fail() {
    echo "$1" >&2
    exit 1
}

for file in "$IPA_IN" "$CERT_P12" "$MAIN_PROFILE" "$WIDGET_PROFILE"; do
    [[ -f "$file" ]] || fail "Missing $file"
done

p12_password="${P12_PASSWORD:-}"
if [[ -z "$p12_password" ]]; then
    read -r -s -p "p12 export password: " p12_password
    echo
fi
[[ -n "$p12_password" ]] || fail "The p12 password must not be empty"

mkdir -p "$(dirname "$IPA_OUT")"
IPA_OUT="$(cd "$(dirname "$IPA_OUT")" && pwd)/$(basename "$IPA_OUT")"

work="$(mktemp -d)"
keychain="$work/signing.keychain-db"
# The search list is put back as it was, paths may contain spaces
keychains=()
while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    keychains+=("${line//\"/}")
done < <(security list-keychains -d user)
cleanup() {
    security list-keychains -d user -s ${keychains[@]+"${keychains[@]}"} 2>/dev/null || true
    security delete-keychain "$keychain" 2>/dev/null || true
    rm -rf "$work"
}
trap cleanup EXIT

keychain_password="$(openssl rand -hex 16)"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$CERT_P12" -k "$keychain" -P "$p12_password" -A
security set-key-partition-list \
    -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" ${keychains[@]+"${keychains[@]}"}

identity="$(security find-identity -v -p codesigning "$keychain" |
    awk -F'"' '/Apple Distribution/ { print $2; exit }')"
[[ -n "$identity" ]] || fail "No Apple Distribution identity in $CERT_P12"
echo "Signing as: $identity"

unzip -q "$IPA_IN" -d "$work/ipa"
app="$work/ipa/Payload/MicYou.app"
widget="$app/PlugIns/MicYouWidget.appex"
[[ -d "$app" && -d "$widget" ]] || fail "Unexpected IPA layout in $IPA_IN"

extract_entitlements() {
    security cms -D -i "$1" > "$work/profile.plist"
    /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' "$work/profile.plist" > "$2"
}

extract_entitlements "$MAIN_PROFILE" "$work/app.entitlements"
extract_entitlements "$WIDGET_PROFILE" "$work/widget.entitlements"

# Catch a stale bundle ID before signing, the upload would fail much later
check_bundle_id() {
    local bundle="$1" entitlements="$2" label="$3"
    local expected actual
    expected="$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$entitlements")"
    expected="${expected#*.}"
    actual="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Info.plist")"
    [[ "$actual" == "$expected" ]] ||
        fail "$label bundle ID is $actual, profile expects $expected; build it with Tools/build-testflight.sh and the matching TESTFLIGHT_BUNDLE_ID"
}
check_bundle_id "$app" "$work/app.entitlements" "App"
check_bundle_id "$widget" "$work/widget.entitlements" "Widget"

# Sign nested code first, the containing bundle's signature covers it
while IFS= read -r -d '' nested; do
    codesign --force --timestamp --sign "$identity" "$nested"
done < <(find "$app" \( -name '*.framework' -o -name '*.dylib' \) -print0)

cp "$WIDGET_PROFILE" "$widget/embedded.mobileprovision"
codesign --force --timestamp --sign "$identity" \
    --entitlements "$work/widget.entitlements" "$widget"

cp "$MAIN_PROFILE" "$app/embedded.mobileprovision"
codesign --force --timestamp --sign "$identity" \
    --entitlements "$work/app.entitlements" "$app"

codesign --verify --deep --strict --verbose=2 "$app"

rm -f "$IPA_OUT"
(cd "$work/ipa" && zip -qry -X "$IPA_OUT" Payload)
echo "Signed IPA: $IPA_OUT"
