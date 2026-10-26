@testable import RecipeRaccoon
import XCTest

private final class FakeCreateRecipeUseCase: CreateRecipeUseCase {
    var result: Result<Void, Error> = .success(())
    private(set) var createdRecipes: [Recipe] = []

    func execute(_ recipe: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {
        createdRecipes.append(recipe)
        try result.get()
    }
}

private final class FakeUpdateRecipeUseCase: UpdateRecipeUseCase {
    var result: Result<Void, Error> = .success(())
    private(set) var updatedRecipes: [Recipe] = []

    func execute(_ recipe: Recipe, newPhotos _: [UUID: ProcessedPhoto]) throws {
        updatedRecipes.append(recipe)
        try result.get()
    }
}

private final class FakeFetchTagsUseCase: FetchTagsUseCase {
    var result: Result<[Tag], Error> = .success([])
    func execute() throws -> [Tag] { try result.get() }
}

private final class FakeFindOrCreateTagUseCase: FindOrCreateTagUseCase {
    var resultProvider: (String) -> Result<Tag, Error> = { name in .success(Tag(id: UUID(), name: name, isPreset: false)) }
    private(set) var requestedNames: [String] = []

    func execute(name: String) throws -> Tag {
        requestedNames.append(name)
        return try resultProvider(name).get()
    }
}

private struct UseCaseFailure: LocalizedError {
    var errorDescription: String? { "Something went wrong" }
}

@MainActor
final class RecipeFormViewModelTests: XCTestCase {
    // MARK: canSave

