@testable import RecipeRaccoon
import XCTest

private struct NoOpCreateRecipeUseCase: CreateRecipeUseCase {
    func execute(_: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {}
}

private struct NoOpUpdateRecipeUseCase: UpdateRecipeUseCase {
    func execute(_: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {}
}

private struct NoOpFetchTagsUseCase: FetchTagsUseCase {
    func execute() throws -> [Tag] { [] }
}

private struct NoOpFindOrCreateTagUseCase: FindOrCreateTagUseCase {
    func execute(name: String) throws -> Tag {
        Tag(id: UUID(), name: name, isPreset: false)
    }
}

/// The form's Servings row (Phase 15.1).
@MainActor
final class RecipeFormViewModelServingsTests: XCTestCase {
    func testANewRecipeStartsWithoutServings() throws {
        let viewModel = makeViewModel(mode: .create)
        viewModel.title = "Pancakes"

        XCTAssertNil(viewModel.servings)
        XCTAssertNil(try XCTUnwrap(viewModel.save()).servings)
    }

    func testSetChangeAndClearServings() throws {
        let viewModel = makeViewModel(mode: .create)
        viewModel.title = "Pancakes"

        viewModel.setServings()
        XCTAssertEqual(viewModel.servings, RecipeFormViewModel.defaultServings)

        viewModel.changeServings(to: 6)
        XCTAssertEqual(try XCTUnwrap(viewModel.save()).servings, 6)

        viewModel.clearServings()
        XCTAssertNil(try XCTUnwrap(viewModel.save()).servings)
    }

    func testChangeServingsStaysWithinOneToNinetyNine() {
        let viewModel = makeViewModel(mode: .create)
        viewModel.setServings()

        viewModel.changeServings(to: 0)
        XCTAssertEqual(viewModel.servings, 1)

        viewModel.changeServings(to: 100)
        XCTAssertEqual(viewModel.servings, 99)
    }

    func testChangeServingsLeavesUnsetServingsUnset() {
        let viewModel = makeViewModel(mode: .create)

        viewModel.changeServings(to: 6)

        XCTAssertNil(viewModel.servings)
    }

    func testEditAndCaptureStartWithTheRecipesServings() throws {
        let recipe = Recipe(id: UUID(), title: "Bread", servings: 2, ingredients: [], steps: [], source: .typed, tags: [])

        for mode in [RecipeFormMode.edit(recipe), .capture(recipe)] {
            let viewModel = makeViewModel(mode: mode)
            XCTAssertEqual(viewModel.servings, 2)
            XCTAssertEqual(try XCTUnwrap(viewModel.save()).servings, 2)
        }
    }

    private func makeViewModel(mode: RecipeFormMode) -> RecipeFormViewModel {
        RecipeFormViewModel(mode: mode, dependencies: .testing(
            createRecipeUseCase: NoOpCreateRecipeUseCase(),
            updateRecipeUseCase: NoOpUpdateRecipeUseCase(),
            fetchTagsUseCase: NoOpFetchTagsUseCase(),
            findOrCreateTagUseCase: NoOpFindOrCreateTagUseCase()
        ))
    }
}
