import Foundation

/// Which cup and spoon sizes a recipe's volume units mean. The stored recipe keeps the unit as
/// written, so this is decided on the device (PLAN.md 11.1). It's the user's choice in
/// Settings, independent of the app's language; until they pick one it follows the device's
/// measurement system (region), never the language.
enum VolumeStandard: String, CaseIterable, Equatable {
    /// US customary: 236.6 ml cup, 14.8 ml tablespoon, US pints.
    case usCustomary
    /// Metric cups and spoons (250/15/5 ml); pints and fluid ounces are imperial.
    case metric

    /// The `UserDefaults` key of the Settings choice.
    static let storageKey = "volumeStandard"

    /// The choice before the user makes one: US customary only in a US-measurement region.
    static func regionDefault(for locale: Locale = .current) -> VolumeStandard {
        locale.measurementSystem == .us ? .usCustomary : .metric
    }
}

/// What a recipe unit measures, as an amount of a base unit.
enum MeasurementUnitKind: Equatable {
    case volume(milliliters: Double)
    case weight(grams: Double)
}

/// How a scaled amount in a unit is rounded for the recipe screen (Phase 15.3).
enum ScalingRounding: Equatable {
    /// Cups: a whole number plus ¼, ⅓, ½, ⅔ or ¾.
    case cup
    /// Spoons: as cups, and ⅛ below one.
    case spoon
    /// Metric units: whole numbers, tens above 100.
    case metric
    /// Other imperial and US units (fluid ounces to gallons, ounces, pounds): one decimal.
    case imperial
    /// No unit, or one without a size ("clove", "can"): the nearest half.
    case counted
}

/// The volume and weight units recipes use, in the languages the app ships in. Count units
/// ("clove", "can") and vague ones ("pinch", "handful") have no size, so they aren't here.
enum MeasurementUnits {
    private enum Unit: Hashable {
        case cup, tablespoon, teaspoon, milliliter, centiliter, deciliter, liter
        case fluidOunce, pint, quart, gallon
        case gram, kilogram, milligram, ounce, pound
    }

    /// Lowercased and without accents, like `folded(_:)` makes the recipe's unit.
    private static let names: [String: Unit] = {
        let groups: [(Unit, [String])] = [
            (.cup, ["cup", "c", "taza", "tasse", "kopje", "kop"]),
            (.tablespoon, [
                "tablespoon", "tbsp", "tbs", "tbl", "cucharada", "cda", "cuillere a soupe",
                "cuilleres a soupe", "c. a s.", "cas", "cs", "el", "essloffel", "eetlepel",
            ]),
            (.teaspoon, [
                "teaspoon", "tsp", "cucharadita", "cdta", "cdita", "cuillere a cafe",
                "cuilleres a cafe", "c. a c.", "cac", "cc", "tl", "teeloffel", "theelepel",
            ]),
            (.milliliter, ["milliliter", "millilitre", "ml", "mililitro"]),
            (.centiliter, ["centiliter", "centilitre", "cl"]),
            (.deciliter, ["deciliter", "decilitre", "dl"]),
            (.liter, ["liter", "litre", "l", "litro"]),
            (.fluidOunce, ["fl oz", "fl. oz", "fluid ounce"]),
            (.pint, ["pint", "pt"]),
            (.quart, ["quart", "qt"]),
            (.gallon, ["gallon", "gal"]),
            (.gram, ["gram", "gramme", "g", "gr", "gramo"]),
            (.kilogram, ["kilogram", "kilogramme", "kg", "kilo"]),
            (.milligram, ["milligram", "milligramme", "mg"]),
            // "oz" alone is a weight; a fluid ounce is written "fl oz".
            (.ounce, ["ounce", "oz"]),
            (.pound, ["pound", "lb", "lbs"]),
        ]
        var names: [String: Unit] = [:]
        for (unit, spellings) in groups {
            for spelling in spellings {
                names[spelling] = unit
            }
        }
        return names
    }()

    /// Each unit's size in the US customary and metric standards (the same for metric units).
    private static let sizes: [Unit: (usCustomary: MeasurementUnitKind, metric: MeasurementUnitKind)] = [
        .cup: (.volume(milliliters: 236.5882365), .volume(milliliters: 250)),
        .tablespoon: (.volume(milliliters: 14.78676478125), .volume(milliliters: 15)),
        .teaspoon: (.volume(milliliters: 4.92892159375), .volume(milliliters: 5)),
        .milliliter: (.volume(milliliters: 1), .volume(milliliters: 1)),
        .centiliter: (.volume(milliliters: 10), .volume(milliliters: 10)),
        .deciliter: (.volume(milliliters: 100), .volume(milliliters: 100)),
        .liter: (.volume(milliliters: 1000), .volume(milliliters: 1000)),
        .fluidOunce: (.volume(milliliters: 29.5735295625), .volume(milliliters: 28.4130625)),
        .pint: (.volume(milliliters: 473.176473), .volume(milliliters: 568.26125)),
        .quart: (.volume(milliliters: 946.352946), .volume(milliliters: 1136.5225)),
        .gallon: (.volume(milliliters: 3785.411784), .volume(milliliters: 4546.09)),
        .gram: (.weight(grams: 1), .weight(grams: 1)),
        .kilogram: (.weight(grams: 1000), .weight(grams: 1000)),
        .milligram: (.weight(grams: 0.001), .weight(grams: 0.001)),
        .ounce: (.weight(grams: 28.349523125), .weight(grams: 28.349523125)),
        .pound: (.weight(grams: 453.59237), .weight(grams: 453.59237)),
    ]

    static func scalingRounding(of unit: String?) -> ScalingRounding {
        switch unit.flatMap(lookUp) {
        case .cup: .cup
        case .tablespoon, .teaspoon: .spoon
        case .milliliter, .centiliter, .deciliter, .liter, .gram, .kilogram, .milligram: .metric
        case .fluidOunce, .pint, .quart, .gallon, .ounce, .pound: .imperial
        case nil: .counted
        }
    }

    /// Units that are an amount in themselves, lowercased and without accents. "1" means nothing
    /// to them unless the recipe writes it, so a number the model adds to "snufje zout" is
    /// dropped on capture and ignored by scaling (#251).
    private static let vagueNames: Set<String> = [
        "pinch", "dash", "handful", "pizca", "pincee", "prise", "msp", "messerspitze", "snufje",
    ]

    /// True for a unit that's an amount in itself, such as "pinch" or "snufje", in any of the
    /// app's languages and in the plural.
    static func isVague(_ unit: String?) -> Bool {
        guard let unit else { return false }
        let folded = unit.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if vagueNames.contains(folded) {
            return true
        }
        // Plurals: "pinches", "snufjes", "Prisen".
        return ["es", "s", "n"].contains { suffix in
            folded.hasSuffix(suffix) && vagueNames.contains(String(folded.dropLast(suffix.count)))
        }
    }

    static func kind(of unit: String, standard: VolumeStandard) -> MeasurementUnitKind? {
        guard let unit = lookUp(unit), let size = sizes[unit] else { return nil }
        return standard == .usCustomary ? size.usCustomary : size.metric
    }

    private static func lookUp(_ text: String) -> Unit? {
        var unit = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        if let match = names[unit] {
            return match
        }
        if unit.hasSuffix(".") {
            unit.removeLast()
            if let match = names[unit] {
                return match
            }
        }
        // Plurals: "cups", "tablespoons", "tazas", "eetlepels".
        for suffix in ["es", "s"] where unit.hasSuffix(suffix) {
            if let match = names[String(unit.dropLast(suffix.count))] {
                return match
            }
        }
        return nil
    }
}
