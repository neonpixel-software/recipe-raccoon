@testable import RecipeRaccoon
import XCTest

final class CapturedRecipeSchemaTests: XCTestCase {
    func testToDomainMapsFullyStructuredIngredient() {
        let schema = CapturedIngredientSchema(rawText: "2 cups flour", amount: "2", unit: "cup", ingredientName: "flour")

        let line = schema.toDomain()

        XCTAssertEqual(line.rawText, "2 cups flour")
        XCTAssertEqual(line.amount, 2)
        XCTAssertEqual(line.unit, "cup")
        XCTAssertEqual(line.ingredientName, "flour")
    }

    func testToDomainCollapsesEmptyFieldsToNilAndTrims() {
        let schema = CapturedIngredientSchema(rawText: "a pinch of salt", amount: "  ", unit: "", ingredientName: "  salt  ")

        let line = schema.toDomain()

        XCTAssertNil(line.amount)
        XCTAssertNil(line.unit)
        XCTAssertEqual(line.ingredientName, "salt")
    }

    func testToDomainLeavesAmountNilWhenUnparseable() {
        let schema = CapturedIngredientSchema(rawText: "a few eggs", amount: "a few", unit: "", ingredientName: "eggs")

        let line = schema.toDomain()

        XCTAssertNil(line.amount)
    }

    func testToDomainParsesFractionAmounts() {
        let schema = CapturedIngredientSchema(rawText: "1 1/2 tsp salt", amount: "1 1/2", unit: "tsp", ingredientName: "salt")

        XCTAssertEqual(schema.toDomain().amount, 1.5)
    }

    /// #234 review: scaling finds the written amount by its value, so capture must store a
    /// written fraction exactly, not rounded.
    func testToDomainStoresAWrittenFractionExactly() {
        let schema = CapturedIngredientSchema(rawText: "⅔ cup sugar", amount: "⅔", unit: "cup", ingredientName: "sugar")

        XCTAssertEqual(schema.toDomain().amount, 2.0 / 3)
    }

    /// #216: the model's single number for a compound amount is wrong, so the line's parts win.
    func testToDomainCombinesACompoundAmountFromTheLine() throws {
        let schema = CapturedIngredientSchema(
            rawText: "1 cup plus 2 tablespoons flour", amount: "1 2/3", unit: "cup", ingredientName: "flour"
        )

        let line = schema.toDomain()

        XCTAssertEqual(try XCTUnwrap(line.amount), 1.125, accuracy: 1e-9)
        XCTAssertEqual(line.unit, "cup")
        XCTAssertEqual(line.ingredientName, "flour")
    }

    func testToDomainGivesACompoundOfWeightAndVolumeNoAmount() {
        let schema = CapturedIngredientSchema(rawText: "1 cup plus 50 g sugar", amount: "1", unit: "cup", ingredientName: "sugar")

        let line = schema.toDomain()

        XCTAssertNil(line.amount)
        XCTAssertNil(line.unit)
        XCTAssertEqual(line.ingredientName, "sugar")
    }

    func testToDomainParsesAThousandsSeparator() {
        let schema = CapturedIngredientSchema(rawText: "1,000 g flour", amount: "1,000", unit: "g", ingredientName: "flour")

        XCTAssertEqual(schema.toDomain().amount, 1000)
    }

    func testToDomainTakesUnitFromAmountWhenUnitIsEmpty() {
        let schema = CapturedIngredientSchema(rawText: "100g butter", amount: "100g", unit: "", ingredientName: "butter")

        let line = schema.toDomain()

        XCTAssertEqual(line.amount, 100)
        XCTAssertEqual(line.unit, "g")
    }

    func testToDomainPrefersExplicitUnitOverOneInAmount() {
        let schema = CapturedIngredientSchema(rawText: "100g butter", amount: "100g", unit: "grams", ingredientName: "butter")

        XCTAssertEqual(schema.toDomain().unit, "grams")
    }

