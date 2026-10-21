import Foundation

/// Formats a stored amount for the form's Amount field the way cooks write it: "1⅔" rather
/// than "1.6666666666666665" (issue #87). The output reads back through
/// IngredientAmountParser, so an untouched field saves the same value.
enum IngredientAmountFormatter {
    /// Halves, thirds, quarters and eighths — the fractions recipes actually use.
    private static let commonFractions: [(value: Double, glyph: String)] = [
        (1.0 / 8, "⅛"), (1.0 / 4, "¼"), (1.0 / 3, "⅓"), (3.0 / 8, "⅜"), (1.0 / 2, "½"),
        (5.0 / 8, "⅝"), (2.0 / 3, "⅔"), (3.0 / 4, "¾"), (7.0 / 8, "⅞"),
    ]
    private static let tolerance = 1e-6

    static func format(_ amount: Double) -> String {
        // The whole/fraction split below assumes a positive amount the parser would accept.
        // The parser never stores anything else, but show one faithfully rather than as
        // "-1½" (for -0.5) or "0" (for 1e-7).
        guard amount.isFinite, amount >= tolerance else { return String(amount) }

        let whole = amount.rounded(.down)
        let fraction = amount - whole
        let wholeText = String(format: "%.0f", whole)

        if fraction < tolerance {
            return wholeText
        }
        if let match = commonFractions.first(where: { abs($0.value - fraction) < tolerance }) {
            return whole == 0 ? match.glyph : wholeText + match.glyph
        }

        // Anything else gets at most two decimals, without trailing zeros ("0.3", "1.25").
        var decimal = String(format: "%.2f", amount)
        while decimal.hasSuffix("0") {
            decimal.removeLast()
        }
        if decimal.hasSuffix(".") {
            decimal.removeLast()
        }
        // Rounding a tiny amount to "0" would lose it, since the parser rejects zero.
        return decimal == "0" ? String(amount) : decimal
    }
}
