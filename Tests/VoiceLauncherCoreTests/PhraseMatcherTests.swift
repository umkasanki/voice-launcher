import XCTest
@testable import VoiceLauncherCore

final class PhraseMatcherTests: XCTestCase {
    private let threshold = 0.8
    private let start = Command(phrase: "hey mac start tracking", action: .openApp)
    private let restart = Command(phrase: "hey mac restart tracking", action: .restartApp)

    func testWordsDropPunctuationAndCase() {
        XCTAssertEqual(PhraseMatcher.words("Hey, Mac! Start   tracking."), PhraseMatcher.words("hey mac start tracking"))
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

    // MARK: Key phrase

    private let off = Command(phrase: "hey mac stop tracking", action: .quitApp)

    func testKeyPhraseIsRequired() {
        XCTAssertNil(PhraseMatcher.bestMatch(in: "stop tracking", commands: [off], threshold: 0.9, keyPhrase: "hey mac"))
    }

    func testKeyPhraseMustComeRightBeforeTheCommand() {
        XCTAssertNil(PhraseMatcher.bestMatch(
            in: "hey mac how are you stop tracking", commands: [off], threshold: 0.9, keyPhrase: "hey mac"))
    }

    func testKeyPhraseThenCommandMatches() {
        let match = PhraseMatcher.bestMatch(
            in: "well hey mac stop tracking please", commands: [off], threshold: 0.9, keyPhrase: "hey mac")
        XCTAssertEqual(match?.command, off)
    }

    func testCommandPhraseWithoutKeyPhraseAlsoWorks() {
        let bare = Command(phrase: "stop tracking", action: .quitApp)
        XCTAssertNotNil(PhraseMatcher.bestMatch(in: "hey mac stop tracking", commands: [bare], threshold: 0.9, keyPhrase: "hey mac"))
    }

    // MARK: Alphabets and ambiguity

    func testLatinAndCyrillicSpellingsMatch() {
        // The recogniser may write a name in Latin letters: "Mac" for its Cyrillic spelling.
        XCTAssertEqual(PhraseMatcher.words("Mac"), PhraseMatcher.words("\u{041C}\u{0430}\u{043A}"))
    }

    func testTooCloseToCallFiresNothing() {
        let a = Command(phrase: "hey mac turn on", action: .openApp)
        let b = Command(phrase: "hey mac turn one", action: .quitApp)
        XCTAssertNil(PhraseMatcher.bestMatch(in: "hey mac turn onn", commands: [a, b], threshold: 0.8))
    }

    func testExactTieFiresNothing() {
        let a = Command(phrase: "hey mac start", action: .openApp)
        let b = Command(phrase: "hey mac start", action: .quitApp)
        XCTAssertNil(PhraseMatcher.bestMatch(in: "hey mac start", commands: [a, b], threshold: 0.8))
    }

    func testCyrillicTsAndChStayDistinctFromK() {
        // Only a Latin "c" is read as "k"; Cyrillic letters that transliterate to "c" are not.
        let k = PhraseMatcher.words("\u{043A}")
        XCTAssertNotEqual(PhraseMatcher.words("\u{0447}"), k)
        XCTAssertNotEqual(PhraseMatcher.words("\u{0446}"), k)
        XCTAssertEqual(PhraseMatcher.words("c"), k)
    }
}