    func testToDomainDropsDescriptorUsedAsUnit() {
        let schema = CapturedIngredientSchema(rawText: "1 large egg", amount: "1", unit: "large", ingredientName: "large egg")

        let line = schema.toDomain()

        XCTAssertEqual(line.amount, 1)
        XCTAssertNil(line.unit)
        XCTAssertEqual(line.ingredientName, "egg")
    }

    func testToDomainMovesIngredientFromUnitToEmptyName() {
        let schema = CapturedIngredientSchema(rawText: "1 yellow onion", amount: "1", unit: "yellow onion", ingredientName: "")

        let line = schema.toDomain()

        XCTAssertNil(line.unit)
        XCTAssertEqual(line.ingredientName, "yellow onion")
    }

    func testToDomainNeverUsesPlaceholderUnitAsName() {
        let schema = CapturedIngredientSchema(rawText: "salt & pepper to taste", amount: "", unit: "none", ingredientName: "")

        let line = schema.toDomain()

        XCTAssertNil(line.unit)
        XCTAssertNil(line.ingredientName)
    }

    func testToDomainTakesUnitFromRawTextWhenModelLeftItEmpty() {
        let schema = CapturedIngredientSchema(rawText: "1/3 cup melted butter", amount: "1/3", unit: "", ingredientName: "butter")

        let line = schema.toDomain()

        XCTAssertEqual(line.amount, 1.0 / 3)
        XCTAssertEqual(line.unit, "cup")
    }

    func testToDomainTakesUnitFromRawTextWhenAmountIsMidSentence() {
        let schema = CapturedIngredientSchema(rawText: "Il vous faut 250 g de farine", amount: "250", unit: "", ingredientName: "farine")

        XCTAssertEqual(schema.toDomain().unit, "g")
    }

    func testToDomainDoesNotMatchAmountInsideLongerNumber() {
        let schema = CapturedIngredientSchema(rawText: "Pour 15 crêpes : 1 pincée de sel", amount: "1", unit: "", ingredientName: "sel")

        XCTAssertEqual(schema.toDomain().unit, "pincée")
    }

    func testToDomainTakesUnitFromWordAmount() {
        let schema = CapturedIngredientSchema(rawText: "a pinch of salt", amount: "a pinch", unit: "", ingredientName: "salt")

        let line = schema.toDomain()

        XCTAssertNil(line.amount)
        XCTAssertEqual(line.unit, "pinch")
    }

    func testRecipeToDomainDropsIngredientsNotInSource() {
        let schema = CapturedRecipeSchema(
            title: "Crêpes",
            ingredients: [
                CapturedIngredientSchema(rawText: "250 g de farine", amount: "250", unit: "g", ingredientName: "farine"),
                CapturedIngredientSchema(rawText: "eau", amount: "", unit: "", ingredientName: "eau"),
            ],
            equipment: [],
            steps: ["Mélanger"]
        )

        let recipe = schema.toDomain(source: "Il faut 250 g de farine. Mélanger.")

        XCTAssertEqual(recipe.ingredients.map(\.rawText), ["250 g de farine"])
    }

    /// The model misspelled "Olivenöl"; the exact source check would drop a real ingredient (#76).
    func testRecipeToDomainKeepsAMisspelledIngredientInTheSourceSpelling() {
        let schema = CapturedRecipeSchema(
            title: "Vinaigrette",
            ingredients: [
                CapturedIngredientSchema(rawText: "3 EL Olivenäl", amount: "3", unit: "EL", ingredientName: "Olivenäl"),
                CapturedIngredientSchema(rawText: "1 TL Senf", amount: "1", unit: "TL", ingredientName: "Senf"),
            ],
            equipment: [],
            steps: ["Schütteln"]
        )

        let recipe = schema.toDomain(source: "3 EL Olivenöl\n1 TL Senf\nSchütteln.")

        XCTAssertEqual(recipe.ingredients.map(\.rawText), ["3 EL Olivenöl", "1 TL Senf"])
        XCTAssertEqual(recipe.ingredients.map(\.ingredientName), ["Olivenöl", "Senf"])
    }

