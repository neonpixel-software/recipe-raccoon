import XCTest

/// The form's Servings row (Phase 15.1): Set Servings, the stepper and clearing it. Clicks
/// don't reach the app on GitHub's macOS runner, so this runs on iOS; the form's unit tests
/// cover the same actions on both platforms.
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
}
