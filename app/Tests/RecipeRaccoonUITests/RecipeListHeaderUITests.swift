import XCTest

/// The recipe list's header stays pinned to the top of the window: when the list shows an
/// empty or error state instead of recipes (#96, #98), and while the recipes scroll under it.
/// The empty and error states only take the height they need, and without the column filling
/// the window the whole column, header included, was centered in it. ViewInspector can't see
/// laid-out positions, hence a UI test.
final class RecipeListHeaderUITests: XCTestCase {
    /// How many recipes the manyRecipes scenario seeds (UITestScenario.manyRecipes).
    private static let manyRecipesCount = 40

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testHeaderStaysAtTopWhenThereAreNoRecipes() {
        let app = launch(scenario: "empty")

        XCTAssertTrue(text("No Recipes Yet", in: app).waitForExistence(timeout: 10))
        assertHeaderIsAtTop(in: app)
    }

    @MainActor
    func testHeaderStaysAtTopWhenNoRecipeHasTheSelectedTag() {
        let app = launch(scenario: "noMatchingTag")

        // The scenario starts with the Dinner tag selected (UITestScenario.selectedTagName).
        let tagChip = app.buttons["Dinner"]
        XCTAssertTrue(tagChip.waitForExistence(timeout: 10))
        XCTAssertTrue(tagChip.isSelected, "The Dinner chip isn't selected")

        XCTAssertTrue(text("No Recipes With This Tag", in: app).waitForExistence(timeout: 10))
        assertHeaderIsAtTop(in: app)
    }

    @MainActor
    func testHeaderStaysAtTopWhenRecipesFailToLoad() {
        let app = launch(scenario: "loadError")

        XCTAssertTrue(text("Couldn't Load Recipes", in: app).waitForExistence(timeout: 10))
        assertHeaderIsAtTop(in: app)
    }

    @MainActor
    func testHeaderStaysAtTopWhileTheRecipesScroll() {
        let app = launch(scenario: "manyRecipes")

        XCTAssertTrue(app.buttons["Recipe 01"].waitForExistence(timeout: 10))
        // The first recipe that starts below the window: once it's on screen, the list has really
        // moved. Waiting for it also rides out the moment after a scroll when the macOS runner's
        // accessibility snapshot comes back without the rows: an earlier check read Recipe 01's
        // frame right then and failed with no buttons but the window's zoom button. Found rather
        // than fixed, because an iPad Pro 13 fits Recipe 12 on screen before scrolling.
        // Nothing moves yet, so reading frames can't race; isHittable on an off-screen element
        // made XCTest retry for 14 s on macOS.
        let windowBottom = app.windows.firstMatch.frame.maxY
        let laterName = (2...Self.manyRecipesCount).lazy.map { String(format: "Recipe %02d", $0) }.first { name in
            let row = app.buttons[name]
            return !row.exists || row.frame.minY >= windowBottom
        }
        guard let laterName else { return XCTFail("All \(Self.manyRecipesCount) recipes fit on screen, so the list can't scroll") }
        let laterRecipe = app.buttons[laterName]
        let headerBefore = assertHeaderIsAtTop(in: app)

        let list = app.scrollViews["RecipeList"]
        XCTAssertTrue(list.exists, "The recipe list is missing")
        // A synthesized scroll on GitHub's macOS runner sometimes moves the list less, or not at
        // all, so scroll in steps until that recipe is on screen. However far it goes, the header
        // has to stay put. On iOS each step is a slow drag over a third of the list: a swipe's
        // momentum could carry the recipe past the top while the runner was still settling it,
        // and the lazy list then unloads the row, so no later check can find it (#164).
        var scrolled = false
        for _ in 0..<8 where !scrolled {
            #if os(macOS)
            list.scroll(byDeltaX: 0, deltaY: -600)
            #else
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
            #endif
            scrolled = waitUntilFullyInside(laterRecipe, window: app.windows.firstMatch.frame, timeout: 3)
        }
        let whereLater = laterRecipe.exists ? "at \(laterRecipe.frame), window bottom \(windowBottom)" : "not loaded"
        XCTAssertTrue(scrolled, "The recipe list didn't scroll: after 8 scrolls \(laterName) is \(whereLater), so this checked nothing")
        let headerAfter = assertHeaderIsAtTop(in: app)
        XCTAssertEqual(headerAfter.minY, headerBefore.minY, accuracy: 1, "The header moved while the list scrolled")
    }

    /// Waits until the element's frame lies within the window. Not isHittable: on the GitHub
    /// iOS runner, asking that of a row still settling after a swipe failed the test outright
    /// ("Activation point invalid") instead of returning false.
    @MainActor
    private func waitUntilFullyInside(_ element: XCUIElement, window: CGRect, timeout: TimeInterval) -> Bool {
        let inside = NSPredicate { _, _ in
            element.exists && window.contains(element.frame)
        }
        let expectation = XCTNSPredicateExpectation(predicate: inside, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
