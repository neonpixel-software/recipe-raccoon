@testable import RecipeRaccoon
import SwiftData
import XCTest

final class ModelContextDeleteUnusedTagsTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer.inMemory()
        return ModelContext(container)
    }

    private func tagNames(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<TagModel>()).map(\.name).sorted()
    }

    func testDeletesCustomTagsNoRecipeUses() throws {
        let context = try makeInMemoryContext()
        context.insert(TagModel(name: "Desert", isPreset: false))
        context.insert(RecipeModel(title: "Pie", steps: [], isTypedSource: true, tags: [TagModel(name: "Baking", isPreset: false)]))
        try context.save()

        let changed = try context.deleteUnusedTags()

        XCTAssertTrue(changed)
        XCTAssertEqual(try tagNames(in: context), ["Baking"])
    }

    func testKeepsPresetTagsEvenWhenUnused() throws {
        let context = try makeInMemoryContext()
        context.insert(TagModel(name: "Dinner", isPreset: true))
        try context.save()

        let changed = try context.deleteUnusedTags()

        XCTAssertFalse(changed)
        XCTAssertEqual(try tagNames(in: context), ["Dinner"])
    }

    func testChangesNothingWhenEveryCustomTagIsUsed() throws {
        let context = try makeInMemoryContext()
        context.insert(RecipeModel(title: "Pie", steps: [], isTypedSource: true, tags: [TagModel(name: "Baking", isPreset: false)]))
        try context.save()

        XCTAssertFalse(try context.deleteUnusedTags())
        XCTAssertEqual(try tagNames(in: context), ["Baking"])
    }
}
