@testable import RecipeRaccoon
import SwiftData
import XCTest

final class SwiftDataRecipeRepositoryTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            RecipeModel.self,
            IngredientLineModel.self,
            TagModel.self,
            DensityEntryModel.self,
        ])
        let container = try ModelContainer.inMemory(schema: schema)
        return ModelContext(container)
    }

    func testFetchAllReturnsEmptyArrayWhenNoRecipesStored() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataRecipeRepository(modelContext: context)

        let recipes = try repository.fetchAll()

        XCTAssertEqual(recipes, [])
    }

    func testFetchAllReturnsRecipesSortedByTitleWithIngredientsAndTags() throws {
        let context = try makeInMemoryContext()
        context.insert(RecipeModel(
            title: "Waffles",
            steps: ["Cook in waffle iron"],
            isTypedSource: true,
            ingredients: [IngredientLineModel(rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour")],
            tags: [TagModel(name: "Breakfast", isPreset: true)]
        ))
        context.insert(RecipeModel(title: "Apple Pie", steps: ["Bake"], isTypedSource: true))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        let recipes = try repository.fetchAll()

        XCTAssertEqual(recipes.map(\.title), ["Apple Pie", "Waffles"])
        let waffles = try XCTUnwrap(recipes.first { $0.title == "Waffles" })
        XCTAssertEqual(waffles.ingredients.first?.ingredientName, "flour")
        XCTAssertEqual(waffles.tags.first?.name, "Breakfast")
        // Rows saved before equipment existed (#82) have none.
        XCTAssertEqual(recipes.first?.equipment, [])
    }

    func testFetchAllMapsURLSourceRecipe() throws {
        let context = try makeInMemoryContext()
        let url = try XCTUnwrap(URL(string: "https://example.com/recipe"))
        context.insert(RecipeModel(title: "Web Recipe", steps: ["Step 1"], isTypedSource: false, sourceURL: url))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        let recipes = try repository.fetchAll()

        XCTAssertEqual(recipes.first?.source, .url(url))
    }

    func testCreateInsertsRecipeRetrievableByFetchAll() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataRecipeRepository(modelContext: context)
        let recipe = Recipe(
            id: UUID(),
            title: "Waffles",
            ingredients: [IngredientLine(id: UUID(), rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour")],
            equipment: ["waffle iron"],
            steps: ["Cook in waffle iron"],
            source: .typed,
            tags: []
        )

        try repository.create(recipe)

        let recipes = try repository.fetchAll()
        XCTAssertEqual(recipes, [recipe])
    }

    func testUpdateReplacesFieldsAndIngredientsWithoutOrphaningOldRows() throws {
        let context = try makeInMemoryContext()
        let recipeID = UUID()
        context.insert(RecipeModel(
            id: recipeID,
            title: "Original Title",
            steps: ["Old step"],
            isTypedSource: true,
            ingredients: [IngredientLineModel(rawText: "1 old ingredient")]
        ))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        let updated = Recipe(
            id: recipeID,
            title: "New Title",
            ingredients: [IngredientLine(id: UUID(), rawText: "2 cups sugar", amount: 2, unit: "cup", ingredientName: "sugar")],
            equipment: ["saucepan"],
            steps: ["New step"],
            source: .typed,
            tags: []
        )

        try repository.update(updated)

        let recipes = try repository.fetchAll()
        XCTAssertEqual(recipes, [updated])

        let remainingIngredients = try context.fetch(FetchDescriptor<IngredientLineModel>())
        XCTAssertEqual(remainingIngredients.map(\.rawText), ["2 cups sugar"])
    }

    /// SwiftData doesn't keep the order of to-many relationships (#86). 20 lines make an
    /// in-order result by chance vanishingly unlikely; reading through a fresh context
    /// makes the order come from the store, not the inserting context's in-memory array.
    func testCreateAndUpdatePreserveIngredientOrderAcrossContexts() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataRecipeRepository(modelContext: context)
        let ingredients = (1...20).map { IngredientLine(id: UUID(), rawText: "ingredient \($0)") }
        let recipe = Recipe(id: UUID(), title: "Long", ingredients: ingredients, steps: [], source: .typed, tags: [])

        try repository.create(recipe)

        let freshRepository = SwiftDataRecipeRepository(modelContext: ModelContext(context.container))
        XCTAssertEqual(try freshRepository.fetchAll().first?.ingredients, ingredients)

        var reordered = recipe
        reordered.ingredients = ingredients.reversed()
        try repository.update(reordered)

        let secondFreshRepository = SwiftDataRecipeRepository(modelContext: ModelContext(context.container))
        XCTAssertEqual(try secondFreshRepository.fetchAll().first?.ingredients, reordered.ingredients)
    }

    func testCreateResolvesTagsToExistingTagModelRowsWithoutDuplicating() throws {
        let context = try makeInMemoryContext()
        let tagID = UUID()
        context.insert(TagModel(id: tagID, name: "Breakfast", isPreset: true))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        let tag = Tag(id: tagID, name: "Breakfast", isPreset: true)
        let recipe = Recipe(id: UUID(), title: "Waffles", ingredients: [], steps: [], source: .typed, tags: [tag])

        try repository.create(recipe)

        let recipes = try repository.fetchAll()
        XCTAssertEqual(recipes.first?.tags, [tag])

        let allTagRows = try context.fetch(FetchDescriptor<TagModel>())
        XCTAssertEqual(allTagRows.count, 1)
    }

    func testUpdateResolvesTagsToExistingTagModelRowsWithoutDuplicating() throws {
        let context = try makeInMemoryContext()
        let recipeID = UUID()
        let tagID = UUID()
        context.insert(RecipeModel(id: recipeID, title: "Waffles", steps: [], isTypedSource: true))
        context.insert(TagModel(id: tagID, name: "Breakfast", isPreset: true))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        let tag = Tag(id: tagID, name: "Breakfast", isPreset: true)
        let updated = Recipe(id: recipeID, title: "Waffles", ingredients: [], steps: [], source: .typed, tags: [tag])

        try repository.update(updated)

        let recipes = try repository.fetchAll()
        XCTAssertEqual(recipes.first?.tags, [tag])

        let allTagRows = try context.fetch(FetchDescriptor<TagModel>())
        XCTAssertEqual(allTagRows.count, 1)
    }

    func testUpdateThrowsRecipeNotFoundForUnknownID() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataRecipeRepository(modelContext: context)
        let recipe = Recipe(id: UUID(), title: "Ghost", ingredients: [], steps: [], source: .typed, tags: [])

        XCTAssertThrowsError(try repository.update(recipe)) { error in
            XCTAssertEqual(error as? RecipeRepositoryError, .recipeNotFound)
        }
    }

    func testDeleteRemovesRecipe() throws {
        let context = try makeInMemoryContext()
        let recipeID = UUID()
        context.insert(RecipeModel(id: recipeID, title: "Waffles", steps: ["Cook"], isTypedSource: true))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        try repository.delete(id: recipeID)

        let recipes = try repository.fetchAll()
        XCTAssertEqual(recipes, [])
    }

    func testDeleteThrowsRecipeNotFoundForUnknownID() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataRecipeRepository(modelContext: context)

        XCTAssertThrowsError(try repository.delete(id: UUID())) { error in
            XCTAssertEqual(error as? RecipeRepositoryError, .recipeNotFound)
        }
    }

    // MARK: - Unused tags (#211)

    private func tagNames(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<TagModel>()).map(\.name).sorted()
    }

    func testUpdateDeletesACustomTagOnceItsLastRecipeDropsIt() throws {
        let context = try makeInMemoryContext()
        let recipeID = UUID()
        let typo = TagModel(name: "Desert", isPreset: false)
        let preset = TagModel(name: "Dessert", isPreset: true)
        context.insert(RecipeModel(id: recipeID, title: "Pie", steps: [], isTypedSource: true, tags: [typo, preset]))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        try repository.update(Recipe(id: recipeID, title: "Pie", ingredients: [], steps: [], source: .typed, tags: []))

        XCTAssertEqual(try tagNames(in: context), ["Dessert"])
    }

    func testDeleteDeletesTheRecipesUnusedCustomTagsButKeepsSharedOnesAndPresets() throws {
        let context = try makeInMemoryContext()
        let pieID = UUID()
        let shared = TagModel(name: "Baking", isPreset: false)
        let preset = TagModel(name: "Dessert", isPreset: true)
        context.insert(RecipeModel(id: pieID, title: "Pie", steps: [], isTypedSource: true, tags: [TagModel(name: "Grandma", isPreset: false), shared, preset]))
        context.insert(RecipeModel(title: "Bread", steps: [], isTypedSource: true, tags: [shared]))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        try repository.delete(id: pieID)

        XCTAssertEqual(try tagNames(in: context), ["Baking", "Dessert"])
    }

    func testCreateMakesATagAgainWhenItsRowIsGone() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataRecipeRepository(modelContext: context)
        // Offered by a form, then deleted by the cleanup after another save.
        let gone = Tag(id: UUID(), name: "Brunch", isPreset: false)

        try repository.create(Recipe(id: UUID(), title: "Waffles", ingredients: [], steps: [], source: .typed, tags: [gone]))

        XCTAssertEqual(try repository.fetchAll().first?.tags.map(\.name), ["Brunch"])
        XCTAssertEqual(try tagNames(in: context), ["Brunch"])
    }

    func testCreateUsesATagWithTheSameNameWhenTheOfferedRowIsGone() throws {
        let context = try makeInMemoryContext()
        let existingID = UUID()
        context.insert(RecipeModel(title: "Pancakes", steps: [], isTypedSource: true, tags: [TagModel(id: existingID, name: "Brunch", isPreset: false)]))
        try context.save()

        let repository = SwiftDataRecipeRepository(modelContext: context)
        try repository.create(Recipe(id: UUID(), title: "Waffles", ingredients: [], steps: [], source: .typed, tags: [Tag(id: UUID(), name: "brunch", isPreset: false)]))

        let waffles = try XCTUnwrap(repository.fetchAll().first { $0.title == "Waffles" })
        XCTAssertEqual(waffles.tags.map(\.id), [existingID])
        XCTAssertEqual(try tagNames(in: context), ["Brunch"])
    }
}
