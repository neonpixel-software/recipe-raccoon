import Foundation

/// An amount written in two parts, as in "1 cup plus 2 tablespoons" or "1 lb 4 oz" (#216). The
/// on-device model can't add them up and returns a single wrong number (1 2/3 cups instead of
/// 1 1/8), so capture reads them from the line instead.
enum CompoundAmount: Equatable {
    /// Both parts in the first part's unit.
    case combined(value: Double, unit: String)
    /// A weight and a volume, or a second part without a known size ("1 tbsp plus 1 pinch"): no single
    /// amount is right, so the line gets none rather than a wrong one.
    case uncombinable

    /// Words that join the two parts. Writing them side by side ("1 lb 4 oz") joins them too.
    private static let joiners: Set<String> = ["plus", "+", ",", "and", "y", "et", "und", "en"]

    private static let numberRegex: NSRegularExpression? = {
        let fraction = "[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]"
        let slash = #"\s*[/⁄]\s*"#
        let number = #"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\s+\d+"# + slash + #"\d+|\d+\s?"# + fraction
            + #"|\d+"# + slash + #"\d+|\d+(?:[.,]\d+)?|"# + fraction
        return try? NSRegularExpression(pattern: #"(?<![\d.,/⁄\p{L}])(?:"# + number + #")(?![\d/⁄]|[.,]\d)"#)
    }()

    /// The first compound amount in `line`: a number and a unit, optionally a joining word, then
    /// a number and a unit. Nil when the line has none, as in "2 tbsp butter and 1 tsp salt",
    /// where an ingredient comes between the parts, or when the parts aren't a sum (see
    /// `combining`).
    init?(in line: String) {
        guard let numberRegex = Self.numberRegex else { return nil }
        let numbers = numberRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            .compactMap { Range($0.range, in: line) }
        for (first, second) in zip(numbers, numbers.dropFirst()) {
            guard let firstUnit = Self.unit(between: line[first.upperBound..<second.lowerBound]),
                  let secondUnit = IngredientDescriptors.leadingUnit(in: String(line[second.upperBound...])),
                  let firstValue = IngredientAmountParser.parse(String(line[first]), unit: firstUnit)?.value,
                  let secondValue = IngredientAmountParser.parse(String(line[second]), unit: secondUnit)?.value else { continue }
            guard let amount = Self.combining(firstValue, firstUnit, secondValue, secondUnit) else { return nil }
            self = amount
            return
        }
        return nil
    }

    /// The text between the two numbers when it's exactly a unit, optionally followed by a
    /// joining word: "cup plus", "lb", "EL +".
    private static func unit(between text: Substring) -> String? {
        var words = text.replacingOccurrences(of: "+", with: " + ").replacingOccurrences(of: ",", with: " , ")
            .split(whereSeparator: \.isWhitespace)
        if let last = words.last, joiners.contains(last.lowercased()) {
            words.removeLast()
        }
        let unit = words.joined(separator: " ")
        guard !unit.isEmpty, IngredientDescriptors.leadingUnit(in: unit) == unit else { return nil }
        return unit
    }

    /// Cup-and-spoon compounds are a US habit, so sizes are US customary: 1 cup plus 2
    /// tablespoons is 1 1/8 cups. Nil when the parts aren't a sum: a container and its size
    /// ("1 can 14 oz beans", where the model's count stays), or one amount restated in the other
    /// system ("1 cup 250 ml milk"); every real compound keeps to one system.
    private static func combining(_ firstValue: Double, _ firstUnit: String, _ secondValue: Double, _ secondUnit: String) -> Self? {
        guard let firstKind = MeasurementUnits.kind(of: firstUnit, standard: .usCustomary) else { return nil }
        let sameSystem = isMetric(firstUnit) == isMetric(secondUnit)
        switch (firstKind, MeasurementUnits.kind(of: secondUnit, standard: .usCustomary)) {
        case let (.volume(firstSize), .volume(secondSize)), let (.weight(firstSize), .weight(secondSize)):
            return sameSystem ? .combined(value: firstValue + secondValue * secondSize / firstSize, unit: firstUnit) : nil
        default:
            return .uncombinable
        }
    }

    private static func isMetric(_ unit: String) -> Bool {
        MeasurementUnits.scalingRounding(of: unit) == .metric
    }
}
