import XCTest
@testable import VoiceLauncherCore

final class PhraseMatcherTests: XCTestCase {
    private let threshold = 0.8
    private let start = Command(phrase: "hey mac start tracking", action: .openApp)
    private let restart = Command(phrase: "hey mac restart tracking", action: .restartApp)

    func testWordsDropPunctuationAndCase() {
        XCTAssertEqual(PhraseMatcher.words("Hey, Mac! Start   tracking."), ["hey", "mac", "start", "tracking"])
    }

    func testWordsFoldYoIntoYe() {
        XCTAssertEqual(PhraseMatcher.words("\u{0401}\u{0436}"), PhraseMatcher.words("\u{0435}\u{0436}"))
    }

    func testExactPhraseMatches() {
        let match = PhraseMatcher.bestMatch(in: "Hey Mac start tracking", commands: [start], threshold: threshold)
        XCTAssertEqual(match?.score, 1)
    }

    func testSmallRecognitionDifferenceStillMatches() {
        let match = PhraseMatcher.bestMatch(in: "hey mac start trackin", commands: [start], threshold: threshold)
        XCTAssertNotNil(match)
    }

    func testPhraseInsideLongerSpeechMatches() {
        let match = PhraseMatcher.bestMatch(
            in: "so I was saying hey mac start tracking please", commands: [start], threshold: threshold)
        XCTAssertNotNil(match)
    }

    func testUnrelatedSpeechDoesNotMatch() {
        let match = PhraseMatcher.bestMatch(
            in: "the tracking numbers are on the invoice", commands: [start], threshold: threshold)
        XCTAssertNil(match)
    }

    func testPartialPhraseDoesNotMatch() {
        XCTAssertNil(PhraseMatcher.bestMatch(in: "hey mac", commands: [start], threshold: threshold))
    }

    func testCloserPhraseWinsBetweenSimilarCommands() {
        let match = PhraseMatcher.bestMatch(
            in: "hey mac restart tracking", commands: [start, restart], threshold: threshold)
        XCTAssertEqual(match?.command, restart)
    }

    func testDisabledCommandIsIgnored() {
        var disabled = start
        disabled.enabled = false
        XCTAssertNil(PhraseMatcher.bestMatch(in: "hey mac start tracking", commands: [disabled], threshold: threshold))
    }
}
