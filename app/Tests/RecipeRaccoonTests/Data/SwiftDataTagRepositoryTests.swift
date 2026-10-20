@testable import RecipeRaccoon
import SwiftData
import XCTest

final class SwiftDataTagRepositoryTests: XCTestCase {
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

    func testFetchAllReturnsEmptyArrayWhenNoTagsStored() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataTagRepository(modelContext: context)

        XCTAssertEqual(try repository.fetchAll(), [])
    }

    func testFetchAllReturnsTagsSortedByName() throws {
        let context = try makeInMemoryContext()
        context.insert(TagModel(name: "Snack", isPreset: true))
        context.insert(TagModel(name: "Breakfast", isPreset: true))
        try context.save()

        let repository = SwiftDataTagRepository(modelContext: context)
        let tags = try repository.fetchAll()

        XCTAssertEqual(tags.map(\.name), ["Breakfast", "Snack"])
    }

    func testFindOrCreateReturnsExistingTagCaseInsensitively() throws {
        let context = try makeInMemoryContext()
        let existingID = UUID()
        context.insert(TagModel(id: existingID, name: "Breakfast", isPreset: true))
        try context.save()

        let repository = SwiftDataTagRepository(modelContext: context)
        let tag = try repository.findOrCreate(name: "breakfast")

        XCTAssertEqual(tag.id, existingID)
        XCTAssertEqual(tag.name, "Breakfast")

        let allTagRows = try context.fetch(FetchDescriptor<TagModel>())
        XCTAssertEqual(allTagRows.count, 1)
    }

    func testFindOrCreateCreatesNewTagWhenNoMatch() throws {
        let context = try makeInMemoryContext()
        let repository = SwiftDataTagRepository(modelContext: context)

        let tag = try repository.findOrCreate(name: "  Spicy  ")

        XCTAssertEqual(tag.name, "Spicy")
        XCTAssertFalse(tag.isPreset)

        let allTags = try repository.fetchAll()
        XCTAssertEqual(allTags, [tag])
    }

    func testDeleteRemovesACustomTagFromItsRecipesAndKeepsThem() throws {
        let context = try makeInMemoryContext()
        let tagID = UUID()
        let preset = TagModel(name: "Dinner", isPreset: true)
        context.insert(RecipeModel(title: "Stew", steps: [], isTypedSource: true, tags: [TagModel(id: tagID, name: "Desert", isPreset: false), preset]))
        try context.save()

        let repository = SwiftDataTagRepository(modelContext: context)
        try repository.delete(id: tagID)

        XCTAssertEqual(try repository.fetchAll().map(\.name), ["Dinner"])
        let recipe = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeModel>()).first)
        XCTAssertEqual(recipe.tags?.map(\.name), ["Dinner"])
    }

    func testDeleteLeavesAPresetAlone() throws {
        let context = try makeInMemoryContext()
        let presetID = UUID()
        context.insert(TagModel(id: presetID, name: "Dinner", isPreset: true))
        try context.save()

        let repository = SwiftDataTagRepository(modelContext: context)
        try repository.delete(id: presetID)
        try repository.delete(id: UUID())

        XCTAssertEqual(try repository.fetchAll().map(\.name), ["Dinner"])
    }
}