    func testCanSaveIsFalseWhenTitleIsBlankOrWhitespace() {
        let viewModel = makeViewModel(mode: .create)

        viewModel.title = "   "

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSaveIsTrueWhenTitleIsNonBlank() {
        let viewModel = makeViewModel(mode: .create)

        viewModel.title = "Pancakes"

        XCTAssertTrue(viewModel.canSave)
    }

    // MARK: edit mode pre-fill

    func testEditModePrefillsFieldsFromOriginalRecipe() {
        let original = Recipe(
            id: UUID(),
            title: "Pancakes",
            ingredients: [IngredientLine(id: UUID(), rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour")],
            equipment: ["griddle", "whisk"],
            steps: ["Mix", "Cook"],
            source: .typed,
            tags: [Tag(id: UUID(), name: "Breakfast", isPreset: true)]
        )

        let viewModel = makeViewModel(mode: .edit(original))

        XCTAssertEqual(viewModel.title, "Pancakes")
        XCTAssertEqual(viewModel.equipment.map(\.name), ["griddle", "whisk"])
        XCTAssertEqual(viewModel.steps.map(\.text), ["Mix", "Cook"])
        XCTAssertEqual(viewModel.ingredients.first?.amount, "2")
        XCTAssertEqual(viewModel.ingredients.first?.unit, "cup")
        XCTAssertEqual(viewModel.ingredients.first?.ingredientName, "flour")
    }

    func testEditModeFormatsFractionalAmountAsAFraction() {
        let original = Recipe(
            id: UUID(),
            title: "Pancakes",
            ingredients: [IngredientLine(id: UUID(), rawText: "1.5 cups flour", amount: 1.5, unit: "cup", ingredientName: "flour")],
            steps: [],
            source: .typed,
            tags: []
        )

        let viewModel = makeViewModel(mode: .edit(original))

        XCTAssertEqual(viewModel.ingredients.first?.amount, "1½")
    }

    func testLoadedRowsKeepTheirSourceLineOnlyWhenItSaysMoreThanTheFields() {
        let original = Recipe(
            id: UUID(),
            title: "Pancakes",
            ingredients: [
                IngredientLine(id: UUID(), rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour"),
                IngredientLine(id: UUID(), rawText: "1 cup plus 2 tablespoons sugar", amount: 1.125, unit: "cup", ingredientName: "sugar"),
            ],
            steps: [],
            source: .typed,
            tags: []
        )

        let viewModel = makeViewModel(mode: .edit(original))
        viewModel.addIngredient()

        XCTAssertEqual(viewModel.ingredients.map(\.sourceLine), [nil, "1 cup plus 2 tablespoons sugar", nil])
    }

    func testSaveInEditModePreservesRawOnlyIngredientLineUntouchedByStructuredFields() throws {
        let original = Recipe(
            id: UUID(),
            title: "Pancakes",
            ingredients: [IngredientLine(id: UUID(), rawText: "1 egg")],
            steps: [],
            source: .typed,
            tags: []
        )
        let updateUseCase = FakeUpdateRecipeUseCase()
        let viewModel = makeViewModel(mode: .edit(original), updateUseCase: updateUseCase)

        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertEqual(recipe.ingredients.count, 1)
        XCTAssertEqual(recipe.ingredients[0].rawText, "1 egg")
        XCTAssertNil(recipe.ingredients[0].amount)
    }

    // MARK: ingredient mutation

    func testAddRemoveMoveIngredient() {
        let viewModel = makeViewModel(mode: .create)

        viewModel.addIngredient()
        viewModel.addIngredient()
        XCTAssertEqual(viewModel.ingredients.count, 2)

        let firstID = viewModel.ingredients[0].id
        let secondID = viewModel.ingredients[1].id

        viewModel.moveIngredientDown(at: 0)
        XCTAssertEqual(viewModel.ingredients.map(\.id), [secondID, firstID])

        viewModel.moveIngredientUp(at: 1)
        XCTAssertEqual(viewModel.ingredients.map(\.id), [firstID, secondID])

        viewModel.removeIngredient(at: 0)
        XCTAssertEqual(viewModel.ingredients.map(\.id), [secondID])
    }

    func testMoveIngredientIsNoOpAtBoundaries() {
        let viewModel = makeViewModel(mode: .create)
        viewModel.addIngredient()
        let onlyID = viewModel.ingredients[0].id

        viewModel.moveIngredientUp(at: 0)
        viewModel.moveIngredientDown(at: 0)

        XCTAssertEqual(viewModel.ingredients.map(\.id), [onlyID])
    }

    // MARK: step mutation

    func testAddRemoveMoveStep() {
        let viewModel = makeViewModel(mode: .create)

        viewModel.addStep()
        viewModel.steps[0].text = "Mix"
        viewModel.addStep()
        viewModel.steps[1].text = "Cook"

        viewModel.moveStepDown(at: 0)
        XCTAssertEqual(viewModel.steps.map(\.text), ["Cook", "Mix"])

        viewModel.moveStepUp(at: 1)
        XCTAssertEqual(viewModel.steps.map(\.text), ["Mix", "Cook"])

        viewModel.removeStep(at: 0)
        XCTAssertEqual(viewModel.steps.map(\.text), ["Cook"])
    }

    func testStepIdentityStaysStableAcrossMoves() {
        let viewModel = makeViewModel(mode: .create)

        viewModel.addStep()
        viewModel.addStep()
        let firstID = viewModel.steps[0].id
        let secondID = viewModel.steps[1].id

        viewModel.moveStepDown(at: 0)

        XCTAssertEqual(viewModel.steps.map(\.id), [secondID, firstID])
    }

    // MARK: save — create

    func testSaveInCreateModeBuildsRecipeWithComposedRawTextAndCallsCreateUseCase() throws {
        let createUseCase = FakeCreateRecipeUseCase()
        let viewModel = makeViewModel(mode: .create, createUseCase: createUseCase)
        viewModel.title = "  Pancakes  "
        viewModel.addIngredient()
        viewModel.ingredients[0].amount = "2"
        viewModel.ingredients[0].unit = "cups"
        viewModel.ingredients[0].ingredientName = "flour"
        viewModel.addStep()
        viewModel.steps[0].text = "  Mix well  "

        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertEqual(recipe.title, "Pancakes")
        XCTAssertEqual(recipe.steps, ["Mix well"])
        XCTAssertEqual(recipe.source, .typed)
        XCTAssertEqual(recipe.tags, [])
        XCTAssertEqual(recipe.ingredients.count, 1)
        XCTAssertEqual(recipe.ingredients[0].rawText, "2 cups flour")
        XCTAssertEqual(recipe.ingredients[0].amount, 2)
        XCTAssertEqual(createUseCase.createdRecipes, [recipe])
    }

    func testSaveSkipsFullyBlankIngredientRowsAndStepsAndParsesUnparseableAmountAsNil() throws {
        let createUseCase = FakeCreateRecipeUseCase()
        let viewModel = makeViewModel(mode: .create, createUseCase: createUseCase)
        viewModel.title = "Soup"
        viewModel.addIngredient() // fully blank, should be dropped
        viewModel.addIngredient()
        viewModel.ingredients[1].ingredientName = "salt" // only name filled
        viewModel.addStep() // blank, should be dropped
        viewModel.addStep()
        viewModel.steps[1].text = "Simmer"

        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertEqual(recipe.ingredients.count, 1)
        XCTAssertEqual(recipe.ingredients[0].rawText, "salt")
        XCTAssertNil(recipe.ingredients[0].amount)
        XCTAssertEqual(recipe.steps, ["Simmer"])
    }

    func testSaveReturnsNilAndDoesNotCallUseCaseWhenTitleIsBlank() {
        let createUseCase = FakeCreateRecipeUseCase()
        let viewModel = makeViewModel(mode: .create, createUseCase: createUseCase)
        viewModel.title = "   "

        let saved = viewModel.save()

        XCTAssertNil(saved)
        XCTAssertTrue(createUseCase.createdRecipes.isEmpty)
    }

    func testSaveSetsErrorMessageAndReturnsNilOnCreateFailure() {
        let createUseCase = FakeCreateRecipeUseCase()
        createUseCase.result = .failure(UseCaseFailure())
        let viewModel = makeViewModel(mode: .create, createUseCase: createUseCase)
        viewModel.title = "Pancakes"

        let saved = viewModel.save()

        XCTAssertNil(saved)
        XCTAssertEqual(viewModel.errorMessage, "Something went wrong")
    }

    // MARK: save — edit

    func testSaveInEditModePreservesOriginalIdentitySourceAndTagsAndCallsUpdateUseCase() throws {
        let originalID = UUID()
        let tag = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let original = Recipe(id: originalID, title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [tag])
        let updateUseCase = FakeUpdateRecipeUseCase()
        let viewModel = makeViewModel(mode: .edit(original), updateUseCase: updateUseCase)
        viewModel.title = "Fluffy Pancakes"

        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertEqual(recipe.id, originalID)
        XCTAssertEqual(recipe.title, "Fluffy Pancakes")
        XCTAssertEqual(recipe.source, .typed)
        XCTAssertEqual(recipe.tags, [tag])
        XCTAssertEqual(updateUseCase.updatedRecipes, [recipe])
    }

    func testSaveSetsErrorMessageAndReturnsNilOnUpdateFailure() {
        let original = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [])
        let updateUseCase = FakeUpdateRecipeUseCase()
        updateUseCase.result = .failure(UseCaseFailure())
        let viewModel = makeViewModel(mode: .edit(original), updateUseCase: updateUseCase)

        let saved = viewModel.save()

        XCTAssertNil(saved)
        XCTAssertEqual(viewModel.errorMessage, "Something went wrong")
    }

    // MARK: save — capture

    func testCaptureModePrefillsLikeEditMode() {
        let captured = Recipe(
            id: UUID(),
            title: "Pancakes",
            ingredients: [IngredientLine(id: UUID(), rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour")],
            steps: ["Mix", "Cook"],
            source: .typed,
            tags: []
        )

        let viewModel = makeViewModel(mode: .capture(captured))

        XCTAssertEqual(viewModel.title, "Pancakes")
        XCTAssertEqual(viewModel.steps.map(\.text), ["Mix", "Cook"])
        XCTAssertEqual(viewModel.ingredients.first?.ingredientName, "flour")
    }

    func testSaveInCaptureModeCreatesANewRecordWithAFreshIDRatherThanUpdating() throws {
        let capturedID = UUID()
        let captured = Recipe(id: capturedID, title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [])
        let createUseCase = FakeCreateRecipeUseCase()
        let updateUseCase = FakeUpdateRecipeUseCase()
        let viewModel = makeViewModel(mode: .capture(captured), createUseCase: createUseCase, updateUseCase: updateUseCase)

        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertNotEqual(recipe.id, capturedID)
        XCTAssertEqual(recipe.title, "Pancakes")
        XCTAssertEqual(recipe.source, .typed)
        XCTAssertEqual(createUseCase.createdRecipes, [recipe])
        XCTAssertTrue(updateUseCase.updatedRecipes.isEmpty)
    }

    func testSaveSetsErrorMessageAndReturnsNilOnCaptureModeCreateFailure() {
        let captured = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [])
        let createUseCase = FakeCreateRecipeUseCase()
        createUseCase.result = .failure(UseCaseFailure())
        let viewModel = makeViewModel(mode: .capture(captured), createUseCase: createUseCase)

        let saved = viewModel.save()

        XCTAssertNil(saved)
        XCTAssertEqual(viewModel.errorMessage, "Something went wrong")
    }

    // MARK: tags

    func testToggleTagAddsAndRemovesFromSelection() {
        let viewModel = makeViewModel(mode: .create)
        let tag = Tag(id: UUID(), name: "Breakfast", isPreset: true)

        viewModel.toggleTag(tag)
        XCTAssertTrue(viewModel.selectedTagIDs.contains(tag.id))

        viewModel.toggleTag(tag)
        XCTAssertFalse(viewModel.selectedTagIDs.contains(tag.id))
    }

    func testLoadTagsPopulatesAllTagsSortedPresetsFirst() {
        let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let spicy = Tag(id: UUID(), name: "Spicy", isPreset: false)
        let fetchTagsUseCase = FakeFetchTagsUseCase()
        fetchTagsUseCase.result = .success([spicy, breakfast])
        let viewModel = makeViewModel(mode: .create, fetchTagsUseCase: fetchTagsUseCase)

        viewModel.loadTags()

        XCTAssertEqual(viewModel.allTags, [breakfast, spicy])
    }

    func testEditModePreselectsExistingRecipeTagsAndMergesMissingOnesIntoAllTags() {
        let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let original = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [breakfast])
        let fetchTagsUseCase = FakeFetchTagsUseCase()
        fetchTagsUseCase.result = .success([]) // simulates a fetch that hasn't caught up yet
        let viewModel = makeViewModel(mode: .edit(original), fetchTagsUseCase: fetchTagsUseCase)

        XCTAssertTrue(viewModel.selectedTagIDs.contains(breakfast.id))

        viewModel.loadTags()

        XCTAssertEqual(viewModel.allTags, [breakfast])
        XCTAssertTrue(viewModel.selectedTagIDs.contains(breakfast.id))
    }

    func testConfirmNewTagCreatesAddsAndSelectsTag() {
        let viewModel = makeViewModel(mode: .create)
        viewModel.newTagName = "  Spicy  "
        viewModel.isAddingNewTag = true

        viewModel.confirmNewTag()

        XCTAssertEqual(viewModel.allTags.map(\.name), ["Spicy"])
        XCTAssertTrue(viewModel.selectedTagIDs.contains(viewModel.allTags[0].id))
        XCTAssertEqual(viewModel.newTagName, "")
        XCTAssertFalse(viewModel.isAddingNewTag)
    }

    func testConfirmNewTagDoesNothingWhenNameIsBlank() {
        let viewModel = makeViewModel(mode: .create)
        viewModel.newTagName = "   "
        viewModel.isAddingNewTag = true

        viewModel.confirmNewTag()

        XCTAssertTrue(viewModel.allTags.isEmpty)
        XCTAssertFalse(viewModel.isAddingNewTag)
    }

    func testConfirmNewTagReusesExistingTagWithoutDuplicatingInAllTags() {
        let existing = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let fetchTagsUseCase = FakeFetchTagsUseCase()
        fetchTagsUseCase.result = .success([existing])
        let findOrCreateTagUseCase = FakeFindOrCreateTagUseCase()
        findOrCreateTagUseCase.resultProvider = { _ in .success(existing) }
        let viewModel = makeViewModel(mode: .create, fetchTagsUseCase: fetchTagsUseCase, findOrCreateTagUseCase: findOrCreateTagUseCase)
        viewModel.loadTags()

        viewModel.newTagName = "breakfast"
        viewModel.confirmNewTag()

        XCTAssertEqual(viewModel.allTags, [existing])
        XCTAssertTrue(viewModel.selectedTagIDs.contains(existing.id))
    }

    func testSaveIncludesOnlySelectedTags() throws {
        let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let lunch = Tag(id: UUID(), name: "Lunch", isPreset: true)
        let fetchTagsUseCase = FakeFetchTagsUseCase()
        fetchTagsUseCase.result = .success([breakfast, lunch])
        let createUseCase = FakeCreateRecipeUseCase()
        let viewModel = makeViewModel(mode: .create, createUseCase: createUseCase, fetchTagsUseCase: fetchTagsUseCase)
        viewModel.title = "Pancakes"
        viewModel.loadTags()
        viewModel.toggleTag(breakfast)

        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertEqual(recipe.tags, [breakfast])
    }

    func testEditModeSaveReflectsDeselectingAnOriginalTag() throws {
        let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let original = Recipe(id: UUID(), title: "Pancakes", ingredients: [], steps: [], source: .typed, tags: [breakfast])
        let updateUseCase = FakeUpdateRecipeUseCase()
        let viewModel = makeViewModel(mode: .edit(original), updateUseCase: updateUseCase)
        viewModel.loadTags()

        viewModel.toggleTag(breakfast)
        let saved = viewModel.save()

        let recipe = try XCTUnwrap(saved)
        XCTAssertEqual(recipe.tags, [])
    }

    // MARK: helpers

    private func makeViewModel(
        mode: RecipeFormMode,
        createUseCase: FakeCreateRecipeUseCase = FakeCreateRecipeUseCase(),
        updateUseCase: FakeUpdateRecipeUseCase = FakeUpdateRecipeUseCase(),
        fetchTagsUseCase: FakeFetchTagsUseCase = FakeFetchTagsUseCase(),
        findOrCreateTagUseCase: FakeFindOrCreateTagUseCase = FakeFindOrCreateTagUseCase()
    ) -> RecipeFormViewModel {
        RecipeFormViewModel(mode: mode, dependencies: .testing(
            createRecipeUseCase: createUseCase,
            updateRecipeUseCase: updateUseCase,
            fetchTagsUseCase: fetchTagsUseCase,
            findOrCreateTagUseCase: findOrCreateTagUseCase
        ))
    }
}
