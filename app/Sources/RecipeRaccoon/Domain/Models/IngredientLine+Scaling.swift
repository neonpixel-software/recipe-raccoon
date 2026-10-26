import Foundation

extension IngredientLine {
    /// The line for `factor` times the recipe's servings (Phase 15.3), shown on the recipe screen
    /// only: the saved recipe never changes. `amount` is the exact scaled amount, so weights
    /// come from it, and `rawText` shows it rounded to what a cook can measure
    /// (`IngredientAmountRounding`). A line without an amount ("salt to taste") stays as it is.
    func scaled(by factor: Double) -> IngredientLine {
        guard let amount, amount > 0, factor > 0, factor != 1 else { return self }
        let exact = amount * factor
        let shown = IngredientAmountFormatter.format(IngredientAmountRounding.rounded(exact, unit: unit))
        var line = self
        line.amount = exact
        line.rawText = text(showing: shown, originalAmount: amount, factor: factor)
        return line
    }

    /// `rawText` with the amount replaced where it's written ("⅔ cup flour" → "1⅓ cup flour",
    /// "Il vous faut 250 g de farine, tamisée" → "Il vous faut 500 g de farine, tamisée"), so
    /// the rest of the line stays as the recipe writes it. Only when the amount isn't written
    /// anywhere in the line is one built from amount, unit and name ("a dozen eggs" → "6 eggs"),
    /// or, without a name, the factor put in front of the line ("2 × a handful").
    private func text(showing shown: String, originalAmount amount: Double, factor: Double) -> String {
        if let written = Self.writtenAmount(amount, unit: unit, in: rawText) {
            return rawText.replacingCharacters(in: written, with: shown)
        }
        guard let ingredientName else {
            let shownFactor = IngredientAmountFormatter.format(IngredientAmountRounding.rounded(factor, unit: nil))
            return "\(shownFactor) × \(rawText)"
        }
        return [shown, unit, ingredientName].compactMap(\.self).joined(separator: " ")
    }

    /// The first number in `text` that's `amount` as written: "1 1/2", "1½", "1 ½", "1/2",
    /// "2.5", "2,5", "2" or "½", not part of a longer number. Within 1%, so a line written
    /// "⅔ cup" with 0.67 typed as its amount still matches; the leading "1" of "1 (2 lb)
    /// chicken" with an amount of 2 doesn't.
    private static func writtenAmount(_ amount: Double, unit: String?, in text: String) -> Range<String.Index>? {
        let fraction = "[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]"
        let slash = #"\s*[/⁄]\s*"#
        let number = #"\d+\s+\d+"# + slash + #"\d+|\d+\s?"# + fraction + #"|\d+"# + slash + #"\d+|\d+(?:[.,]\d+)?|"# + fraction
        let pattern = #"(?<![\d.,/⁄\p{L}])(?:"# + number + #")(?![\d/⁄]|[.,]\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let tolerance = max(1e-6, amount * 0.01)
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text),
                  let value = IngredientAmountParser.parse(String(text[range]), unit: unit)?.value else { continue }
            if abs(value - amount) <= tolerance {
                return range
            }
        }
        return nil
    }
}

/// Rounds a scaled amount to what a cook can measure in its unit (Phase 15.3). The groups come
/// from `MeasurementUnits.scalingRounding(of:)`. A tie goes to the smaller amount, and a non-zero
/// amount never rounds to 0: it shows the group's smallest step instead.
enum IngredientAmountRounding {
    private static let tolerance = 1e-9
    /// The fractions cups and spoons are measured in.
    private static let cupSteps: [Double] = [1.0 / 4, 1.0 / 3, 1.0 / 2, 2.0 / 3, 3.0 / 4]
    /// Spoons below one also come in eighths.
    private static let smallSpoonSteps: [Double] = [1.0 / 8] + cupSteps

    static func rounded(_ amount: Double, unit: String?) -> Double {
        switch MeasurementUnits.scalingRounding(of: unit) {
        case .cup:
            kitchenFraction(amount, steps: cupSteps)
        case .spoon:
            kitchenFraction(amount, steps: amount < 1 ? smallSpoonSteps : cupSteps)
        case .metric:
            nearest(amount, step: amount > 100 ? 10 : 1)
        case .imperial:
            nearest(amount, step: 0.1)
        case .counted:
            nearest(amount, step: 0.5)
        }
    }

    /// A whole number plus the nearest of `steps` (or nothing): ⅔ × 2 stays exactly 1⅓, and
    /// 5/12 cup, as close to ⅓ as to ½, shows ⅓.
    private static func kitchenFraction(_ amount: Double, steps: [Double]) -> Double {
        let whole = amount.rounded(.down)
        let fraction = amount - whole
        var best = 0.0
        for candidate in steps + [1] where abs(fraction - candidate) < abs(fraction - best) - tolerance {
            best = candidate
        }
        let result = whole + best
        return result > 0 ? result : steps[0]
    }

    private static func nearest(_ amount: Double, step: Double) -> Double {
        let lower = (amount / step + tolerance).rounded(.down) * step
        let upper = lower + step
        let result = amount - lower <= upper - amount + tolerance ? lower : upper
        return result > tolerance ? result : step
    }
}
