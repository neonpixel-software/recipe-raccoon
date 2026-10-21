import Foundation

/// Checks the number of servings the model read against the source text (Phase 15.2). The
/// ingredient check (`IngredientDescriptors.appears`) is too weak for this: a bare "4" occurs in
/// almost any recipe ("bake for 4 minutes", step 4, "4 eggs"). So the number has to be stated as
/// servings: next to a servings word, right after a yield word, or after "for" at the start of a
/// line ("Voor 12 muffins"). A range ("4–6 personen") gives its lower number.
enum CapturedServings {
    /// Servings words in the languages the app ships in (en, nl, de, fr, es), folded.
    private static let servingsWords = [
        "serves", "serving", "servings", "portion", "portions", "people", "persons",
        "personen", "porties", // Dutch
        "portionen", // German ("Portion" and "Personen" are above)
        "personne", "personnes", "part", "parts", // French
        "persona", "personas", "racion", "raciones", "porcion", "porciones", "comensales", // Spanish
    ]

    /// Words a yield follows directly ("Makes 12 muffins", "Yield: 1 loaf").
    private static let yieldWords = ["makes", "yield", "yields", "ergibt", "rinde"]

    /// Words for "for" that state servings at the start of a line ("Für 4 Personen").
    private static let forWords = ["for", "voor", "fur", "pour", "para"]

    /// A whole number of one or two digits, optionally a range, that isn't part of a longer or
    /// decimal number. Group 1 is the first number, group 2 the range's end.
    private static let number = #"(?<![\d]|\d[.,])(\d{1,2})(?:\s*[-–—]\s*(\d{1,2}))?(?![\d]|[.,]\d)"#

    /// The servings in `candidate` (the model's answer, e.g. "4", "4-6" or "12 muffins") if
    /// `source` states that number as servings, else nil. Without a source the number is only
    /// checked against `Recipe.servingsRange`.
    static func grounded(_ candidate: String, in source: String?) -> Int? {
        guard let value = firstNumber(in: candidate) else { return nil }
        guard let source else {
            return Recipe.servingsRange.contains(value) ? value : nil
        }
        return statedServings(in: source).first { $0.numbers.contains(value) }?.servings
    }

    private static func firstNumber(in text: String) -> Int? {
        guard let range = text.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(text[range])
    }

    /// Every number `source` states as servings, with the numbers written there (both ends of a
    /// range) and the servings they stand for (a range's lower end).
    private static func statedServings(in source: String) -> [(numbers: [Int], servings: Int)] {
        let text = source.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let servings = alternation(servingsWords)
        let word = #"[^\s\d]+\s+"#
        let patterns = [
            // "4 servings", "4–6 personen", "6 grandes parts", "pour 6 personnes"
            number + #"\s+(?:"# + word + #")?"# + servings,
            // "Serves 4", "Servings: 4", "Serves about 6", "Personen: 4-6"
            servings + #"\s*:?\s*(?:"# + word + #")?"# + number,
            // "Makes 12 muffins", "Yield: 1 loaf"
            alternation(yieldWords) + #"\s*:?\s*"# + number,
            // "Voor 12 muffins" at the start of a line; a time unit after it is checked below.
            #"^[ \t]*"# + alternation(forWords) + #"\s+"# + number + #"(?:\s+(\p{L}+))?"#,
        ]
        return patterns.flatMap { pattern in
            matches(of: pattern, in: text).compactMap { groups -> (numbers: [Int], servings: Int)? in
                guard let first = groups[0].flatMap(Int.init) else { return nil }
                if groups.count > 2, let next = groups[2], IngredientDescriptors.isTimeUnit(next) {
                    return nil
                }
                let numbers = [first] + (groups[1].flatMap(Int.init).map { [$0] } ?? [])
                let lowest = numbers.min() ?? first
                return Recipe.servingsRange.contains(lowest) ? (numbers, lowest) : nil
            }
        }
    }

    /// A pattern matching any of `words` as a whole word.
    private static func alternation(_ words: [String]) -> String {
        #"(?<!\p{L})(?:"# + words.joined(separator: "|") + #")(?!\p{L})"#
    }

    /// The capture groups (after the whole match) of each match of `pattern` in `text`.
    private static func matches(of pattern: String, in text: String) -> [[String?]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
        }
    }
}
