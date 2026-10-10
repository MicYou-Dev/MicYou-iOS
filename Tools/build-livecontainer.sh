#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds an unsigned release IPA without app extensions, for LiveContainer
# LiveContainer cannot sign or host extensions, so the widget is dropped
set -euo pipefail
cd "$(dirname "$0")/.."
xtool dev build -c release --ipa
out=xtool/MicYou-LiveContainer.ipa
cp xtool/MicYou.ipa "$out"
zip -q -d "$out" 'Payload/MicYou.app/PlugIns/*'
echo "Wrote $out"
