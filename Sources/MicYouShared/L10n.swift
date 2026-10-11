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
        public static var failed: String { string("status.failed") }
        public static func ready(_ name: String) -> String { format("status.ready", name) }
        public static var duration: String { string("status.duration") }
        public static var formatLabel: String { string("status.format") }
        public static var bitrate: String { string("status.bitrate") }
        public static var inputLevel: String { string("status.input-level") }
        public static var transport: String { string("status.transport") }
        /// Short form of forward error correction for the stats tile
        public static var fec: String { string("status.fec") }
        public static var mutedDetail: String { string("status.muted-detail") }
        public static var reconnectDetail: String { string("status.reconnect-detail") }
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
        public static var targetLabel: String { string("home.target.label") }
        public static var noTarget: String { string("home.target.none") }
        public static var change: String { string("home.target.change") }
        public static var chooseComputer: String { string("home.choose") }
        public static var hint: String { string("home.hint") }
        public static var formatHeader: String { string("home.format") }
        public static var adjust: String { string("home.format.adjust") }
    }

    public enum Settings {
        public static var appliesNextTime: String { string("settings.applies-next-time") }
        public static var presets: String { string("settings.preset") }
        public static var presetLowLatency: String { string("settings.preset.low-latency") }
        public static var presetStable: String { string("settings.preset.stable") }
        public static var presetLossless: String { string("settings.preset.lossless") }
        public static var presetFooter: String { string("settings.preset.footer") }
        public static var connection: String { string("settings.connection") }
        public static var transport: String { string("settings.transport") }
        public static var tcpUDP: String { string("settings.transport.tcp-udp") }
        public static var tcpOnly: String { string("settings.transport.tcp") }
        public static var fec: String { string("settings.fec") }
        public static var autoReconnect: String { string("settings.auto-reconnect") }
        public static var connectionFooter: String { string("settings.connection.footer") }
        public static var audio: String { string("settings.audio") }
        public static var codec: String { string("settings.codec") }
        public static var opus: String { string("settings.codec.opus") }
        public static var pcm: String { string("settings.codec.pcm") }
        public static var pcmShort: String { string("settings.codec.pcm-short") }
        public static var bitrate: String { string("settings.bitrate") }
        public static var sampleRate: String { string("settings.sample-rate") }
        public static var channels: String { string("settings.channels") }
        public static var opusNo44Footer: String { string("settings.audio.footer-opus-44") }
        public static var audioFooter: String { string("settings.audio.footer") }
        public static var microphone: String { string("settings.microphone") }
        public static var inputGain: String { string("settings.input-gain") }
        public static var inputGainFooter: String { string("settings.input-gain.footer") }
        public static var voiceProcessing: String { string("settings.voice-processing") }
        public static var voiceProcessingFooter: String { string("settings.voice-processing.footer") }
        public static var general: String { string("settings.general") }
        public static var keepScreenOn: String { string("settings.keep-screen-on") }
        public static var liveActivity: String { string("settings.live-activity") }
        public static var generalFooter: String { string("settings.general.footer") }
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
        public static var feedbackFooter: String { string("about.feedback.footer") }
        public static var community: String { string("about.community") }
        public static var qqGroup: String { string("about.qq") }
        public static var telegram: String { string("about.telegram") }
        public static var discussions: String { string("about.discussions") }
        public static var website: String { string("about.website") }
        public static var project: String { string("about.project") }
        public static var quickStart: String { string("about.quick-start") }
        public static var desktop: String { string("about.desktop") }
        public static var sourceCode: String { string("about.source-code") }
        public static var releases: String { string("about.releases") }
        public static var acknowledgements: String { string("about.acknowledgements") }
        public static var license: String { string("about.license") }
        public static var notice: String { string("about.notice") }
        public static var footer: String { string("about.footer") }
    }

    public enum Credits {
        public static var license: String { string("credits.license") }
        public static var thanks: String { string("credits.thanks") }
        public static var footer: String { string("credits.footer") }
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
        public static var timeout: String { string("error.timeout") }
        public static var handshake: String { string("error.handshake") }
        public static var heartbeat: String { string("error.heartbeat") }
        public static var closedByPeer: String { string("error.closed") }
        public static func unexpectedData(_ detail: String) -> String { format("error.unexpected-data", detail) }
        public static var noPeerAddress: String { string("error.no-peer-address") }
        public static var udpFailed: String { string("error.udp") }
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

    public enum Control {
        public static var name: LocalizedStringResource { resource("app.name") }
        public static var description: LocalizedStringResource { resource("control.description") }
    }
}
