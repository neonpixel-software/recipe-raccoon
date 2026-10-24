@testable import RecipeRaccoon
import XCTest

final class IngredientAmountParserTests: XCTestCase {
    func testParsesWholeAndDecimalNumbers() {
        XCTAssertEqual(IngredientAmountParser.parse("2")?.value, 2)
        XCTAssertEqual(IngredientAmountParser.parse(" 1.5 ")?.value, 1.5)
    }

    func testParsesSimpleFractions() {
        XCTAssertEqual(IngredientAmountParser.parse("1/2")?.value, 0.5)
        XCTAssertEqual(IngredientAmountParser.parse("3/4")?.value, 0.75)
        XCTAssertEqual(IngredientAmountParser.parse("1\u{2044}4")?.value, 0.25)
    }

    func testParsesMixedNumbers() {
        XCTAssertEqual(IngredientAmountParser.parse("1 1/2")?.value, 1.5)
        XCTAssertEqual(IngredientAmountParser.parse("2 3/4")?.value, 2.75)
    }

    func testParsesVulgarFractionCharacters() throws {
        XCTAssertEqual(IngredientAmountParser.parse("½")?.value, 0.5)
        XCTAssertEqual(IngredientAmountParser.parse("¼")?.value, 0.25)
        XCTAssertEqual(IngredientAmountParser.parse("⅛")?.value, 0.125)
        XCTAssertEqual(try XCTUnwrap(IngredientAmountParser.parse("⅓")?.value), 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(IngredientAmountParser.parse("1 ⅔")?.value), 5.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(IngredientAmountParser.parse("1¾")?.value, 1.75)
    }

    func testSplitsUnitWrittenAfterTheNumber() {
        XCTAssertEqual(IngredientAmountParser.parse("100g"), .init(value: 100, unit: "g"))
        XCTAssertEqual(IngredientAmountParser.parse("250 ml"), .init(value: 250, unit: "ml"))
        XCTAssertEqual(IngredientAmountParser.parse("1/2 tsp."), .init(value: 0.5, unit: "tsp."))
        XCTAssertNil(IngredientAmountParser.parse("2")?.unit)
    }

    func testKeepsQuantityBeforeMultiWordUnit() {
        XCTAssertEqual(IngredientAmountParser.parse("1/2 fl oz"), .init(value: 0.5, unit: "fl oz"))
        XCTAssertEqual(IngredientAmountParser.parse("1/2 c. à s."), .init(value: 0.5, unit: "c. à s."))
        XCTAssertEqual(IngredientAmountParser.parse("1/2 cuillère à soupe"), .init(value: 0.5, unit: "cuillère à soupe"))
    }

    func testParsesDecimalComma() {
        XCTAssertEqual(IngredientAmountParser.parse("2,5")?.value, 2.5)
        XCTAssertEqual(IngredientAmountParser.parse("0,25 l"), .init(value: 0.25, unit: "l"))
    }

    func testParsesThousandsSeparators() {
        XCTAssertEqual(IngredientAmountParser.parse("1,000")?.value, 1000)
        XCTAssertEqual(IngredientAmountParser.parse("1,000 g"), .init(value: 1000, unit: "g"))
        XCTAssertEqual(IngredientAmountParser.parse("12,500.5")?.value, 12500.5)
        XCTAssertEqual(IngredientAmountParser.parse("1,000,000")?.value, 1_000_000)
        XCTAssertNil(IngredientAmountParser.parse("1,0000"))
        XCTAssertNil(IngredientAmountParser.parse("1000,000"))
        XCTAssertNil(IngredientAmountParser.parse("1,00,000"))
    }

    func testRejectsUnparseableText() {
        XCTAssertNil(IngredientAmountParser.parse(""))
        XCTAssertNil(IngredientAmountParser.parse("a few"))
        XCTAssertNil(IngredientAmountParser.parse("2-3"))
        XCTAssertNil(IngredientAmountParser.parse("1/0"))
        XCTAssertNil(IngredientAmountParser.parse("1/2/3"))
        XCTAssertNil(IngredientAmountParser.parse("1 2 3"))
        XCTAssertNil(IngredientAmountParser.parse("x½"))
        XCTAssertNil(IngredientAmountParser.parse("2 cups 3"))
        XCTAssertNil(IngredientAmountParser.parse("-5"))
        XCTAssertNil(IngredientAmountParser.parse("0"))
    }
}
