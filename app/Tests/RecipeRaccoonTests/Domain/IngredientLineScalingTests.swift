@testable import RecipeRaccoon
import XCTest

/// Scaling for another number of servings (Phase 15.3): the text with the rounded amount, the
/// exact amount for the weight view.
final class IngredientLineScalingTests: XCTestCase {
    private func line(_ rawText: String, _ amount: Double?, _ unit: String? = nil, name: String? = nil) -> IngredientLine {
        IngredientLine(id: UUID(), rawText: rawText, amount: amount, unit: unit, ingredientName: name)
    }

    private func scaledText(_ rawText: String, _ amount: Double?, _ unit: String? = nil, by factor: Double) -> String {
        line(rawText, amount, unit, name: "flour").scaled(by: factor).rawText
    }

    // MARK: the text

    func testReplacesTheAmountAtTheStartOfTheText() {
        XCTAssertEqual(scaledText("2 cups flour", 2, "cups", by: 2), "4 cups flour")
        XCTAssertEqual(scaledText("2.5 dl milk", 2.5, "dl", by: 2), "5 dl milk")
        XCTAssertEqual(scaledText("½ cup sugar", 0.5, "cup", by: 3), "1½ cup sugar")
        XCTAssertEqual(scaledText("1 1/2 tbsp oil", 1.5, "tbsp", by: 2), "3 tbsp oil")
        XCTAssertEqual(scaledText("1½ tsp salt", 1.5, "tsp", by: 2), "3 tsp salt")
        XCTAssertEqual(scaledText("100g butter", 100, "g", by: 2), "200g butter")
        XCTAssertEqual(scaledText("2,5 dl Milch", 2.5, "dl", by: 2), "5 dl Milch")
        XCTAssertEqual(scaledText("1,000 g flour", 1000, "g", by: 2), "2000 g flour")
        XCTAssertEqual(scaledText("  3 eggs", 3, by: 2), "  6 eggs")
    }

    func testReplacesTheAmountWhereverItIsWritten() {
        let flour = line("Il vous faut 250 g de farine, tamisée", 250, "g", name: "farine")

        XCTAssertEqual(flour.scaled(by: 2).rawText, "Il vous faut 500 g de farine, tamisée")
    }

    /// #234 review: replacing the number keeps the rest of the line, where rebuilding it from
    /// amount, unit and name gave "4 cups a good 2 cups".
    func testKeepsTheRestOfALineWithoutAName() {
        XCTAssertEqual(line("a good 2 cups, sifted", 2, "cups").scaled(by: 2).rawText, "a good 4 cups, sifted")
    }

    func testSkipsANumberThatIsNotTheAmount() {
        // The model read "2" as the amount of "1 (2 lb) chicken"; the leading "1" isn't it.
        let chicken = line("1 (2 lb) chicken", 2, "lb", name: "chicken")

        XCTAssertEqual(chicken.scaled(by: 2).rawText, "1 (4 lb) chicken")
    }

    func testDoesNotReplaceTheAmountInsideALongerNumber() {
        XCTAssertEqual(scaledText("Bake at 200 °C: 2 cups flour", 2, "cups", by: 2), "Bake at 200 °C: 4 cups flour")
    }

    /// #234 review: an amount typed as 0.67 for a line written "⅔ cup" still replaces the ⅔.
    func testMatchesTheWrittenAmountWithinOnePercent() {
        XCTAssertEqual(scaledText("⅔ cup sugar, packed", 0.67, "cup", by: 2), "1⅓ cup sugar, packed")
    }

    func testBuildsTheLineWhenTheAmountIsNotWritten() {
        XCTAssertEqual(line("a dozen eggs", 12, name: "eggs").scaled(by: 0.5).rawText, "6 eggs")
    }

    func testPutsTheFactorInFrontOfALineWithoutANameOrAWrittenAmount() {
        XCTAssertEqual(line("a can", 1, "can").scaled(by: 2).rawText, "2 × a can")
        XCTAssertEqual(line("a can", 1, "can").scaled(by: 1.5).rawText, "1½ × a can")
    }

    /// #251: the model gave "snufje zout" an amount of 1, which scaled to "1½ snufje zout".
    func testLeavesAVagueUnitWithoutAWrittenAmountUnchanged() {
        let salt = line("snufje zout", 1, "snufje", name: "zout")
        let pinch = line("a pinch of salt", 1, "pinch", name: "salt")

        XCTAssertEqual(salt.scaled(by: 1.5), salt)
        XCTAssertEqual(pinch.scaled(by: 2), pinch)
    }

    func testScalesAVagueUnitWithAWrittenAmount() {
        XCTAssertEqual(line("2 snufjes zout", 2, "snufjes", name: "zout").scaled(by: 1.5).rawText, "3 snufjes zout")
    }

