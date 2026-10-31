import Foundation

/// Fuzzy comparison of a configured phrase with recognised speech.
///
/// The recogniser rarely hears a phrase letter for letter: a word comes back in
/// another form, a letter is swapped, punctuation and case drift. So both sides
/// are reduced to bare lowercase words, and the phrase is compared — as a string
/// of characters, by edit distance — with every run of consecutive words of
/// about the same length in the transcript. The best run gives the score.
public enum PhraseMatcher {
    public struct Match: Equatable {
        public let command: Command
        public let score: Double
    }

    /// Lowercase words with punctuation dropped and "yo" folded into "ye", so
    /// the recogniser's choice between the two letters does not matter.
    public static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "\u{0451}", with: "\u{0435}")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Similarity in 0...1 of `phrase` to its best-matching run of words in
    /// `transcript`. Runs one word shorter and one word longer than the phrase
    /// are tried too, so a dropped or an extra word costs only its letters.
    public static func score(phrase: [String], in transcript: [String]) -> Double {
        guard !phrase.isEmpty, !transcript.isEmpty else { return 0 }
        let target = phrase.joined(separator: " ")
        var best = similarity(target, transcript.joined(separator: " "))
        for length in max(1, phrase.count - 1)...(phrase.count + 1) where length <= transcript.count {
            for start in 0...(transcript.count - length) {
                let run = transcript[start..<start + length].joined(separator: " ")
                best = max(best, similarity(target, run))
            }
        }
        return best
    }

    /// The enabled command that scores highest against `transcript`, if it
    /// reaches `threshold`. On a tie the longer phrase wins: it is the more
    /// specific of the two.
    public static func bestMatch(in transcript: String, commands: [Command], threshold: Double) -> Match? {
        let heard = words(transcript)
        var best: Match?
        for command in commands where command.enabled {
            let score = score(phrase: words(command.phrase), in: heard)
            guard score >= threshold else { continue }
            if let current = best {
                let better = score > current.score
                    || (score == current.score && command.phrase.count > current.command.phrase.count)
                if !better { continue }
            }
            best = Match(command: command, score: score)
        }
        return best
    }

    public static func similarity(_ a: String, _ b: String) -> Double {
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 1 }
        return 1 - Double(editDistance(Array(a), Array(b))) / Double(longest)
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
