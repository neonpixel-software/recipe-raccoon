import Foundation

/// Parses the model's amount string into a number. The on-device model copies quantities
/// as written ("1/2", "1 ½", "100g") and gets its own fraction arithmetic wrong (issue #76),
/// so fractions are resolved here rather than asked of the model.
enum IngredientAmountParser {
    struct ParsedAmount: Equatable {
        let value: Double
        /// A unit written straight after the number, as in "100g" or "250 ml".
        let unit: String?
    }

    private static let vulgarFractions: [Character: Double] = [
        "½": 1.0 / 2, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "¼": 1.0 / 4, "¾": 3.0 / 4,
        "⅕": 1.0 / 5, "⅖": 2.0 / 5, "⅗": 3.0 / 5, "⅘": 4.0 / 5, "⅙": 1.0 / 6,
        "⅚": 5.0 / 6, "⅛": 1.0 / 8, "⅜": 3.0 / 8, "⅝": 5.0 / 8, "⅞": 7.0 / 8,
    ]

    /// Accepts "2", "1.5", "2,5", "1/2", "1 1/2", "½", "1½", "1 ½", optionally followed by a
    /// unit ("100g", "1/2 cup", "1/2 fl oz"). Returns nil for anything else, including ranges
    /// ("2-3"), words ("a few") and amounts that aren't positive. Compound amounts ("1 cup plus 2 tablespoons") are not supported:
    /// the model returns a single, usually wrong, number for them, and the user corrects it
    /// on the review screen.
    static func parse(_ text: String) -> ParsedAmount? {
        let normalized = text
            .replacingOccurrences(of: "\u{2044}", with: "/") // fraction slash, as in "1⁄2"
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var quantityText = normalized
        var unit: String?
        if let unitStart = normalized.firstIndex(where: \.isLetter) {
            let unitText = normalized[unitStart...].trimmingCharacters(in: .whitespaces)
            guard unitText.allSatisfy({ $0.isLetter || $0 == "." || $0.isWhitespace }) else { return nil }
            quantityText = String(normalized[..<unitStart])
            unit = unitText
        }

        guard let value = quantity(quantityText.trimmingCharacters(in: .whitespaces)),
              value.isFinite, value > 0 else { return nil }
        return ParsedAmount(value: value, unit: unit)
    }

    private static func quantity(_ text: String) -> Double? {
        if let decimal = Double(text) {
            return decimal
        }
        // A decimal comma, as German, French and Dutch recipes write it ("2,5"). Three digits
        // after the comma read as a thousands separator ("1,000"), so those are rejected.
        if text.range(of: #"^\d+,\d{1,2}$"#, options: .regularExpression) != nil {
            return Double(text.replacingOccurrences(of: ",", with: "."))
        }
        if let last = text.last, let fraction = vulgarFractions[last] {
            let whole = text.dropLast().trimmingCharacters(in: .whitespaces)
            if whole.isEmpty {
                return fraction
            }
            return UInt(whole).map { Double($0) + fraction }
        }
        let parts = text.split(whereSeparator: \.isWhitespace)
        switch parts.count {
        case 1:
            return simpleFraction(parts[0])
        case 2:
            guard let whole = UInt(parts[0]), let fraction = simpleFraction(parts[1]) else { return nil }
            return Double(whole) + fraction
        default:
            return nil
        }
    }

    private static func simpleFraction(_ text: Substring) -> Double? {
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let numerator = UInt(parts[0]),
              let denominator = UInt(parts[1]),
              denominator > 0 else { return nil }
        return Double(numerator) / Double(denominator)
    }
}
