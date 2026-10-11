# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository (`CLAUDE.md` is a symlink to it)

iOS client for MicYou: streams the phone microphone over the LAN to the MicYou 2.x desktop app. Swift 6 + SwiftUI, built with [xtool](https://github.com/xtool-org/xtool), no Xcode project, compiles and signs on both Linux and macOS

Detailed docs (in Chinese): `docs/ARCHITECTURE.md` (modules, threading, state machine, motion, localization), `docs/DEVELOPMENT.md` (xtool pitfalls, CI and releases, debugging, screenshots), `docs/PROTOCOL.md` (wire protocol with the desktop app)

## Eight honors and eight shames

- 以瞎猜接口为耻，以认真查询为荣: shame on guessing APIs, honor in looking them up
- 以模糊执行为耻，以寻求确认为荣: shame on acting on vague requirements, honor in asking for clarification
- 以臆想业务为耻，以人类确认为荣: shame on inventing business logic, honor in confirming it with a human
- 以创造接口为耻，以复用现有为荣: shame on creating new interfaces, honor in reusing existing ones
- 以跳过验证为耻，以主动测试为荣: shame on skipping verification, honor in testing proactively
- 以破坏架构为耻，以遵循规范为荣: shame on breaking the architecture, honor in following conventions
- 以假装理解为耻，以诚实无知为荣: shame on pretending to understand, honor in admitting what you do not know
- 以盲目修改为耻，以谨慎重构为荣: shame on blind edits, honor in careful refactoring

## Branches

- Local `main` tracks `origin/swiftui`, the active development line; `build.yml` also only triggers on pushes to `swiftui`
- The remote default branch `origin/v2` uses an older protocol (magic `0x694F5354`, port `8900`) that is incompatible with the 2.x desktop app; do not merge into it or use it as a reference

## Commands

```bash
xtool dev build                                         # build to xtool/MicYou.app (needs a Darwin SDK, see xtool setup)
xtool dev run                                           # build, sign and install on the connected device
swift test --package-path Packages/MicYouProtocol       # protocol library tests, run directly on Linux
swift test --package-path Packages/MicYouCore           # app logic tests (presets, reconnect, samples, meter), also on Linux
swift test --package-path Packages/MicYouProtocol --filter Framing/tcpHeaderIsBigEndian   # single test
Tools/check-strings.py                                  # localization keys, format specifiers and unused keys across all three languages
Tools/build-livecontainer.sh                            # release IPA plus a LiveContainer IPA without the widget
Tools/verify-ipa.sh                                     # checks the extension is bundled and the SDK version is >= 26
python3 Tools/mock_receiver.py --mdns --toggle-mute 5   # fake desktop receiver, saves received PCM as WAV
```

- Only `MicYouProtocol` and `MicYouCore` (pure Foundation) can be tested on Linux; the app and widget depend on iOS frameworks and have no unit tests, so logic that needs no Apple framework belongs in `MicYouCore`
- Tests use Swift Testing (`@Suite` / `@Test` / `#expect`), not XCTest
- CI `check.yml` runs both package test suites and `check-strings.py`; run them locally after touching strings, the protocol or core logic

## Architecture

### Modules (see `Package.swift`)

- `MicYouProtocol` (separate package under `Packages/`): hand-written protobuf codec (`ProtoWire.swift`, no third-party deps), TCP `MicY` / UDP `MicU` framing, `AudioSequencer` numbering and XOR FEC, manual address parsing; upstream definition in `Proto/network.proto`
- `MicYouCore` (separate package under `Packages/`, depends on `MicYouProtocol`): transport and codec choices, presets, `StreamOptions`, `ReconnectPolicy`, `SampleProcessor` and `PeakLimiter`, `MeterBallistics`, `InputPreference`, Bonjour display names
- `MicYouShared`: `L10n`, `DeepLink`, `StreamActivityAttributes`, shared by the app and the widget
- `MicYou`: the app; `MicYouWidget`: Live Activity and Dynamic Island
- The widget shares no storage with the app and there is no App Group; every button routes back to the app through `micyou://` links (`DeepLink`)

### Data flow

`AudioCapture` (AVAudioEngine tap, resample, then `SampleProcessor`: gain, `PeakLimiter`, convert to Int16) → `SessionSink` (forwards under a lock, pushes levels to the main thread at up to 30 Hz) → `StreamSession` (Opus encode or PCM chunking, sequencing, FEC) → UDP by default (TCP port + 1), or `ControlChannel` in TCP-only mode

- On connect, `AppSettings.streamConfig` freezes settings into a `StreamConfig` (endpoint plus `StreamOptions`) for the session; changes made while streaming apply to the next connection, or right away through `AppModel.restart()` ("Reconnect Now to Apply" in Settings). Input gain and the microphone choice apply immediately
- A remembered Bonjour computer connects through `NWEndpoint.service` built from its instance name, without waiting for the browser, so Shortcuts, links and connect on open work right after launch
- `AudioCapture` reports interruptions (calls, other apps) and failed restarts to `AppModel.captureStatus`; the connection stays up meanwhile and capture is retried when the interruption ends or the app returns to the foreground
- `ControlChannel` handles the handshake, heartbeats, two-way mute sync and the desktop's once-a-second link stats, and treats 5 seconds without a `ping` as a disconnect; when the TCP send backlog exceeds 128 KiB new audio packets are dropped
- USB (`StreamLink.usb`): usbmuxd only lets the computer connect, so `ControlChannel` listens on loopback and runs the normal client handshake once the desktop in USB mode connects; audio is forced to TCP-only (`StreamOptions.overUSB`)

### Threading

- `@MainActor`: `AppModel`, `AppSettings`, `ServerBrowser`, `LiveActivityController` and all views
- Potentially blocking calls (activating `AVAudioSession`, loading converters, `Activity.request`) must **not** run on the main thread, they drop frames in the connect animation
- `AudioCapture` has its own serial capture queue; the audio callback thread and the capture queue only exchange state through locks
- Each `StreamSession` has one serial queue running its `ControlChannel`, UDP connection, Opus encoder and reconnect timer
- Session events return to `AppModel` via `Task { @MainActor in }`; each session carries a unique token and the main thread checks it to drop late events from old sessions

### Reconnect

States `idle → connecting → streaming ⇄ reconnecting(n) → failed`; reconnects only when auto-reconnect is on, the connection has streamed successfully, the error is retryable (handshake and protocol errors are not) and fewer than 6 attempts were made, with delays of `1, 2, 4, 8, 15, 15` seconds; capture is **not** stopped while reconnecting, which keeps background recording from being suspended

## Conventions

- User-visible strings go only through `Sources/MicYouShared/L10n.swift`; to add one: add the key to all three `Support/Localization/*.lproj/Localizable.strings` → add a property in `L10n.swift` → run `Tools/check-strings.py`; full sentences end with a period, buttons and short labels have no punctuation
- Display text shared by the UI and the Live Activity (codec names, transport modes) lives in `Views/Common/StreamText.swift`
- Settings explain themselves with a toggle subtitle or a `SettingHint` under the row, which follows the current choice; a conflicting combination gets a warning hint with a button that fixes it. Avoid long section footers
- Animation durations and curves come from `Motion` in `Views/Common/Motion.swift`; appear and disappear with `adaptiveTransition` / `adaptiveAnimation` (they respect Reduce Motion)
- Stateful glass buttons use `glassSurface` and only change `tint`; do not switch between two `buttonStyle`s, and do not use filter transitions such as `blurReplace` on glass views
- The Live Activity only updates when state, mute, microphone or format changes, and has no level meter (frequent updates make `Text(timerInterval:)` flicker)
- Logging uses `Logger` from `Log.swift`, subsystem `com.chouchiu.micyou`, categories `model` / `capture` / `session` / `control` / `browser` / `activity` / `update`; messages are English sentences without a trailing period, details after a colon, errors as `String(describing:)` with `privacy: .public`, addresses and device names left private. The About page exports them as `YYYY/MM/DD HH:MM:SS.mmm [LEVEL] module: message` through `LogFormatter` in `MicYouCore`
- Every source file starts with `// SPDX-License-Identifier: GPL-3.0-or-later`; code comments are in English with no trailing period
- Commit messages in English, `<type>: <description>`, types `feat` / `fix` / `refactor` / `style` / `docs` / `chore`

## xtool pitfalls

- `sdkVersion` in `Package.swift` (default `27.1`, overridden in CI by `MICYOU_IOS_SDK_VERSION`) fixes the Mach-O SDK version via `-platform_version`; without it iOS runs the app in compatibility mode with no Liquid Glass; update it when the local Darwin SDK changes
- Keep the `-u _main` linker flag on `MicYouWidget`, otherwise the widget `@main` is dead stripped; do not change it to `-e _main` either (assertion crash at launch)
- No SwiftPM resource bundles: the icon, licenses and `.lproj` folders are copied to the `.app` root by `resources` in `xtool.yml`; the widget extension lists its own localization folders, so a new language must be added in both places
- xtool does not run the App Intents metadata processor, so Shortcuts may not show the actions in `Intents/`; Live Activity buttons therefore use `Link` to open `micyou://`
- `Resources/AppIcon/Assets.car` can only be compiled by `actool` on macOS; trigger the `compile-icon.yml` workflow manually and replace the file with its output
- When upgrading xtool, update the version and SHA-256 in `.github/actions/setup-xtool/action.yml`

## Device debugging

USB screenshots and launch: `pymobiledevice3 developer dvt screenshot --userspace shot.png`; `pymobiledevice3 developer dvt launch --userspace "<Bundle ID> <args>"`, with launch arguments `-welcomeShown NO`, `-tourShown NO`, `-MicYouTourStep 3` (Debug only), `-host 192.168.1.5`; README screenshots are scaled to `660 × 1434` and stored in `docs/screenshots/`
