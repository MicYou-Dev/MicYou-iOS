// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MicYouCore

@Suite struct Samples {
    private func run(_ samples: [Float], gain: Float = 1, duplicate: Bool = false) -> (pcm: [Int16], levelDB: Float, limited: Bool) {
        var processor = SampleProcessor()
        let result = samples.withUnsafeBufferPointer { processor.process($0, gain: gain, duplicate: duplicate) }
        let pcm = result.pcm.withUnsafeBytes { raw in raw.bindMemory(to: Int16.self).map { Int16(littleEndian: $0) } }
        return (pcm, result.levelDB, result.limited)
    }

    @Test func silenceReportsTheFloor() {
        let result = run([0, 0, 0])
        #expect(result.pcm == [0, 0, 0])
        #expect(result.levelDB == SampleProcessor.silence)
        #expect(run([]).levelDB == SampleProcessor.silence)
    }

    @Test func quietSamplesPassUnchanged() {
        let result = run([0.5, -0.5, 0.25])
        #expect(result.pcm == [16384, -16384, 8192])
    }

    @Test func levelIsRMS() {
        let result = run(Array(repeating: 0.5, count: 480))
        #expect(abs(result.levelDB - 20 * log10(0.5)) < 0.01)
    }

    @Test func duplicateWritesEachSampleTwice() {
        #expect(run([0.5, -0.25], duplicate: true).pcm == [16384, 16384, -8192, -8192])
    }

    @Test func gainIsLimitedBelowFullScale() {
        let result = run(Array(repeating: 0.8, count: 100), gain: SampleProcessor.linearGain(dB: 24))
        let ceiling = Int16((PeakLimiter.ceiling * 32767).rounded())
        #expect(result.pcm.allSatisfy { abs(Int($0)) <= Int(ceiling) })
        #expect(result.limited)
        #expect(!run([0.5, -0.5]).limited)
    }
}

@Suite struct Meter {
    @Test func risesQuicklyAndFallsSteadily() {
        let meter = MeterBallistics()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        _ = meter.advance(to: -60, at: start)
        var reading = meter.advance(to: -10, at: start.addingTimeInterval(0.1))
        #expect(reading.level > -12)
        // A tenth of a second at 36 dB per second
        reading = meter.advance(to: -60, at: start.addingTimeInterval(0.2))
        #expect(abs(reading.level - (reading.peak - 3.6)) < 0.5)
    }

    @Test func peakHoldsThenFalls() {
        let meter = MeterBallistics()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        _ = meter.advance(to: -60, at: start)
        var time = 0.0
        var reading = meter.advance(to: 0, at: start)
        for _ in 0..<5 {
            time += 0.1
            reading = meter.advance(to: 0, at: start.addingTimeInterval(time))
        }
        let peak = reading.peak
        time += 0.1
        reading = meter.advance(to: -60, at: start.addingTimeInterval(time))
        #expect(reading.peak == peak)
        // One second of hold, then 60 dB at 18 dB per second
        for _ in 0..<50 {
            time += 0.1
            reading = meter.advance(to: -60, at: start.addingTimeInterval(time))
        }
        #expect(reading.isSettled)
        #expect(reading.level == MeterBallistics.floor)
        #expect(reading.peak == MeterBallistics.floor)
    }
}
