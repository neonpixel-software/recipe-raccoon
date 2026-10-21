@testable import RecipeRaccoon
import XCTest

private struct NoOpCreateRecipeUseCase: CreateRecipeUseCase {
    func execute(_: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {}
}

private struct NoOpUpdateRecipeUseCase: UpdateRecipeUseCase {
    func execute(_: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {}
}

private struct FakeDeleteRecipeUseCase: DeleteRecipeUseCase {
    var result: Result<Void, Error> = .success(())
    let onExecute: ((UUID) -> Void)?

    init(result: Result<Void, Error> = .success(()), onExecute: ((UUID) -> Void)? = nil) {
        self.result = result
        self.onExecute = onExecute
    }

    func execute(id: UUID) throws {
        onExecute?(id)
        try result.get()
    }
}

private struct NoOpFetchTagsUseCase: FetchTagsUseCase {
    func execute() throws -> [Tag] { [] }
}

private struct NoOpFindOrCreateTagUseCase: FindOrCreateTagUseCase {
    func execute(name: String) throws -> Tag {
        Tag(id: UUID(), name: name, isPreset: false)
    }
}

private struct UseCaseFailure: LocalizedError {
    var errorDescription: String? { "Something went wrong" }
}

private func makeViewModel(
    recipe: Recipe,
    deleteRecipeUseCase: FakeDeleteRecipeUseCase = FakeDeleteRecipeUseCase(),
    images: [UUID: Data] = [:]
) -> RecipeDetailViewModel {
    RecipeDetailViewModel(
        recipe: recipe,
        formDependencies: .testing(
            createRecipeUseCase: NoOpCreateRecipeUseCase(),
            updateRecipeUseCase: NoOpUpdateRecipeUseCase(),
            fetchTagsUseCase: NoOpFetchTagsUseCase(),
            findOrCreateTagUseCase: NoOpFindOrCreateTagUseCase()
        ),
        deleteRecipeUseCase: deleteRecipeUseCase,
        fetchPhotoImageUseCase: StubFetchPhotoImageUseCase(images: images)
    )
}

@MainActor
final class RecipeDetailViewModelTests: XCTestCase {
    func testDeleteSetsIsDeletedOnSuccess() {
        let recipe = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [])
        var deletedID: UUID?
        let viewModel = makeViewModel(recipe: recipe, deleteRecipeUseCase: FakeDeleteRecipeUseCase(onExecute: { deletedID = $0 }))

        viewModel.delete()

        XCTAssertTrue(viewModel.isDeleted)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(deletedID, recipe.id)
    }

    func testImageDataIsThePhotosImageOrNilWhenItIsntHere() {
        let here = RecipePhoto(id: UUID())
        let missing = RecipePhoto(id: UUID())
        let recipe = Recipe(id: UUID(), title: "Salad", ingredients: [], steps: [], source: .typed, tags: [], photos: [here, missing])
        let viewModel = makeViewModel(recipe: recipe, images: [here.id: Data([3])])

        XCTAssertEqual(viewModel.imageData(for: here), Data([3]))
        XCTAssertNil(viewModel.imageData(for: missing))
    }

    func testDeleteSetsErrorMessageAndLeavesIsDeletedFalseOnFailure() {
        let recipe = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [])
        let viewModel = makeViewModel(recipe: recipe, deleteRecipeUseCase: FakeDeleteRecipeUseCase(result: .failure(UseCaseFailure())))

        viewModel.delete()

        XCTAssertFalse(viewModel.isDeleted)
        XCTAssertEqual(viewModel.errorMessage, "Something went wrong")
    }

    func testMakeEditFormViewModelPrefillsFromCurrentRecipe() {
        let recipe = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [])
        let viewModel = makeViewModel(recipe: recipe)

        let formViewModel = viewModel.makeEditFormViewModel()

        XCTAssertEqual(formViewModel.title, "Pancakes")
    }

    // MARK: servings (Phase 15.3)

    private func flatbread(servings: Int?) -> Recipe {
        Recipe(
            id: UUID(),
            title: "Flatbread",
            servings: servings,
            ingredients: [
                IngredientLine(id: UUID(), rawText: "⅔ cup flour", amount: 2.0 / 3, unit: "cup", ingredientName: "flour"),
                IngredientLine(id: UUID(), rawText: "salt to taste", ingredientName: "salt"),
            ],
            steps: [],
            source: .typed,
            tags: []
        )
    }

    func testStartsAtTheRecipesOwnServingsUnscaled() {
        let recipe = flatbread(servings: 2)
        let viewModel = makeViewModel(recipe: recipe)

        XCTAssertEqual(viewModel.shownServings, 2)
        XCTAssertFalse(viewModel.isScaled)
        XCTAssertEqual(viewModel.shownIngredients, recipe.ingredients)
    }

    func testMoreServingsScaleTheAmountsAndResetGoesBack() throws {
        let recipe = flatbread(servings: 2)
        let viewModel = makeViewModel(recipe: recipe)

        viewModel.increaseServings()
        viewModel.increaseServings()

        XCTAssertEqual(viewModel.shownServings, 4)
        XCTAssertTrue(viewModel.isScaled)
        XCTAssertEqual(viewModel.shownIngredients.map(\.rawText), ["1⅓ cup flour", "salt to taste"])
        // The weight view weighs the exact amount.
        XCTAssertEqual(try XCTUnwrap(viewModel.shownIngredients[0].amount), 4.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(viewModel.recipe, recipe, "Scaling changed the saved recipe")

        viewModel.resetServings()

        XCTAssertEqual(viewModel.shownServings, 2)
        XCTAssertEqual(viewModel.shownIngredients, recipe.ingredients)
    }

    func testServingsStayWithinOneToNinetyNine() {
        let low = makeViewModel(recipe: flatbread(servings: 1))
        XCTAssertFalse(low.canDecreaseServings)
        low.decreaseServings()
        XCTAssertEqual(low.shownServings, 1)

        let high = makeViewModel(recipe: flatbread(servings: 99))
        XCTAssertFalse(high.canIncreaseServings)
        high.increaseServings()
        XCTAssertEqual(high.shownServings, 99)
        high.decreaseServings()
        XCTAssertEqual(high.shownServings, 98)
    }

    func testARecipeWithoutServingsCannotScale() {
        let recipe = flatbread(servings: nil)
        let viewModel = makeViewModel(recipe: recipe)

        viewModel.increaseServings()

        XCTAssertNil(viewModel.shownServings)
        XCTAssertFalse(viewModel.canIncreaseServings)
        XCTAssertFalse(viewModel.canDecreaseServings)
        XCTAssertFalse(viewModel.isScaled)
        XCTAssertEqual(viewModel.shownIngredients, recipe.ingredients)
    }

    func testAnEditShowsTheRecipesNewServings() {
        var recipe = flatbread(servings: 2)
        let viewModel = makeViewModel(recipe: recipe)
        viewModel.increaseServings()

        recipe.servings = 6
        viewModel.recipe = recipe

        XCTAssertEqual(viewModel.shownServings, 6)
        XCTAssertFalse(viewModel.isScaled)
    }
}
