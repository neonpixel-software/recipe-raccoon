import Foundation
import FoundationModels

@Generable
struct CapturedRecipeSchema {
    @Guide(description: "A short, descriptive title for the recipe")
    let title: String
    /// Kept only when the source states the number as servings (`CapturedServings`), so the
    /// model can't invent one.
    @Guide(description: "How many people or servings the recipe makes, as a whole number, if stated, else empty")
    let servings: String
    /// The maximum counts stop a runaway list. With greedy sampling the model can repeat one line
    /// until it runs out of context ("une pincée de sel" ×100 in a crêpe recipe, issue #76),
    /// which fails the whole capture. The limits are far above any real recipe.
    @Guide(description: "Each ingredient as a separate structured line", .maximumCount(40))
    let ingredients: [CapturedIngredientSchema]
    @Guide(description: "Tools and cookware the recipe needs, e.g. loaf pan, whisk", .maximumCount(15))
    let equipment: [String]
    @Guide(description: "Each preparation step in order, one instruction per entry", .maximumCount(40))
    let steps: [String]
}

@Generable
struct CapturedIngredientSchema {
    @Guide(description: "The ingredient exactly as written in the source text, e.g. '2 cups flour'")
    let rawText: String
    @Guide(description: "The quantity exactly as written (e.g. \"2\", \"1.5\", \"1/2\", \"1 1/2\", \"½\") if stated, else empty. Don't convert fractions")
    let amount: String
    @Guide(description: "Unit of measurement (e.g. \"cup\", \"tsp\", \"g\") if stated, else empty")
    let unit: String
    @Guide(description: "The ingredient's name alone, without quantity/unit, if identifiable, else empty")
    let ingredientName: String
}

extension CapturedRecipeSchema {
    /// Maps to a `Recipe`. With `source`, ingredients and equipment the model invented (not
    /// in the source text) are dropped. An ingredient without a measurement unit whose line or
    /// name is also one of the equipment items is dropped too: the model sometimes lists a tool
    /// in both ("8x4-inch loaf pan" named "loaf pan", issue #82). It gives such lines an amount
    /// ("1 loaf pan"), so the unit is what tells them apart from food: "¼ cup butter" is kept
    /// even if the model also lists "butter" as equipment for "butter the pan". The servings are
    /// kept only if the source states them as servings.
    func toDomain(source: String? = nil) -> Recipe {
        let trimmedEquipment = equipment
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !IngredientDescriptors.isPlaceholder($0) }
        let groundedEquipment = source.map { source in
            trimmedEquipment.filter { IngredientDescriptors.appears(in: source, rawText: $0, name: "") }
        } ?? trimmedEquipment
        let grounded = source.map { source in
            ingredients.compactMap { $0.grounded(in: source) }
        } ?? ingredients
        let mappedIngredients = grounded.map { $0.toDomain() }.filter { line in
            guard line.unit == nil else { return true }
            // A step's duration turned into an ingredient ("une heure" named "heure", #76).
            if let name = line.ingredientName, IngredientDescriptors.isTimeUnit(name) {
                return false
            }
            return !groundedEquipment.contains { item in
                IngredientDescriptors.isSameText(item, line.rawText) || IngredientDescriptors.isSameText(item, line.ingredientName ?? "")
            }
        }
        return Recipe(
            id: UUID(),
            title: title,
            servings: CapturedServings.grounded(servings, in: source),
            ingredients: Self.removingRepeats(mappedIngredients, by: \.rawText),
            equipment: groundedEquipment,
            steps: Self.removingRepeatedSteps(steps),
            source: .typed,
            tags: []
        )
    }

    /// Drops an entry that repeats the one before it. The model can get stuck repeating a line
    /// (issue #76); a recipe never lists the same line twice in a row.
    private static func removingRepeats<Element>(_ elements: [Element], by text: (Element) -> String) -> [Element] {
        var result: [Element] = []
        for element in elements {
            if let previous = result.last, IngredientDescriptors.isSameText(text(previous), text(element)) {
                continue
            }
            result.append(element)
        }
        return result
    }

    /// Drops blank steps, and a step that repeats the end of the one before it: the model
    /// sometimes finishes a step and then emits its last clause again as a step of its own
    /// ("…légèrement huilée, environ une minute de chaque côté." then "environ une minute de
    /// chaque côté", issue #76). Only the end counts, which is the pattern the model shows, so a
    /// step that reuses words from the middle of the previous one stays.
    ///
    /// Unlike ingredients and equipment, steps aren't checked against the source text: the model
    /// legitimately splits and rewords them, so a source check would drop real steps.
    private static func removingRepeatedSteps(_ steps: [String]) -> [String] {
        var result: [String] = []
        for step in steps.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !step.isEmpty {
            if let previous = result.last, IngredientDescriptors.endsWith(previous, step) {
                continue
            }
            result.append(step)
        }
        return result
    }
}

