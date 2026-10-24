@testable import RecipeRaccoon
import XCTest

/// Amounts written in two parts (#216).
final class CompoundAmountTests: XCTestCase {
    private func combined(_ line: String, file: StaticString = #filePath, line testLine: UInt = #line) throws -> (Double, String) {
        guard case let .combined(value, unit) = try XCTUnwrap(CompoundAmount(in: line), file: file, line: testLine) else {
            XCTFail("\"\(line)\" isn't combined", file: file, line: testLine)
            return (0, "")
        }
        return (value, unit)
    }

    func testAddsTheSecondPartInTheFirstPartsUnit() throws {
        let (cups, cupUnit) = try combined("1 cup plus 2 tablespoons flour")
        XCTAssertEqual(cups, 1.125, accuracy: 1e-9)
        XCTAssertEqual(cupUnit, "cup")

        let (pounds, poundUnit) = try combined("1 lb 4 oz ground beef")
        XCTAssertEqual(pounds, 1.25, accuracy: 1e-9)
        XCTAssertEqual(poundUnit, "lb")
    }

    func testReadsTheJoiningWordsAndNumberShapes() throws {
        XCTAssertEqual(try combined("1/2 cup + 1 tbsp milk").0, 0.5 + 1.0 / 16, accuracy: 1e-9)
        XCTAssertEqual(try combined("2 tbsp+1 tsp sugar").0, 2 + 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(try combined("1 ½ cups and 2 tablespoons water").0, 1.625, accuracy: 1e-9)
        XCTAssertEqual(try combined("1 EL und 1 TL Zucker").0, 1 + 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(try combined("1 kg 250 g de farine").0, 1.25, accuracy: 1e-9)
        XCTAssertEqual(try combined("1 lb, 4 oz minced beef").0, 1.25, accuracy: 1e-9)
        XCTAssertEqual(try combined("Il vous faut 1 tasse plus 2 c. à s. de sucre").1, "tasse")
    }

    func testAWeightAndAVolumeGiveNoAmount() {
        XCTAssertEqual(CompoundAmount(in: "1 cup plus 50 g sugar"), .uncombinable)
    }

    func testAUnitWithoutASizeGivesNoAmount() {
        XCTAssertEqual(CompoundAmount(in: "1 tbsp plus 1 pinch salt"), .uncombinable)
    }

    func testOrdinaryLinesAreNotCompound() {
        for line in [
            "2 cups flour",
            "2 tbsp butter and 1 tsp salt",
            "1 to 2 cups stock",
            "1 cup (240 ml) milk",
            "1 cup/240 ml milk",
            "1 (14 oz) can tomatoes",
            "2 eggs and 1 cup milk",
            "1,000 g flour",
            "a pinch of salt",
            // The same amount in the other system, not a sum (#247 review).
            "1 cup 250 ml milk",
            "1 tbsp 15 ml oil",
            // A container and its size: the model's count stays (#247 review).
            "1 can 14 oz beans",
            "1 box 200 g flour",
        ] {
            XCTAssertNil(CompoundAmount(in: line), line)
        }
    }
}
