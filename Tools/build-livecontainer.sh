#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds an unsigned release IPA without app extensions, for LiveContainer
# LiveContainer cannot sign or host extensions, so the widget is dropped
set -euo pipefail
cd "$(dirname "$0")/.."
xtool dev build -c release --ipa

# xtool stores every file uncompressed, deflating them halves the download
ipa="$PWD/xtool/MicYou.ipa"
payload=$(mktemp -d)
trap 'rm -rf "$payload"' EXIT
unzip -q "$ipa" -d "$payload"
rm "$ipa"
(cd "$payload" && zip -q -r -9 -y -X "$ipa" Payload)

out=xtool/MicYou-LiveContainer.ipa
cp xtool/MicYou.ipa "$out"
zip -q -d "$out" 'Payload/MicYou.app/PlugIns/*'
ls -l xtool/*.ipa
echo "Wrote $out"
