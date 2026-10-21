@testable import RecipeRaccoon
import XCTest

final class IngredientAmountFormatterTests: XCTestCase {
    func testFormatsWholeNumbersWithoutADecimalPoint() {
        XCTAssertEqual(IngredientAmountFormatter.format(2), "2")
        XCTAssertEqual(IngredientAmountFormatter.format(250), "250")
    }

    func testFormatsCommonFractionsAsGlyphs() {
        XCTAssertEqual(IngredientAmountFormatter.format(0.5), "½")
        XCTAssertEqual(IngredientAmountFormatter.format(1.0 / 3), "⅓")
        XCTAssertEqual(IngredientAmountFormatter.format(5.0 / 3), "1⅔")
        XCTAssertEqual(IngredientAmountFormatter.format(2.75), "2¾")
        XCTAssertEqual(IngredientAmountFormatter.format(0.125), "⅛")
        XCTAssertEqual(IngredientAmountFormatter.format(3.875), "3⅞")
    }

    func testFormatsOtherAmountsWithAtMostTwoDecimals() {
        XCTAssertEqual(IngredientAmountFormatter.format(0.3), "0.3")
        XCTAssertEqual(IngredientAmountFormatter.format(1.2), "1.2")
        XCTAssertEqual(IngredientAmountFormatter.format(1.0 / 6), "0.17")
        XCTAssertEqual(IngredientAmountFormatter.format(2.999), "3")
    }

    func testKeepsATinyAmountRatherThanRoundingItToZero() {
        XCTAssertEqual(IngredientAmountFormatter.format(0.001), "0.001")
        XCTAssertEqual(IngredientAmountFormatter.format(1e-7), "1e-07")
    }

    func testShowsAmountsTheParserWouldRejectFaithfully() {
        XCTAssertEqual(IngredientAmountFormatter.format(-0.5), "-0.5")
        XCTAssertEqual(IngredientAmountFormatter.format(0), "0.0")
    }

    func testFormattedAmountsParseBackToTheSameValue() throws {
        for amount in [0.5, 1.0 / 3, 5.0 / 3, 2.75, 0.125, 0.3, 12] {
            let formatted = IngredientAmountFormatter.format(amount)
            let parsed = try XCTUnwrap(IngredientAmountParser.parse(formatted), formatted)
            XCTAssertEqual(parsed.value, amount, accuracy: 1e-9, formatted)
            XCTAssertNil(parsed.unit, formatted)
        }
    }
}