    /// Step durations the model turned into ingredients ("une heure" named "heure", #76).
    func testRecipeToDomainDropsDurationsListedAsIngredients() {
        let source = "250 g de farine. Laisser reposer une heure. Cuire environ une minute de chaque côté."
        let schema = CapturedRecipeSchema(
            title: "Crêpes",
            ingredients: [
                CapturedIngredientSchema(rawText: "250 g de farine", amount: "250", unit: "g", ingredientName: "farine"),
                CapturedIngredientSchema(rawText: "une heure", amount: "une heure", unit: "", ingredientName: "heure"),
                CapturedIngredientSchema(
                    rawText: "environ une minute de chaque côté",
                    amount: "environ une minute",
                    unit: "",
                    ingredientName: "minute"
                ),
            ],
            equipment: [],
            steps: ["Laisser reposer une heure."]
        )

        let recipe = schema.toDomain(source: source)

        XCTAssertEqual(recipe.ingredients.map(\.rawText), ["250 g de farine"])
    }

    /// The model can get stuck repeating a line (#76); the copies go, a later mention stays.
    func testRecipeToDomainDropsLinesRepeatedBackToBack() {
        let salt = CapturedIngredientSchema(rawText: "une pincée de sel", amount: "une pincée", unit: "", ingredientName: "sel")
        let flour = CapturedIngredientSchema(rawText: "250 g de farine", amount: "250", unit: "g", ingredientName: "farine")
        let schema = CapturedRecipeSchema(
            title: "Crêpes",
            ingredients: [flour, salt, salt, salt, flour],
            equipment: [],
            steps: ["Mélanger.", "Mélanger.", "Cuire.", "Mélanger."]
        )

        let recipe = schema.toDomain(source: "250 g de farine, une pincée de sel. Mélanger. Cuire.")

        XCTAssertEqual(recipe.ingredients.map(\.rawText), ["250 g de farine", "une pincée de sel", "250 g de farine"])
        XCTAssertEqual(recipe.steps, ["Mélanger.", "Cuire.", "Mélanger."])
    }

    /// The model re-emitted a step's last clause as a step of its own (#76).
    func testRecipeToDomainDropsAStepThatRepeatsPartOfThePreviousOne() {
        let schema = CapturedRecipeSchema(
            title: "Crêpes",
            ingredients: [],
            equipment: [],
            steps: [
                "Cuire les crêpes dans une poêle chaude, environ une minute de chaque côté.",
                "environ une minute de chaque côté",
                "Servir.",
            ]
        )

        let recipe = schema.toDomain()

        XCTAssertEqual(recipe.steps, ["Cuire les crêpes dans une poêle chaude, environ une minute de chaque côté.", "Servir."])
    }

    /// Only a repeated ending counts: a step that reuses words from the middle stays (PR #127 review).
    func testRecipeToDomainKeepsAStepThatReusesWordsFromTheMiddleOfThePreviousOne() {
        let schema = CapturedRecipeSchema(
            title: "Pie",
            ingredients: [],
            equipment: [],
            steps: [
                "Spoon the filling into the pie crust and bake for 40 minutes.",
                "into the pie crust",
                "Cool for 40 minutes.",
                "bake for 40 minutes",
            ]
        )

        let recipe = schema.toDomain()

        XCTAssertEqual(recipe.steps, [
            "Spoon the filling into the pie crust and bake for 40 minutes.",
            "into the pie crust",
            "Cool for 40 minutes.",
            "bake for 40 minutes",
        ])
    }

    func testRecipeToDomainMapsFieldsAndFiltersBlankSteps() {
        let schema = CapturedRecipeSchema(
            title: "Pancakes",
            ingredients: [CapturedIngredientSchema(rawText: "1 egg", amount: "1", unit: "", ingredientName: "egg")],
            equipment: [],
            steps: ["Mix", "  ", "Cook"]
        )

        let recipe = schema.toDomain()

        XCTAssertEqual(recipe.title, "Pancakes")
        XCTAssertEqual(recipe.ingredients.count, 1)
        XCTAssertEqual(recipe.ingredients[0].ingredientName, "egg")
        XCTAssertEqual(recipe.steps, ["Mix", "Cook"])
        XCTAssertEqual(recipe.source, .typed)
        XCTAssertEqual(recipe.tags, [])
    }

