@testable import RecipeRaccoon
import XCTest

final class CapturedServingsTests: XCTestCase {
    func testKeepsServingsStatedNextToAServingsWord() {
        XCTAssertEqual(CapturedServings.grounded("4", in: "Pancakes\nServes 4\n2 eggs"), 4)
        XCTAssertEqual(CapturedServings.grounded("4", in: "Servings: 4"), 4)
        XCTAssertEqual(CapturedServings.grounded("4", in: "Serves 4 people"), 4)
        XCTAssertEqual(CapturedServings.grounded("6", in: "Recette pour 6 personnes."), 6)
        XCTAssertEqual(CapturedServings.grounded("6", in: "Coupez en 6 grandes parts."), 6)
        XCTAssertEqual(CapturedServings.grounded("2", in: "Für 2 Portionen"), 2)
        XCTAssertEqual(CapturedServings.grounded("4", in: "Ingredientes (4 raciones)"), 4)
    }

    func testTakesTheLowerNumberOfARange() {
        XCTAssertEqual(CapturedServings.grounded("4", in: "Bananenbrood\n4–6 personen"), 4)
        XCTAssertEqual(CapturedServings.grounded("6", in: "4-6 Portionen"), 4)
        XCTAssertEqual(CapturedServings.grounded("4-6", in: "Serves 4 - 6"), 4)
    }

    func testKeepsAYield() {
        XCTAssertEqual(CapturedServings.grounded("12", in: "Makes 12 muffins\n200 g flour"), 12)
        XCTAssertEqual(CapturedServings.grounded("12 muffins", in: "Makes 12 muffins"), 12)
        XCTAssertEqual(CapturedServings.grounded("1", in: "Banana bread\n\nYield: 1 loaf\n\nIngredients:"), 1)
    }

    func testKeepsForANumberInAShortLineOfItsOwn() {
        XCTAssertEqual(CapturedServings.grounded("12", in: "Muffins\nVoor 12 muffins\n200 g bloem"), 12)
        XCTAssertEqual(CapturedServings.grounded("12", in: "Voor 12 grote muffins:"), 12)
        XCTAssertEqual(CapturedServings.grounded("4", in: "Für 4"), 4)
    }

    func testDropsANumberNotStatedAsServings() {
        let source = """
        Cookies
        4 eggs
        For 4 minutes, stir the butter.
        4. Bake for 4 minutes.
        """

        XCTAssertNil(CapturedServings.grounded("4", in: source))
    }

    /// #233 review: a sentence starting with "for" isn't a servings heading.
    func testDropsForANumberInASentence() {
        XCTAssertNil(CapturedServings.grounded("4", in: "For 4, stir well."))
        XCTAssertNil(CapturedServings.grounded("4", in: "For 4 large eggs, separate the yolks."))
        XCTAssertNil(CapturedServings.grounded("10", in: "Voor 10 minuten"))
    }

    /// #233 review: nutrition facts and ratios aren't servings.
    func testDropsAMeasureAfterAServingsWord() {
        XCTAssertNil(CapturedServings.grounded("99", in: "Per serving: 99 kcal"))
        XCTAssertNil(CapturedServings.grounded("1", in: "Serving size: 1 cup"))
        XCTAssertNil(CapturedServings.grounded("12", in: "Per portion: 12 g protein"))
    }

    func testDropsPartsBeforeTheNumberOrInTheSingular() {
        XCTAssertNil(CapturedServings.grounded("2", in: "Part 2: Assembly"))
        XCTAssertNil(CapturedServings.grounded("1", in: "1 part vermouth"))
    }

    func testDropsServingsNotInTheSource() {
        XCTAssertNil(CapturedServings.grounded("4", in: "Serves 6\n2 eggs"))
        XCTAssertNil(CapturedServings.grounded("4", in: "2 eggs, 1 cup milk"))
    }

    func testDropsServingsOutsideTheRange() {
        XCTAssertNil(CapturedServings.grounded("0", in: "Serves 0"))
        XCTAssertNil(CapturedServings.grounded("120", in: "Makes 120 cookies"))
        XCTAssertNil(CapturedServings.grounded("120", in: nil))
    }

    func testDoesNotMatchServingsInsideALongerNumber() {
        XCTAssertNil(CapturedServings.grounded("5", in: "Serves 1.5"))
        XCTAssertNil(CapturedServings.grounded("12", in: "Makes 120 cookies"))
        XCTAssertNil(CapturedServings.grounded("4", in: "Serves 104"))
    }

    func testLeavesAnEmptyAnswerNil() {
        XCTAssertNil(CapturedServings.grounded("", in: "Serves 4"))
        XCTAssertNil(CapturedServings.grounded("", in: nil))
    }

    func testKeepsServingsWithoutASource() {
        XCTAssertEqual(CapturedServings.grounded("4", in: nil), 4)
    }
}
