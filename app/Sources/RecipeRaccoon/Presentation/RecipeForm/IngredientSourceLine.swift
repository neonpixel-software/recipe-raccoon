import Foundation

/// The line an ingredient row was loaded from, shown under its fields when the fields don't
/// say the same thing (#215): a compound amount the fields hold as one number, a note such as
/// "butter, softened", or a line the model couldn't split at all. A line that is just its
/// amount, unit and name ("2 cups flour") stays hidden, so a clean recipe stays quiet.
enum IngredientSourceLine {
    /// Words that may sit between the unit and the name ("250 g de farine", "1 cup of milk").
    private static let connectors: Set<String> = ["of", "de", "van"]

    static func shown(for line: IngredientLine) -> String? {
        let text = line.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isComposed(of: line, text: text) else { return nil }
        return text
    }

    /// True when `text` is the line's amount, unit and name in that order and nothing else,
    /// however the amount is written ("1/2", "½", "0.5") and whichever spelling of the unit
    /// it uses ("cups" for "cup", "tbsp" for "tablespoon").
    private static func isComposed(of line: IngredientLine, text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let amount = line.amount else {
            return matchesUnitAndName(words[...], unit: line.unit, name: line.ingredientName)
        }
        // A written amount is one to three words: "2", "1 1/2", "1 ½ cups" is two plus a unit.
        for count in 1...min(3, words.count) {
            let written = words[..<count].joined(separator: " ")
            guard let parsed = IngredientAmountParser.parse(written, unit: line.unit),
                  abs(parsed.value - amount) <= max(1e-6, amount * 0.01) else { continue }
            if let writtenUnit = parsed.unit {
                // A unit glued to the number ("100g") is the line's unit.
                guard let unit = line.unit, isSameUnit(writtenUnit, unit) else { continue }
                if matchesUnitAndName(words[count...], unit: nil, name: line.ingredientName) {
                    return true
                }
            } else if matchesUnitAndName(words[count...], unit: line.unit, name: line.ingredientName) {
                return true
            }
        }
        return false
    }

    private static func matchesUnitAndName(_ words: ArraySlice<String>, unit: String?, name: String?) -> Bool {
        var rest = words
        if let unit {
            let unitWordCount = unit.split(whereSeparator: \.isWhitespace).count
            guard rest.count >= unitWordCount,
                  isSameUnit(rest.prefix(unitWordCount).joined(separator: " "), unit) else { return false }
            rest = rest.dropFirst(unitWordCount)
            if let first = rest.first, connectors.contains(first.lowercased()) {
                rest = rest.dropFirst()
            }
        }
        var remainder = rest.joined(separator: " ")
        // French elides "de" before a vowel: "2 cl d'huile".
        if unit != nil, let elided = ["d'", "d’"].first(where: { remainder.lowercased().hasPrefix($0) }) {
            remainder.removeFirst(elided.count)
        }
        return remainder.compare(name ?? "", options: [.caseInsensitive]) == .orderedSame
    }

    /// The same word ignoring case, or two spellings of one measurement ("cups" and "cup").
    private static func isSameUnit(_ written: String, _ unit: String) -> Bool {
        if written.compare(unit, options: [.caseInsensitive]) == .orderedSame {
            return true
        }
        guard let writtenKind = MeasurementUnits.kind(of: written, standard: .usCustomary),
              writtenKind == MeasurementUnits.kind(of: unit, standard: .usCustomary) else { return false }
        // And the same family, so two units that happen to share a size still differ.
        let writtenRounding = MeasurementUnits.scalingRounding(of: written)
        return writtenRounding == MeasurementUnits.scalingRounding(of: unit)
    }
}
