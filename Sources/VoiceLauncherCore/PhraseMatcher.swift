import Foundation

/// Fuzzy comparison of a configured phrase with recognised speech.
///
/// The recogniser rarely hears a phrase letter for letter: a word comes back in
/// another form, a letter is swapped, punctuation and case drift, and a name may
/// come back in Latin letters ("Mac" for its Cyrillic spelling). So both sides
/// are reduced to bare lowercase Latin words, and the phrase is compared — as a
/// string of characters, by edit distance — with every run of consecutive words
/// of about the same length in the transcript. The best run gives the score.
///
/// With a key phrase set, a command fires only when the key phrase is heard and
/// the command's own words follow it directly. Each part is scored on its own,
/// so a short difference such as one prefix weighs as much as it should instead
/// of being diluted by the shared key phrase.
public enum PhraseMatcher {
    public struct Match: Equatable {
        public let command: Command
        public let score: Double
    }

    /// Lowercase words in Latin letters, punctuation dropped. Transliteration
    /// makes the recogniser's choice of alphabet irrelevant; "c" is folded into
    /// "k" because the two spell the same sound in transliterated names.
    public static func words(_ text: String) -> [String] {
        let latin = text.lowercased()
            .replacingOccurrences(of: "\u{0451}", with: "\u{0435}")
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? text.lowercased()
        return latin
            .replacingOccurrences(of: "c", with: "k")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Similarity in 0...1 of `phrase` to its best-matching run of words in
    /// `transcript`. Runs one word shorter and one word longer than the phrase
    /// are tried too, so a dropped or an extra word costs only its letters.
    public static func score(phrase: [String], in transcript: [String]) -> Double {
        guard !phrase.isEmpty, !transcript.isEmpty else { return 0 }
        var best = similarity(phrase, transcript[...])
        for start in transcript.indices {
            best = max(best, bestRun(of: phrase, in: transcript, from: start).score)
        }
        return best
    }

    /// The score of `command` against `transcript`, honouring the key phrase.
    /// A command phrase that already begins with the key phrase has it dropped,
    /// so phrases typed either way behave the same.
    public static func score(command phrase: String, keyPhrase: String, in transcript: String) -> Double {
        let heard = words(transcript)
        let key = words(keyPhrase)
        var body = words(phrase)
        guard !key.isEmpty else { return score(phrase: body, in: heard) }

        if body.count > key.count, similarity(key, body[0..<key.count]) >= 0.8 {
            body.removeFirst(key.count)
        }
        guard !body.isEmpty, !heard.isEmpty else { return 0 }

        var best = 0.0
        for start in heard.indices {
            let keyRun = bestRun(of: key, in: heard, from: start)
            guard keyRun.score > best, keyRun.end < heard.count else { continue }
            let bodyRun = bestRun(of: body, in: heard, from: keyRun.end)
            best = max(best, min(keyRun.score, bodyRun.score))
        }
        return best
    }

    /// The enabled command that scores highest against `transcript`, if it
    /// reaches `threshold` and is clearly ahead of the runner-up. Two commands
    /// within `margin` of each other — "on" and "off" said indistinctly — are
    /// too close to call, and nothing fires. On an exact tie the longer phrase
    /// wins: it is the more specific of the two.
    public static func bestMatch(in transcript: String, commands: [Command], threshold: Double,
                                 keyPhrase: String = "", margin: Double = 0.05) -> Match? {
        var best: Match?
        var runnerUp = 0.0
        for command in commands where command.enabled {
            let score = score(command: command.phrase, keyPhrase: keyPhrase, in: transcript)
            guard score >= threshold else { continue }
            if let current = best {
                let better = score > current.score
                    || (score == current.score && command.phrase.count > current.command.phrase.count)
                if !better {
                    runnerUp = max(runnerUp, score)
                    continue
                }
                runnerUp = max(runnerUp, current.score)
            }
            best = Match(command: command, score: score)
        }
        if let best, runnerUp > 0, best.score - runnerUp < margin { return nil }
        return best
    }

    public static func similarity(_ a: String, _ b: String) -> Double {
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 1 }
        return 1 - Double(editDistance(Array(a), Array(b))) / Double(longest)
    }

    /// The best run of words starting exactly at `start`, one word shorter to
    /// one word longer than `phrase`, and the index just past it.
    private static func bestRun(of phrase: [String], in transcript: [String], from start: Int)
        -> (score: Double, end: Int) {
        var best = (score: 0.0, end: start)
        for length in max(1, phrase.count - 1)...(phrase.count + 1) where start + length <= transcript.count {
            let score = similarity(phrase, transcript[start..<start + length])
            if score > best.score { best = (score, start + length) }
        }
        return best
    }

    private static func similarity(_ phrase: [String], _ run: ArraySlice<String>) -> Double {
        similarity(phrase.joined(separator: " "), run.joined(separator: " "))
    }

    static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