    func testStillBuildsACountedUnitWithoutAWrittenAmount() {
        XCTAssertEqual(line("a clove of garlic", 1, "clove", name: "garlic").scaled(by: 2).rawText, "2 clove garlic")
    }

    func testLeavesALineWithoutAnAmountUnchanged() {
        let salt = line("salt to taste", nil, name: "salt")

        XCTAssertEqual(salt.scaled(by: 2), salt)
    }

    func testLeavesTheLineUnchangedAtTheRecipesOwnServings() {
        let flour = line("⅔ cup flour", 2.0 / 3, "cup", name: "flour")

        XCTAssertEqual(flour.scaled(by: 1), flour)
    }

    func testKeepsTheExactAmountForTheWeightView() throws {
        let flour = line("⅓ cup flour", 1.0 / 3, "cup", name: "flour").scaled(by: 1.25)

        XCTAssertEqual(try XCTUnwrap(flour.amount), 5.0 / 12, accuracy: 1e-9)
        XCTAssertEqual(flour.rawText, "⅓ cup flour")
    }

    // MARK: rounding

    func testCupsRoundToKitchenFractions() {
        XCTAssertEqual(scaledText("⅔ cup flour", 2.0 / 3, "cup", by: 2), "1⅓ cup flour")
        XCTAssertEqual(scaledText("1 cup milk", 1, "cup", by: 1.6), "1⅔ cup milk")
        XCTAssertEqual(scaledText("1 cup milk", 1, "cup", by: 2.9), "3 cup milk")
        // 5/12 is as close to ⅓ as to ½: the smaller wins.
        XCTAssertEqual(scaledText("⅓ cup flour", 1.0 / 3, "cup", by: 1.25), "⅓ cup flour")
    }

    func testCupsNeverRoundToZero() {
        XCTAssertEqual(scaledText("¼ cup oil", 0.25, "cup", by: 0.25), "¼ cup oil")
    }

    func testSpoonsBelowOneAlsoComeInEighths() {
        XCTAssertEqual(scaledText("¼ tsp salt", 0.25, "tsp", by: 0.5), "⅛ tsp salt")
        XCTAssertEqual(scaledText("¼ tsp salt", 0.25, "tsp", by: 0.25), "⅛ tsp salt")
        XCTAssertEqual(scaledText("1 tbsp oil", 1, "tbsp", by: 1.1), "1 tbsp oil")
    }

    func testSpoonsInAnotherLanguageRoundLikeSpoons() {
        XCTAssertEqual(scaledText("¼ cuillère à café de sel", 0.25, "cuillère à café", by: 0.5), "⅛ cuillère à café de sel")
        XCTAssertEqual(scaledText("1 EL Öl", 1, "EL", by: 0.5), "½ EL Öl")
    }

    func testMetricUnitsRoundToWholeNumbersAndTensAbove100() {
        XCTAssertEqual(scaledText("250 g flour", 250, "g", by: 1.6), "400 g flour")
        XCTAssertEqual(scaledText("250 g flour", 250, "g", by: 1.57), "390 g flour")
        // 375 is a tie: the smaller wins.
        XCTAssertEqual(scaledText("250 g flour", 250, "g", by: 1.5), "370 g flour")
        XCTAssertEqual(scaledText("30 ml milk", 30, "ml", by: 1.5), "45 ml milk")
        XCTAssertEqual(scaledText("7 g yeast", 7, "g", by: 0.5), "3 g yeast")
        XCTAssertEqual(scaledText("1 l stock", 1, "l", by: 0.25), "1 l stock")
    }

    func testOtherImperialUnitsRoundToOneDecimal() {
        XCTAssertEqual(scaledText("1 lb beef", 1, "lb", by: 1.76), "1.8 lb beef")
        XCTAssertEqual(scaledText("1 lb beef", 1, "lb", by: 1.75), "1.7 lb beef")
        XCTAssertEqual(scaledText("3 oz cheese", 3, "oz", by: 0.5), "1½ oz cheese")
        XCTAssertEqual(scaledText("1 oz cheese", 1, "oz", by: 0.01), "0.1 oz cheese")
    }

    func testCountedAmountsRoundToTheNearestHalf() {
        XCTAssertEqual(scaledText("3 eggs", 3, by: 1.5), "4½ eggs")
        XCTAssertEqual(scaledText("2 cloves garlic", 2, "cloves", by: 1.6), "3 cloves garlic")
        XCTAssertEqual(scaledText("1 egg", 1, by: 0.25), "½ egg")
        // 2.25 is as close to 2 as to 2½.
        XCTAssertEqual(scaledText("3 eggs", 3, by: 0.75), "2 eggs")
    }
}
