// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import MicYouCore

@Suite struct Versions {
    @Test func parsesTagsAndPlainNumbers() {
        #expect(AppVersion("v1.2.0")?.parts == [1, 2, 0])
        #expect(AppVersion("1.1.1")?.parts == [1, 1, 1])
        #expect(AppVersion(" 2 ")?.parts == [2])
    }

    @Test(arguments: ["", "v", "Protocol-2.0.0-1", "1..2", "1.2.0-beta", "1.-2"])
    func rejectsOtherTags(_ text: String) {
        #expect(AppVersion(text) == nil)
    }

    @Test func comparesNumericallyNotAlphabetically() {
        #expect(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        #expect(AppVersion("2.0")! > AppVersion("1.99.99")!)
        #expect(AppVersion("1.2")! == AppVersion("1.2.0")!)
        #expect(!(AppVersion("1.1.1")! < AppVersion("1.1.1")!))
    }
}

@Suite struct Releases {
    @Test func readsTheGitHubAPI() throws {
        let json = #"{"tag_name":"v1.2.0","name":"1.2.0","html_url":"https://github.com/MicYou-Dev/MicYou-iOS/releases/tag/v1.2.0","draft":false,"prerelease":false,"body":"notes"}"#
        let release = try AppRelease(githubJSON: Data(json.utf8))
        #expect(release.version == AppVersion("1.2.0"))
        #expect(release.page.absoluteString == "https://github.com/MicYou-Dev/MicYou-iOS/releases/tag/v1.2.0")
        #expect(release.isNewer(than: AppVersion("1.1.1")!))
        #expect(!release.isNewer(than: AppVersion("1.2.0")!))
        #expect(release.notes?.blocks == [.paragraph("notes")])
    }

    @Test func emptyBodyHasNoNotes() throws {
        let json = ###"{"tag_name":"v1.2.0","html_url":"https://example.com","body":"## Files\n\n- `MicYou.ipa`"}"###
        #expect(try AppRelease(githubJSON: Data(json.utf8)).notes == nil)
        let noBody = #"{"tag_name":"v1.2.0","html_url":"https://example.com","body":null}"#
        #expect(try AppRelease(githubJSON: Data(noBody.utf8)).notes == nil)
    }

    @Test func rejectsPrereleasesAndOtherTags() {
        let prerelease = #"{"tag_name":"v2.0.0","html_url":"https://example.com","prerelease":true}"#
        let protocolTag = #"{"tag_name":"Protocol-2.0.0-1","html_url":"https://example.com"}"#
        #expect(throws: (any Error).self) { try AppRelease(githubJSON: Data(prerelease.utf8)) }
        #expect(throws: (any Error).self) { try AppRelease(githubJSON: Data(protocolTag.utf8)) }
    }

    @Test func readsTheWebsiteRedirect() {
        let url = URL(string: "https://github.com/MicYou-Dev/MicYou-iOS/releases/tag/v1.2.0")!
        #expect(AppRelease(redirectedTo: url)?.version == AppVersion("1.2.0"))
        // Not redirected, for example when GitHub has no release at all
        #expect(AppRelease(redirectedTo: URL(string: "https://github.com/MicYou-Dev/MicYou-iOS/releases")!) == nil)
    }

    @Test func checksOnceADay() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(UpdateSchedule.isDue(lastCheck: nil, now: now))
        #expect(!UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(-UpdateSchedule.interval), now: now))
        #expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }
}

@Suite struct Notes {
    @Test func keepsChangesAndDropsFiles() {
        let body = """
        ## Changes\r
        \r
        - feat: check GitHub Releases for a new version\r
        - fix: keep `AVAudioSession` active\r
        \r
        ## Files\r
        \r
        - `MicYou-*.ipa` unsigned\r
        - `SHA256SUMS.txt` checksums of both\r
        """
        #expect(ReleaseNotes(markdown: body).blocks == [
            .item("check GitHub Releases for a new version", kind: .feat),
            .item("keep `AVAudioSession` active", kind: .fix),
        ])
    }

    @Test func keepsHeadingsWhenThereAreSeveral() {
        let body = "# Highlights\nUSB connections\nand link stats.\n\n## Fixes\n* one\n  continued\n+ two"
        #expect(ReleaseNotes(markdown: body).blocks == [
            .heading("Highlights"),
            .paragraph("USB connections and link stats."),
            .heading("Fixes"),
            .item("one continued"),
            .item("two"),
        ])
    }

    @Test func splitsCommitTypes() {
        let body = "- feat(ui)!: new look\n- Fix: case\n- ref(ui): unknown type\n- docs:\n- note: plain text\n- no colon"
        #expect(ReleaseNotes(markdown: body).blocks == [
            .item("new look", kind: .feat),
            .item("case", kind: .fix),
            .item("ref(ui): unknown type"),
            .item("docs:"),
            .item("note: plain text"),
            .item("no colon"),
        ])
    }

    @Test func emptyBody() {
        #expect(ReleaseNotes(markdown: "").isEmpty)
        #expect(ReleaseNotes(markdown: "## Files\n- a").isEmpty)
    }
}
