import Foundation

/// Checks the number of servings the model read against the source text (Phase 15.2). The
/// ingredient check (`IngredientDescriptors.appears`) is too weak for this: a bare "4" occurs in
/// almost any recipe ("bake for 4 minutes", step 4, "4 eggs"). So the number has to be stated as
/// servings: next to a servings word, right after a yield word, or after "for" in a short line of
/// its own ("Voor 12 muffins"). A range ("4–6 personen") gives its lower number.
enum CapturedServings {
    /// Servings words in the languages the app ships in (en, nl, de, fr, es), folded, matched
    /// before or after the number.
    private static let servingsWords = [
        "serves", "serving", "servings", "portion", "portions", "people", "persons",
        "personen", "porties", // Dutch
        "portionen", // German ("Portion" and "Personen" are above)
        "personne", "personnes", // French
        "persona", "personas", "racion", "raciones", "porcion", "porciones", "comensales", // Spanish
    ]

    /// French "parts" ("6 grandes parts") counts after the number only, so "Part 2: Assembly"
    /// doesn't. The singular is left out for "1 part vermouth".
    private static let servingsWordsAfterNumber = servingsWords + ["parts"]

    /// Words a yield follows directly ("Makes 12 muffins", "Yield: 1 loaf").
    private static let yieldWords = ["makes", "yield", "yields", "ergibt", "rinde"]

    /// Words for "for" that state servings at the start of a line ("Für 4 Personen").
    private static let forWords = ["for", "voor", "fur", "pour", "para"]

    /// Energy units, which follow a number after "serving" in nutrition facts ("Per serving: 99
    /// kcal"). Grams and other measures are in `IngredientDescriptors`.
    private static let energyUnits: Set<String> = ["kcal", "cal", "calorie", "calories", "kj", "kilojoule", "kilojoules"]

    /// A whole number of one or two digits, optionally a range, that isn't part of a longer or
    /// decimal number. Group 1 is the first number, group 2 the range's end.
    private static let number = #"(?<![\d]|\d[.,])(\d{1,2})(?:\s*[-–—]\s*(\d{1,2}))?(?![\d]|[.,]\d)"#

    /// A pattern for stated servings, and whether the word after the number (group 3, if the
    /// pattern has one) rules the match out.
    private struct Rule: Sendable {
        let pattern: String
        var rejectsNextWord: @Sendable (String) -> Bool = { _ in false }
    }

    private struct StatedServings {
        /// The numbers written in the source: both ends of a range.
        let numbers: [Int]
        /// The servings they stand for: a range's lower end.
        let servings: Int
    }

    private static let rules: [Rule] = {
        let word = #"[^\s\d]+\s+"#
        return [
            // "4 servings", "4–6 personen", "6 grandes parts", "pour 6 personnes"
            Rule(pattern: number + #"\s+(?:"# + word + #")?"# + alternation(servingsWordsAfterNumber)),
            // "Serves 4", "Servings: 4", "Serves about 6", "Personen: 4-6"; not "Per serving: 99
            // kcal" or "Serving size: 1 cup".
            Rule(
                pattern: alternation(servingsWords) + #"\s*:?\s*(?:"# + word + #")?"# + number + #"(?:[ \t]*(\p{L}+))?"#,
                rejectsNextWord: { energyUnits.contains($0) || IngredientDescriptors.isMeasurementUnit($0) }
            ),
            // "Makes 12 muffins", "Yield: 1 loaf"
            Rule(pattern: alternation(yieldWords) + #"\s*:?\s*"# + number),
            // "Voor 12 muffins" as a short line of its own: at most two words after the number, and
            // not a time unit ("For 4 minutes"). "For 4, stir well." and "For 4 large eggs,
            // separate the yolks." are sentences, not a heading.
            Rule(
                pattern: #"^[ \t]*"# + alternation(forWords) + #"[ \t]+"# + number
                    + #"(?:[ \t]+(\p{L}+))?(?:[ \t]+\p{L}+)?[ \t]*[:.!]?[ \t]*$"#,
                rejectsNextWord: IngredientDescriptors.isTimeUnit
            ),
        ]
    }()

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

    /// Every number `source` states as servings.
    private static func statedServings(in source: String) -> [StatedServings] {
        let text = source.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var result: [StatedServings] = []
        for rule in rules {
            for groups in matches(of: rule.pattern, in: text) {
                if let stated = stated(by: groups, rule: rule) {
                    result.append(stated)
                }
            }
        }
        return result
    }

    private static func stated(by groups: [String?], rule: Rule) -> StatedServings? {
        guard let first = groups[0].flatMap(Int.init) else { return nil }
        if groups.count > 2, let next = groups[2], rule.rejectsNextWord(next) {
            return nil
        }
        let numbers = [first] + (groups[1].flatMap(Int.init).map { [$0] } ?? [])
        let lowest = numbers.min() ?? first
        return Recipe.servingsRange.contains(lowest) ? StatedServings(numbers: numbers, servings: lowest) : nil
    }

    /// A pattern matching any of `words` as a whole word.
    private static func alternation(_ words: [String]) -> String {
        #"(?<!\p{L})(?:"# + words.joined(separator: "|") + #")(?!\p{L})"#
    }

    /// The capture groups (after the whole match) of each match of `pattern` in `text`.
    private static func matches(of pattern: String, in text: String) -> [[String?]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        var result: [[String?]] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            var groups: [String?] = []
            for index in 1..<match.numberOfRanges {
                groups.append(Range(match.range(at: index), in: text).map { String(text[$0]) })
            }
            result.append(groups)
        }
        return result
    }
}