    // MARK: equipment (issue #82)

    func testRecipeToDomainTrimsEquipmentAndDropsBlanksAndPlaceholders() {
        let schema = CapturedRecipeSchema(title: "Bread", ingredients: [], equipment: ["  loaf pan ", "", "none"], steps: [])

        XCTAssertEqual(schema.toDomain().equipment, ["loaf pan"])
    }

    func testRecipeToDomainDropsEquipmentNotInSource() {
        let schema = CapturedRecipeSchema(title: "Bread", ingredients: [], equipment: ["Loaf pan", "stand mixer"], steps: [])

        let recipe = schema.toDomain(source: "Grease an 8x4-inch loaf pan and bake.")

        XCTAssertEqual(recipe.equipment, ["Loaf pan"])
    }

    func testRecipeToDomainDropsIngredientTheModelAlsoListedAsEquipment() {
        let schema = CapturedRecipeSchema(
            title: "Zucchini Bread",
            ingredients: [
                CapturedIngredientSchema(rawText: "100g walnuts", amount: "100", unit: "g", ingredientName: "walnuts"),
                // The model gives tool lines an amount of 1 (seen on device).
                CapturedIngredientSchema(rawText: "8x4-inch loaf pan", amount: "1", unit: "", ingredientName: "loaf pan"),
                CapturedIngredientSchema(rawText: "toothpick or wooden skewer", amount: "1", unit: "", ingredientName: ""),
            ],
            equipment: ["loaf pan", "Toothpick or wooden skewer"],
            steps: []
        )

        let recipe = schema.toDomain(source: "100g walnuts, 8x4-inch loaf pan, toothpick or wooden skewer")

        XCTAssertEqual(recipe.ingredients.map(\.rawText), ["100g walnuts"])
        XCTAssertEqual(recipe.equipment, ["loaf pan", "Toothpick or wooden skewer"])
    }

    func testRecipeToDomainKeepsIngredientThatOnlyMentionsEquipment() {
        let schema = CapturedRecipeSchema(
            title: "Kebabs",
            ingredients: [
                CapturedIngredientSchema(rawText: "8 wooden skewers for kebabs", amount: "8", unit: "", ingredientName: "wooden skewers"),
                CapturedIngredientSchema(rawText: "¼ cup butter plus more for the pan", amount: "¼", unit: "cup", ingredientName: "butter"),
            ],
            equipment: ["pan", "skewers"],
            steps: []
        )

        XCTAssertEqual(schema.toDomain().ingredients.count, 2)
    }

    func testRecipeToDomainKeepsMeasuredIngredientTheModelAlsoListedAsEquipment() {
        // "Butter the pan" can make the model list butter as equipment.
        let schema = CapturedRecipeSchema(
            title: "Cake",
            ingredients: [CapturedIngredientSchema(rawText: "¼ cup butter", amount: "¼", unit: "cup", ingredientName: "butter")],
            equipment: ["butter", "cake pan"],
            steps: []
        )

        XCTAssertEqual(schema.toDomain().ingredients.map(\.ingredientName), ["butter"])
    }

    // MARK: servings (Phase 15.2; the grounding rules are in CapturedServingsTests)

    func testRecipeToDomainKeepsServingsTheSourceStates() {
        let schema = CapturedRecipeSchema(title: "Soup", servings: "4", ingredients: [], equipment: [], steps: [])

        XCTAssertEqual(schema.toDomain(source: "Soup\nServes 4").servings, 4)
        XCTAssertNil(schema.toDomain(source: "Soup\n4 eggs").servings)
    }
}

extension CapturedRecipeSchema {
    /// The schema without servings, for the tests that don't need them.
    init(title: String, ingredients: [CapturedIngredientSchema], equipment: [String], steps: [String]) {
        self.init(title: title, servings: "", ingredients: ingredients, equipment: equipment, steps: steps)
    }
}