extension CapturedIngredientSchema {
    /// The line if it's in `source`, with a misspelled line or name replaced by the source's
    /// spelling ("Olivenäl" → "Olivenöl"); nil if neither is in the source (an invented
    /// ingredient).
    func grounded(in source: String) -> CapturedIngredientSchema? {
        func spelling(_ text: String) -> String? {
            IngredientDescriptors.appears(in: source, rawText: text, name: "")
                ? text
                : IngredientDescriptors.sourceSpelling(of: text, in: source)
        }
        let rawSpelling = spelling(rawText)
        let nameSpelling = spelling(ingredientName)
        guard rawSpelling != nil || nameSpelling != nil else { return nil }
        return CapturedIngredientSchema(
            rawText: rawSpelling ?? rawText,
            amount: amount,
            unit: unit,
            ingredientName: nameSpelling ?? ingredientName
        )
    }

    func toDomain() -> IngredientLine {
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedAmount = IngredientAmountParser.parse(amount, unit: trimmedUnit.isEmpty ? nil : trimmedUnit)
        var name = ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateUnit = trimmedUnit.isEmpty ? parsedAmount?.unit : trimmedUnit
        var measurementUnit: String?
        if let candidateUnit, IngredientDescriptors.isMeasurementUnit(candidateUnit) {
            measurementUnit = candidateUnit
        } else {
            if name.isEmpty, let candidateUnit, !IngredientDescriptors.isPlaceholder(candidateUnit) {
                // The model sometimes puts the ingredient itself in the unit field ("yellow onion").
                name = candidateUnit
            }
            // The model also leaves the unit empty when the line has one ("1/3 cup butter").
            measurementUnit = unitWrittenInText(amountParsed: parsedAmount != nil)
        }
        name = IngredientDescriptors.removingSizeWords(from: name)
        var amountValue = parsedAmount?.value
        // The model's number for a compound amount is wrong, so the line's own parts replace it.
        switch CompoundAmount(in: rawText) {
        case let .combined(value, unit):
            amountValue = value
            measurementUnit = unit
        case .uncombinable:
            amountValue = nil
            measurementUnit = nil
        case nil:
            break
        }
        // A vague unit has no amount unless the line writes one: "snufje zout" with the model's
        // "1" reads like "a pinch" (#251).
        if MeasurementUnits.isVague(measurementUnit), !Self.writesANumber(rawText) {
            amountValue = nil
        }
        return IngredientLine(
            id: UUID(),
            rawText: rawText,
            amount: amountValue,
            unit: measurementUnit,
            ingredientName: name.isEmpty ? nil : name
        )
    }

    private static func writesANumber(_ text: String) -> Bool {
        text.range(of: #"[\d½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]"#, options: .regularExpression) != nil
    }

    /// The unit as written in rawText right after the amount ("1/3 cup butter", "Il vous faut
    /// 250 g de farine"), or at the end of an amount that isn't a number ("a pinch").
    private func unitWrittenInText(amountParsed: Bool) -> String? {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAmount.isEmpty else { return nil }
        if !amountParsed, let unit = IngredientDescriptors.trailingUnit(in: trimmedAmount) {
            return unit
        }
        let line = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        // The first occurrence of the amount that isn't part of a longer number, so "1" doesn't
        // match inside "15".
        let pattern = #"(?<![\d/.,])"# + NSRegularExpression.escapedPattern(for: trimmedAmount) + #"(?![\d/.,])"#
        guard let range = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return IngredientDescriptors.leadingUnit(in: String(line[range.upperBound...]))
    }
}
