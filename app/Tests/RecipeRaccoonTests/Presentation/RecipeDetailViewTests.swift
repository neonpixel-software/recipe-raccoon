@testable import RecipeRaccoon
import SwiftUI
import ViewInspector
import XCTest

private struct NoOpCreateRecipeUseCase: CreateRecipeUseCase {
    func execute(_: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {}
}

private struct NoOpUpdateRecipeUseCase: UpdateRecipeUseCase {
    func execute(_: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {}
}

private final class RecordingDeleteRecipeUseCase: DeleteRecipeUseCase {
    private(set) var executedIDs: [UUID] = []

    func execute(id: UUID) throws {
        executedIDs.append(id)
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

private func makeViewModel(
    recipe: Recipe,
    deleteRecipeUseCase: DeleteRecipeUseCase = RecordingDeleteRecipeUseCase(),
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
final class RecipeDetailViewTests: XCTestCase {
    private func makeRecipe(
        ingredients: [IngredientLine] = [],
        equipment: [String] = [],
        steps: [String] = [],
        tags: [Tag] = []
    ) -> Recipe {
        Recipe(id: UUID(), title: "Waffles", ingredients: ingredients, equipment: equipment, steps: steps, source: .typed, tags: tags)
    }

    func testEmptyIngredientsAndStepsShowPlaceholderText() throws {
        let viewModel = makeViewModel(recipe: makeRecipe())
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertNoThrow(try sut.inspect().find(text: "No ingredients listed"))
        XCTAssertNoThrow(try sut.inspect().find(text: "No steps listed"))
    }

    func testPopulatedIngredientsAndStepsRenderContent() throws {
        let recipe = makeRecipe(
            ingredients: [IngredientLine(id: UUID(), rawText: "2 cups flour")],
            steps: ["Mix", "Cook"]
        )
        let viewModel = makeViewModel(recipe: recipe)
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertNoThrow(try sut.inspect().find(text: "2 cups flour"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Mix"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Cook"))
    }

    func testEquipmentRendersInItsOwnSection() throws {
        let viewModel = makeViewModel(recipe: makeRecipe(equipment: ["waffle iron"]))
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertNoThrow(try sut.inspect().find(text: "EQUIPMENT"))
        XCTAssertNoThrow(try sut.inspect().find(text: "waffle iron"))
    }

    func testEquipmentSectionIsHiddenWhenEmpty() throws {
        let viewModel = makeViewModel(recipe: makeRecipe())
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertThrowsError(try sut.inspect().find(text: "EQUIPMENT"))
    }

    func testAssignedTagsRenderAsChips() throws {
        let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let recipe = makeRecipe(tags: [breakfast])
        let viewModel = makeViewModel(recipe: recipe)
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertNoThrow(try sut.inspect().find(text: "Breakfast"))
    }

    func testTappingDeleteTogglesConfirmationDialogAndConfirmingItCallsDelete() throws {
        let deleteUseCase = RecordingDeleteRecipeUseCase()
        let recipe = makeRecipe()
        let viewModel = makeViewModel(recipe: recipe, deleteRecipeUseCase: deleteUseCase)
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertThrowsError(try sut.inspect().find(ViewType.ConfirmationDialog.self))

        try sut.inspect().find(button: "Delete").tap()
        XCTAssertTrue(viewModel.isPresentingDeleteConfirmation)

        let dialog = try sut.inspect().find(ViewType.ConfirmationDialog.self)
        XCTAssertEqual(try dialog.title().string(), "Delete this recipe?")
        try dialog.actions().find(button: "Delete").tap()

        XCTAssertEqual(deleteUseCase.executedIDs, [recipe.id])
        XCTAssertTrue(viewModel.isDeleted)
    }

    func testCancellingConfirmationDialogDoesNotCallDelete() throws {
        let deleteUseCase = RecordingDeleteRecipeUseCase()
        let viewModel = makeViewModel(recipe: makeRecipe(), deleteRecipeUseCase: deleteUseCase)
        let sut = RecipeDetailView(viewModel: viewModel)

        try sut.inspect().find(button: "Delete").tap()
        let dialog = try sut.inspect().find(ViewType.ConfirmationDialog.self)
        try dialog.actions().find(button: "Cancel").tap()

        XCTAssertTrue(deleteUseCase.executedIDs.isEmpty)
        XCTAssertFalse(viewModel.isDeleted)
    }

    func testTappingEditSetsPresentingEditOnViewModel() throws {
        let viewModel = makeViewModel(recipe: makeRecipe())
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertFalse(viewModel.isPresentingEdit)
        try sut.inspect().find(button: "Edit").tap()
        XCTAssertTrue(viewModel.isPresentingEdit)
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

    func testTheRecipesOwnServingsShowWithoutTheRecipeNote() throws {
        let sut = RecipeDetailView(viewModel: makeViewModel(recipe: flatbread(servings: 2)))

        XCTAssertNoThrow(try sut.inspect().find(text: "Servings"))
        XCTAssertNoThrow(try sut.inspect().find(text: "⅔ cup flour"))
        XCTAssertThrowsError(try sut.inspect().find(text: "(recipe: 2)"))
        XCTAssertThrowsError(try sut.inspect().find(viewWithAccessibilityLabel: "Reset Servings"))
    }

    func testMoreServingsShowTheScaledLineTheOriginalAndTheRecipesNumber() throws {
        let viewModel = makeViewModel(recipe: flatbread(servings: 2))
        let sut = RecipeDetailView(viewModel: viewModel)

        try sut.inspect().find(viewWithAccessibilityLabel: "More Servings").button().tap()
        try sut.inspect().find(viewWithAccessibilityLabel: "More Servings").button().tap()

        XCTAssertEqual(viewModel.shownServings, 4)
        XCTAssertNoThrow(try sut.inspect().find(text: "1⅓ cup flour"))
        XCTAssertNoThrow(try sut.inspect().find(text: "⅔ cup flour"))
        XCTAssertNoThrow(try sut.inspect().find(text: "(recipe: 2)"))
        XCTAssertNoThrow(try sut.inspect().find(text: "salt to taste"))

        try sut.inspect().find(viewWithAccessibilityLabel: "Reset Servings").button().tap()
        XCTAssertEqual(viewModel.shownServings, 2)
        try sut.inspect().find(viewWithAccessibilityLabel: "Fewer Servings").button().tap()
        XCTAssertEqual(viewModel.shownServings, 1)
    }

    func testARecipeWithoutServingsOffersSetServingsWhichOpensEdit() throws {
        let viewModel = makeViewModel(recipe: flatbread(servings: nil))
        let sut = RecipeDetailView(viewModel: viewModel)

        XCTAssertThrowsError(try sut.inspect().find(viewWithAccessibilityLabel: "More Servings"))
        try sut.inspect().find(button: "Set Servings").tap()

        XCTAssertTrue(viewModel.isPresentingEdit)
    }

    func testARecipeWithoutIngredientsShowsNoServingsRow() throws {
        let sut = RecipeDetailView(viewModel: makeViewModel(recipe: makeRecipe()))

        XCTAssertThrowsError(try sut.inspect().find(button: "Set Servings"))
    }

    /// Regression guard for #89: the list builds the view model inside a NavigationLink destination, which runs
    /// again on every list re-render. The view must own the first instance (@State); with
    /// @Bindable it switched to the new one and lost its state.
    func testDetailOwnsItsViewModelAsState() {
        let sut = RecipeDetailView(viewModel: makeViewModel(recipe: makeRecipe()))
        let storage = Mirror(reflecting: sut).children.first { $0.label == "_viewModel" }?.value
        XCTAssertTrue(storage is State<RecipeDetailViewModel>)
    }

    func testPhotoColumnTakesItsShareOfAWideWindowUpToTheGalleryLimit() {
        XCTAssertEqual(RecipeDetailView.photoColumnWidth(in: CGSize(width: 1000, height: 800), photoCount: 2), 420)
        XCTAssertEqual(RecipeDetailView.photoColumnWidth(in: CGSize(width: 1600, height: 800), photoCount: 2), RecipePhotoGallery.maxWidth)
    }

    func testPhotoColumnNarrowsSoThePhotoFitsAShortWindow() {
        // 300 pt tall: 40 pt of margins and 17 pt of dots leave 243 pt for a 4:3 page.
        XCTAssertEqual(RecipeDetailView.photoColumnWidth(in: CGSize(width: 1000, height: 300), photoCount: 2), 324)
        // A single photo has no dots: 250 pt tall leaves 210 pt.
        XCTAssertEqual(RecipeDetailView.photoColumnWidth(in: CGSize(width: 1000, height: 250), photoCount: 1), 280)
        XCTAssertEqual(RecipeDetailView.photoColumnWidth(in: CGSize(width: 1000, height: 30), photoCount: 1), 0)
    }
}
