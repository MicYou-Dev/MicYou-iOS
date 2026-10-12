// SPDX-License-Identifier: GPL-3.0-or-later
// Every user visible string, looked up in Support/Localization/*.lproj/Localizable.strings
// English lives in en.lproj like the other languages, code only refers to keys through here

import Foundation

public enum L10n {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: args)
    }

    /// For APIs that take a LocalizedStringResource, such as App Intents and controls
    static func resource(_ key: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(key))
    }

    public enum App {
        public static var name: String { string("app.name") }
    }

    public enum Common {
        public static var connect: String { string("common.connect") }
        public static var disconnect: String { string("common.disconnect") }
        public static var cancel: String { string("common.cancel") }
        public static var mute: String { string("common.mute") }
        public static var unmute: String { string("common.unmute") }
        public static var settings: String { string("common.settings") }
        public static var done: String { string("common.done") }
        public static var openSettings: String { string("common.open-settings") }
        public static var retry: String { string("common.retry") }
        public static var resume: String { string("common.resume") }
        public static var holdToTalk: String { string("common.hold-to-talk") }
        public static var dismiss: String { string("common.dismiss") }
        public static var mono: String { string("common.mono") }
        public static var stereo: String { string("common.stereo") }

        /// For example "Opus 48 kHz"
        public static func codecAndRate(_ codec: String, _ rate: String) -> String { format("common.codec-rate", codec, rate) }

        /// Joins short facts such as "Opus 48 kHz" and "Stereo" on one line
        public static func joined(_ parts: [String]) -> String {
            parts.filter { !$0.isEmpty }.joined(separator: string("common.separator"))
        }
    }

    public enum Unit {
        public static func kbps(_ value: Int) -> String { format("unit.kbps", value) }
        public static func kHz(_ hertz: Int) -> String {
            let value = hertz % 1000 == 0 ? String(hertz / 1000) : String(format: "%.1f", Double(hertz) / 1000)
            return format("unit.khz", value)
        }
        public static func dB(_ value: Int) -> String { format("unit.db", value) }
        public static func signedDB(_ value: Double) -> String { format("unit.db-signed", value) }
        public static func ms(_ value: Int) -> String { format("unit.ms", value) }
    }

    public enum Status {
        public static var connecting: String { string("status.connecting") }
        public static var reconnecting: String { string("status.reconnecting") }
        public static func reconnectingAttempt(_ attempt: Int, of total: Int) -> String {
            format("status.reconnecting-attempt", attempt, total)
        }
        public static var streaming: String { string("status.streaming") }
        /// Placeholder while the elapsed time is not known yet
        public static var waiting: String { string("status.waiting") }
        public static var muted: String { string("status.muted") }
        public static var interrupted: String { string("status.interrupted") }
        public static var talking: String { string("status.talking") }
        public static var failed: String { string("status.failed") }
        public static func ready(_ name: String) -> String { format("status.ready", name) }
        public static var duration: String { string("status.duration") }
        public static var formatLabel: String { string("status.format") }
        public static var bitrate: String { string("status.bitrate") }
        public static var inputLevel: String { string("status.input-level") }
        public static var transport: String { string("status.transport") }
        /// Short form of forward error correction for the stats tile
        public static var fec: String { string("status.fec") }
        public static var roundTrip: String { string("status.round-trip") }
        public static var packetLoss: String { string("status.packet-loss") }
        public static var mutedDetail: String { string("status.muted-detail") }
        public static var pushToTalkDetail: String { string("status.push-to-talk-detail") }
        public static var reconnectDetail: String { string("status.reconnect-detail") }
        public static var interruptedDetail: String { string("status.interrupted-detail") }
        public static var resumeFailedDetail: String { string("status.resume-failed-detail") }
    }

    public enum Home {
        public static var nearbyHeader: String { string("home.nearby.header") }
        public static var searching: String { string("home.nearby.searching") }
        public static var searchHint: String { string("home.nearby.hint") }
        public static var localNetworkDenied: String { string("home.nearby.denied") }
        public static var browsingUnavailable: String { string("home.nearby.unavailable") }
        public static var searchingMore: String { string("home.nearby.more") }
        public static var manualHeader: String { string("home.manual.header") }
        public static var address: String { string("home.manual.address") }
        public static var addressPlaceholder: String { string("home.manual.address-placeholder") }
        public static var port: String { string("home.manual.port") }
        public static var recentAddresses: String { string("home.manual.recent") }
        public static func manualHint(port: Int) -> String { format("home.manual.hint", String(port)) }
        public static var manualInvalid: String { string("home.manual.invalid") }
        public static var useAddress: String { string("home.manual.use") }
        public static var usbHeader: String { string("home.usb.header") }
        public static var usbName: String { string("home.usb.name") }
        public static var usbSubtitle: String { string("home.usb.subtitle") }
        public static var usbHint: String { string("home.usb.hint") }
        public static var targetLabel: String { string("home.target.label") }
        public static var noTarget: String { string("home.target.none") }
        public static var change: String { string("home.target.change") }
        public static var chooseComputer: String { string("home.choose") }
        public static var hint: String { string("home.hint") }
        public static var formatHeader: String { string("home.format") }
        public static var notOnWiFi: String { string("home.network.cellular") }
        public static var offline: String { string("home.network.offline") }
        public static var networkText: String { string("home.network.text") }
        public static var useUSB: String { string("home.network.use-usb") }
        public static func updateTitle(_ version: String) -> String { format("home.update.title", version) }
        public static var updateText: String { string("home.update.text") }
        public static var viewUpdate: String { string("home.update.view") }
        public static func updateNotesTitle(_ version: String) -> String { format("home.update.notes", version) }
        public static var downloadUpdate: String { string("home.update.download") }
        public static var translateNotes: String { string("home.update.translate") }
        public static var showOriginalNotes: String { string("home.update.original") }
        public static var newFeature: String { string("home.update.kind.feat") }
        public static var bugFix: String { string("home.update.kind.fix") }
        public static var refactor: String { string("home.update.kind.refactor") }
        public static var design: String { string("home.update.kind.style") }
        public static var documentation: String { string("home.update.kind.docs") }
        public static var otherChange: String { string("home.update.kind.chore") }
    }

    public enum Settings {
        public static var appliesNextTime: String { string("settings.applies-next-time") }
        public static var reconnectToApply: String { string("settings.reconnect-to-apply") }
        public static var presets: String { string("settings.preset") }
        public static var presetLowLatency: String { string("settings.preset.low-latency") }
        public static var presetStable: String { string("settings.preset.stable") }
        public static var presetLossless: String { string("settings.preset.lossless") }
        public static var connection: String { string("settings.connection") }
        public static var transport: String { string("settings.transport") }
        public static var tcpUDP: String { string("settings.transport.tcp-udp") }
        public static var tcpOnly: String { string("settings.transport.tcp") }
        public static var tcpUDPHint: String { string("settings.transport.tcp-udp.hint") }
        public static var tcpOnlyHint: String { string("settings.transport.tcp.hint") }
        public static var transportUSBHint: String { string("settings.transport.usb-hint") }
        public static var fec: String { string("settings.fec") }
        public static var fecDetail: String { string("settings.fec.detail") }
        public static var fecDetailTCP: String { string("settings.fec.detail-tcp") }
        public static var autoReconnect: String { string("settings.auto-reconnect") }
        public static var autoConnect: String { string("settings.auto-connect") }
        public static var autoConnectDetail: String { string("settings.auto-connect.detail") }
        public static var audio: String { string("settings.audio") }
        public static var codec: String { string("settings.codec") }
        public static var opus: String { string("settings.codec.opus") }
        public static var pcm: String { string("settings.codec.pcm") }
        public static var pcmShort: String { string("settings.codec.pcm-short") }
        public static var opusHint: String { string("settings.codec.opus.hint") }
        public static var pcmHint: String { string("settings.codec.pcm.hint") }
        public static var bitrate: String { string("settings.bitrate") }
        public static var sampleRate: String { string("settings.sample-rate") }
        public static var opusNo44: String { string("settings.sample-rate.opus-44") }
        public static var channels: String { string("settings.channels") }
        public static var stereoVoiceProcessing: String { string("settings.channels.voice-processing") }
        public static var turnOffVoiceProcessing: String { string("settings.channels.turn-off-voice-processing") }
        public static var dataRate: String { string("settings.data-rate") }
        public static func dataRateValue(_ rate: String) -> String { format("settings.data-rate.value", rate) }
        public static var microphone: String { string("settings.microphone") }
        public static var input: String { string("settings.input") }
        public static var inputGain: String { string("settings.input-gain") }
        public static var voiceProcessing: String { string("settings.voice-processing") }
        public static var voiceProcessingDetail: String { string("settings.voice-processing.detail") }
        public static var highQualityBluetooth: String { string("settings.bluetooth-hq") }
        public static var highQualityBluetoothDetail: String { string("settings.bluetooth-hq.detail") }
        public static var highQualityBluetoothVoiceProcessing: String { string("settings.bluetooth-hq.voice-processing") }
        public static var micMode: String { string("settings.mic-mode") }
        public static var micModeStandard: String { string("settings.mic-mode.standard") }
        public static var micModeWideSpectrum: String { string("settings.mic-mode.wide-spectrum") }
        public static var micModeVoiceIsolation: String { string("settings.mic-mode.voice-isolation") }
        public static var micModeFooter: String { string("settings.mic-mode.footer") }
        public static var general: String { string("settings.general") }
        public static var pushToTalk: String { string("settings.push-to-talk") }
        public static var pushToTalkDetail: String { string("settings.push-to-talk.detail") }
        public static var keepScreenOn: String { string("settings.keep-screen-on") }
        public static var liveActivity: String { string("settings.live-activity") }
        public static var liveActivityDetail: String { string("settings.live-activity.detail") }
    }

    public enum About {
        public static var title: String { string("about.title") }
        public static func versionValue(_ short: String, build: String) -> String { format("about.version.value", short, build) }
        public static var tagline: String { string("about.tagline") }
        public static var copy: String { string("about.copy") }
        public static var protocolLabel: String { string("about.protocol") }
        public static var protocolValue: String { string("about.protocol.value") }
        public static var defaultPort: String { string("about.default-port") }
        public static var feedback: String { string("about.feedback") }
        public static var reportBug: String { string("about.report-bug") }
        public static var requestFeature: String { string("about.request-feature") }
        public static var copyDiagnostics: String { string("about.copy-diagnostics") }
        public static var copyDiagnosticsDetail: String { string("about.copy-diagnostics.detail") }
        public static var copied: String { string("about.copied") }
        public static var exportLogs: String { string("about.export-logs") }
        public static var preparingLogs: String { string("about.preparing-logs") }
        public static var exportLogsDetail: String { string("about.export-logs.detail") }
        public static var feedbackFooter: String { string("about.feedback.footer") }
        public static var community: String { string("about.community") }
        public static var qqGroup: String { string("about.qq") }
        public static var telegram: String { string("about.telegram") }
        public static var discussions: String { string("about.discussions") }
        public static var website: String { string("about.website") }
        public static var project: String { string("about.project") }
        public static var help: String { string("about.help") }
        public static var quickStart: String { string("about.quick-start") }
        public static var faq: String { string("about.faq") }
        public static var replayIntroduction: String { string("about.replay-introduction") }
        public static var desktop: String { string("about.desktop") }
        public static var sourceCode: String { string("about.source-code") }
        public static var releases: String { string("about.releases") }
        public static var updates: String { string("about.updates") }
        public static func currentVersion(_ version: String) -> String { format("about.updates.current", version) }
        public static var checkingUpdates: String { string("about.updates.checking") }
        public static var upToDate: String { string("about.updates.latest") }
        public static var updateCheckFailed: String { string("about.updates.failed") }
        public static func downloadVersion(_ version: String) -> String { format("about.updates.download", version) }
        public static var autoCheckUpdates: String { string("about.updates.auto") }
        public static var autoCheckUpdatesDetail: String { string("about.updates.auto.detail") }
        public static var updatesFooter: String { string("about.updates.footer") }
        public static var acknowledgements: String { string("about.acknowledgements") }
        public static var license: String { string("about.license") }
        public static var notice: String { string("about.notice") }
        public static var footer: String { string("about.footer") }
    }

    public enum Welcome {
        public static var title: String { string("welcome.title") }
        public static var subtitle: String { string("welcome.subtitle") }
        public static var desktopTitle: String { string("welcome.desktop.title") }
        public static var desktopText: String { string("welcome.desktop.text") }
        public static var networkTitle: String { string("welcome.network.title") }
        public static var networkText: String { string("welcome.network.text") }
        public static var appsTitle: String { string("welcome.apps.title") }
        public static var appsText: String { string("welcome.apps.text") }
        public static var start: String { string("welcome.start") }
    }

    public enum Tour {
        /// For example "2/4"
        public static func progress(_ step: Int, of total: Int) -> String { format("tour.progress", step, total) }
        public static var skip: String { string("tour.skip") }
        public static var next: String { string("tour.next") }
        public static var computerTitle: String { string("tour.computer.title") }
        public static var computerText: String { string("tour.computer.text") }
        public static var connectTitle: String { string("tour.connect.title") }
        public static var connectText: String { string("tour.connect.text") }
        public static var formatTitle: String { string("tour.format.title") }
        public static var formatText: String { string("tour.format.text") }
        public static var settingsTitle: String { string("tour.settings.title") }
        public static var settingsText: String { string("tour.settings.text") }
    }

    public enum Credits {
        public static var included: String { string("credits.included") }
        public static var includedFooter: String { string("credits.included.footer") }
        public static var references: String { string("credits.references") }
        public static var referencesFooter: String { string("credits.references.footer") }
        public static var viewSource: String { string("credits.view-source") }
        public static var textUnavailable: String { string("credits.text-unavailable") }
        public static var appRole: String { string("credits.app.role") }
        public static var protocolRole: String { string("credits.protocol.role") }
        public static var micyouAuthor: String { string("credits.micyou.author") }
        public static var micyouRole: String { string("credits.micyou.role") }
        public static var micyouIOSAuthor: String { string("credits.micyou-ios.author") }
        public static var micyouIOSRole: String { string("credits.micyou-ios.role") }
        public static var iconName: String { string("credits.icon.name") }
        public static var iconRole: String { string("credits.icon.role") }
        public static var micwispRole: String { string("credits.micwisp.role") }
        public static var xtoolRole: String { string("credits.xtool.role") }
    }

    public enum Failure {
        public static var chooseTarget: String { string("error.choose-target") }
        public static var opusUnavailable: String { string("error.opus-unavailable") }
        public static func unreachable(_ reason: String) -> String { format("error.unreachable", reason) }
        public static var refused: String { string("error.refused") }
        public static var hostUnreachable: String { string("error.host-unreachable") }
        public static var notFound: String { string("error.not-found") }
        public static var timeout: String { string("error.timeout") }
        public static var handshake: String { string("error.handshake") }
        public static var heartbeat: String { string("error.heartbeat") }
        public static var closedByPeer: String { string("error.closed") }
        public static func unexpectedData(_ detail: String) -> String { format("error.unexpected-data", detail) }
        public static var noPeerAddress: String { string("error.no-peer-address") }
        public static var udpFailed: String { string("error.udp") }
        public static var usbTimeout: String { string("error.usb-timeout") }
        public static var micDenied: String { string("error.mic-denied") }
        public static var noMicrophone: String { string("error.no-mic") }
        public static var formatUnsupported: String { string("error.format-unsupported") }
    }

    public enum Intent {
        public static var startTitle: LocalizedStringResource { resource("intent.start.title") }
        public static var startDescription: LocalizedStringResource { resource("intent.start.description") }
        public static var stopTitle: LocalizedStringResource { resource("intent.stop.title") }
        public static var stopDescription: LocalizedStringResource { resource("intent.stop.description") }
        public static var muteTitle: LocalizedStringResource { resource("intent.mute.title") }
        public static var muteDescription: LocalizedStringResource { resource("intent.mute.description") }
    }

    public enum Activity {
        /// For example "iPhone Microphone"
        public static func builtInInput(_ device: String) -> String { format("activity.input.built-in", device) }
        public static var udp: String { string("activity.transport.udp") }
        public static var tcp: String { string("activity.transport.tcp") }
    }

    public enum Input {
        public static var automatic: String { string("input.automatic") }
        public static var bottom: String { string("input.bottom") }
        public static var front: String { string("input.front") }
        public static var back: String { string("input.back") }
        public static var unavailable: String { string("input.unavailable") }
    }

    public enum Dim {
        public static var button: String { string("dim.button") }
        public static var wake: String { string("dim.wake") }
    }
}
