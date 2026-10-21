import XCTest

/// The form's Servings row (Phase 15.1): Set Servings, the stepper and clearing it; and scaling
/// on the recipe screen (Phase 15.3). Clicks don't reach the app on GitHub's macOS runner, so
/// the taps run on iOS; the unit tests cover the same actions on both platforms.
final class RecipeServingsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testSetChangeAndClearServingsInTheForm() throws {
        #if os(macOS)
        throw XCTSkip("Needs taps, which the macOS runner can't deliver")
        #else
        let app = launch(scenario: "recipeWithPhotosDetail")
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()

        let set = app.buttons["Set Servings"]
        XCTAssertTrue(set.waitForExistence(timeout: 10), "A recipe without servings doesn't offer Set Servings")
        set.tap()

        let stepper = app.steppers["servingsStepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Set Servings didn't show the stepper")
        XCTAssertEqual(stepper.value as? String, "4")
        // The stepper's buttons: − first, then +.
        stepper.buttons.element(boundBy: 1).tap()
        XCTAssertEqual(stepper.value as? String, "5")

        app.buttons["Clear Servings"].tap()
        XCTAssertTrue(set.waitForExistence(timeout: 5), "Clearing didn't bring Set Servings back")
        XCTAssertFalse(stepper.exists)
        #endif
    }

    @MainActor
    func testMoreServingsScaleTheIngredients() {
        let app = launch(scenario: "servingsDetail")
        let shown = app.staticTexts["shownServings"]
        XCTAssertTrue(shown.waitForExistence(timeout: 10), "The recipe screen shows no servings")
        XCTAssertEqual(shown.label, "2")
        XCTAssertTrue(app.staticTexts["⅔ cup flour"].exists)
        XCTAssertFalse(app.staticTexts["(recipe: 2)"].exists, "The recipe's own number shows as changed")
        #if os(iOS)
        let more = app.buttons["More Servings"]
        more.tap()
        more.tap()

        XCTAssertEqual(shown.label, "4")
        XCTAssertTrue(app.staticTexts["1⅓ cup flour"].waitForExistence(timeout: 5), "The flour didn't double")
        XCTAssertTrue(app.staticTexts["⅔ cup flour"].exists, "The original line isn't under the scaled one")
        XCTAssertTrue(app.staticTexts["(recipe: 2)"].exists)
        XCTAssertTrue(app.staticTexts["salt to taste"].exists)

        app.buttons["Reset Servings"].tap()
        XCTAssertEqual(shown.label, "2")
        XCTAssertFalse(app.staticTexts["1⅓ cup flour"].exists)
        #endif
    }
}
