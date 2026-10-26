@testable import RecipeRaccoon
import XCTest

/// When an ingredient row shows the line it was loaded from (#215).
final class IngredientSourceLineTests: XCTestCase {
    private func shown(_ rawText: String, _ amount: Double?, _ unit: String?, _ name: String?) -> String? {
        IngredientSourceLine.shown(for: IngredientLine(id: UUID(), rawText: rawText, amount: amount, unit: unit, ingredientName: name))
    }

    func testALineThatIsItsFieldsIsHidden() {
        XCTAssertNil(shown("2 cups flour", 2, "cup", "flour"))
        XCTAssertNil(shown("1/2 cup sugar", 0.5, "cup", "sugar"))
        XCTAssertNil(shown("1 ½ tbsp Olive Oil", 1.5, "tablespoon", "olive oil"))
        XCTAssertNil(shown("0,5 l Milch", 0.5, "l", "Milch"))
        XCTAssertNil(shown("100g butter", 100, "g", "butter"))
        XCTAssertNil(shown("3 eggs", 3, nil, "eggs"))
        XCTAssertNil(shown("salt", nil, nil, "salt"))
        XCTAssertNil(shown("1 can tomatoes", 1, "can", "tomatoes"))
    }

    func testConnectingWordsBetweenUnitAndNameAreAllowed() {
        XCTAssertNil(shown("250 g de farine", 250, "g", "farine"))
        XCTAssertNil(shown("2 cl d'huile", 2, "cl", "huile"))
        XCTAssertNil(shown("1 cup of milk", 1, "cup", "milk"))
    }

    func testALineWithMoreThanItsFieldsIsShown() {
        XCTAssertEqual(shown("1 cup plus 2 tablespoons flour", 1.125, "cup", "flour"), "1 cup plus 2 tablespoons flour")
        XCTAssertEqual(shown("1 cup butter, softened", 1, "cup", "butter"), "1 cup butter, softened")
        XCTAssertEqual(shown("salt to taste", nil, nil, "salt"), "salt to taste")
    }

    func testALineTheFieldsDisagreeWithIsShown() {
        XCTAssertNotNil(shown("1 2/3 cups flour", 1.125, "cup", "flour"))
        XCTAssertNotNil(shown("2 tsp salt", 2, "tbsp", "salt"))
        XCTAssertNotNil(shown("2 cups flour", 2, "cup", "sugar"))
    }

    func testALineWithoutFieldsIsShown() {
        XCTAssertEqual(shown("  a handful of herbs ", nil, nil, nil), "a handful of herbs")
    }

    func testAnEmptyLineIsHidden() {
        XCTAssertNil(shown("", nil, nil, nil))
    }
}
