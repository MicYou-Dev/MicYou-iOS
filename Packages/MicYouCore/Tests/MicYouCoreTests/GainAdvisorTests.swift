// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MicYouCore

@Suite struct GainAdvice {
    /// Meter updates at 30 Hz from `start` for `seconds`
    private func feed(_ advisor: inout GainAdvisor, from start: TimeInterval, seconds: TimeInterval,
                      level: Float, limited: (Int) -> Bool = { _ in false }) -> GainAdvisor.Advice? {
        var advice: GainAdvisor.Advice?
        for i in 0..<Int(seconds * 30) {
            advice = advisor.record(levelDB: level, limited: limited(i), at: start + Double(i) / 30)
        }
        return advice
    }

    @Test func steadyLimitingAsksForLessGain() {
        var advisor = GainAdvisor()
        #expect(feed(&advisor, from: 0, seconds: 1, level: -3, limited: { $0 % 3 == 0 }) == .lower)
    }

    @Test func aShortPeakIsIgnored() {
        var advisor = GainAdvisor()
        #expect(feed(&advisor, from: 0, seconds: 2, level: -20, limited: { $0 < 3 }) == nil)
    }

    @Test func loweringHoldsBetweenPhrasesThenClears() {
        var advisor = GainAdvisor()
        _ = feed(&advisor, from: 0, seconds: 1, level: -3, limited: { _ in true })
        #expect(feed(&advisor, from: 1, seconds: 3, level: -25) == .lower)
        #expect(feed(&advisor, from: 4, seconds: 3, level: -25) == nil)
    }

    @Test func quietSpeechAsksForMoreGainAfterAWindow() {
        var advisor = GainAdvisor()
        #expect(feed(&advisor, from: 0, seconds: 5, level: -44) == nil)
        #expect(feed(&advisor, from: 5, seconds: 6, level: -44) == .raise)
        // Speaking up clears it once the next window is done
        #expect(feed(&advisor, from: 11, seconds: 11, level: -20) == nil)
    }

    @Test func silenceAndNormalSpeechAreLeftAlone() {
        var silent = GainAdvisor()
        #expect(feed(&silent, from: 0, seconds: 12, level: -60) == nil)
        var normal = GainAdvisor()
        #expect(feed(&normal, from: 0, seconds: 12, level: -22) == nil)
    }
}
