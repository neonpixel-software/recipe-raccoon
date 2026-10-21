@testable import RecipeRaccoon
import SwiftData
import XCTest

final class RecipeStoreCopierTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer.inMemory()
        return ModelContext(container)
    }

    private func recipes(in context: ModelContext) throws -> [Recipe] {
        try SwiftDataRecipeRepository(modelContext: context).fetchAll()
    }

    private func tagNames(in context: ModelContext) throws -> [String] {
        try SwiftDataTagRepository(modelContext: context).fetchAll().map(\.name)
    }

    func testMergeCopiesRecipesWithIngredientsInOrderAndKeepsIDs() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let recipe = try Recipe(
            id: UUID(),
            title: "Pancakes",
            servings: 4,
            ingredients: [
                IngredientLine(id: UUID(), rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour"),
                IngredientLine(id: UUID(), rawText: "1 egg", amount: 1, unit: nil, ingredientName: "egg"),
            ],
            equipment: ["skillet"],
            steps: ["Mix", "Fry"],
            source: .url(XCTUnwrap(URL(string: "https://example.com/pancakes"))),
            tags: []
        )
        try SwiftDataRecipeRepository(modelContext: source).create(recipe)

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: target), [recipe])
    }

    func testMergeMatchesTagsByNameIgnoringCaseAndCopiesUnusedCustomTags() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        target.insert(TagModel(name: "Breakfast", isPreset: true))
        try target.save()
        let sourceBreakfast = TagModel(name: "breakfast", isPreset: true)
        source.insert(sourceBreakfast)
        source.insert(TagModel(name: "Brunch", isPreset: false))
        source.insert(RecipeModel(title: "Waffles", steps: [], isTypedSource: true, tags: [sourceBreakfast]))
        try source.save()

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try tagNames(in: target), ["Breakfast", "Brunch"])
        XCTAssertEqual(try recipes(in: target).first?.tags.map(\.name), ["Breakfast"])
    }

    func testMergeOverwritesARecipeWithTheSameIDInsteadOfDuplicatingIt() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let id = UUID()
        target.insert(RecipeModel(
            id: id,
            title: "Old title",
            steps: ["Old step"],
            isTypedSource: true,
            ingredients: [IngredientLineModel(rawText: "old line")]
        ))
        try target.save()
        source.insert(RecipeModel(
            id: id,
            title: "New title",
            steps: ["New step"],
            isTypedSource: true,
            ingredients: [IngredientLineModel(rawText: "new line")]
        ))
        try source.save()

        try RecipeStoreCopier.merge(from: source, into: target)

        let merged = try recipes(in: target)
        XCTAssertEqual(merged.map(\.title), ["New title"])
        XCTAssertEqual(merged.first?.ingredients.map(\.rawText), ["new line"])
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<IngredientLineModel>()), 1)
    }

    func testMergeKeepsRecipesThatOnlyExistInTheTarget() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        target.insert(RecipeModel(title: "From another device", steps: [], isTypedSource: true))
        try target.save()
        source.insert(RecipeModel(title: "Local recipe", steps: [], isTypedSource: true))
        try source.save()

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: target).map(\.title), ["From another device", "Local recipe"])
    }

    func testReplaceEmptiesTheTargetBeforeCopying() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        target.insert(RecipeModel(
            title: "Deleted while syncing",
            steps: [],
            isTypedSource: true,
            ingredients: [IngredientLineModel(rawText: "stale line")],
            tags: [TagModel(name: "Stale tag", isPreset: false)]
        ))
        try target.save()
        source.insert(RecipeModel(title: "Synced recipe", steps: [], isTypedSource: true))
        source.insert(TagModel(name: "Dinner", isPreset: true))
        try source.save()

        try RecipeStoreCopier.replace(contentsOf: target, with: source)

        XCTAssertEqual(try recipes(in: target).map(\.title), ["Synced recipe"])
        XCTAssertEqual(try tagNames(in: target), ["Dinner"])
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<IngredientLineModel>()), 0)
    }

    func testMergeLeavesTheSourceUntouched() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        source.insert(RecipeModel(title: "Pancakes", steps: [], isTypedSource: true))
        try source.save()

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: source).map(\.title), ["Pancakes"])
    }

    private func photoRows(in context: ModelContext) throws -> [RecipePhotoModel] {
        try context.fetch(FetchDescriptor<RecipePhotoModel>())
    }

    private func recipeWithPhotos(_ ids: [UUID], in context: ModelContext) throws -> Recipe {
        var recipe = Recipe(id: UUID(), title: "Banana Bread", ingredients: [], steps: [], source: .typed, tags: [])
        recipe.photos = ids.map(RecipePhoto.init)
        let bytes = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
            (id, ProcessedPhoto(imageData: Data([UInt8(index), 1]), thumbnailData: Data([UInt8(index), 2])))
        })
        try SwiftDataRecipeRepository(modelContext: context).create(recipe, newPhotos: bytes)
        return recipe
    }

    func testMergeCopiesPhotosWithTheirBytesInGalleryOrder() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let cover = UUID(), second = UUID()
        let recipe = try recipeWithPhotos([cover, second], in: source)

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: target), [recipe])
        let photos = SwiftDataRecipePhotoRepository(modelContext: target)
        XCTAssertEqual(try photos.image(id: cover), Data([0, 1]))
        XCTAssertEqual(try photos.thumbnail(id: second), Data([1, 2]))
    }

    func testMergeKeepsPhotoRowsTheTargetAlreadyHasAndDropsRemovedOnes() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let kept = UUID(), removed = UUID(), added = UUID()
        var recipe = try recipeWithPhotos([kept, removed], in: source)
        try RecipeStoreCopier.merge(from: source, into: target)
        let keptRow = try XCTUnwrap(photoRows(in: target).first { $0.id == kept })

        recipe.photos = [added, kept].map(RecipePhoto.init)
        try SwiftDataRecipeRepository(modelContext: source).update(
            recipe,
            newPhotos: [added: ProcessedPhoto(imageData: Data([9]), thumbnailData: Data([9]))]
        )
        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: target).first?.photos, recipe.photos)
        let rows = try photoRows(in: target)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.contains { $0 === keptRow })
        XCTAssertEqual(try SwiftDataRecipePhotoRepository(modelContext: target).image(id: added), Data([9]))
    }

    func testReplaceCopiesPhotosAndDeletesTheTargetsOldOnes() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        _ = try recipeWithPhotos([UUID()], in: target)
        let photo = UUID()
        _ = try recipeWithPhotos([photo], in: source)

        try RecipeStoreCopier.replace(contentsOf: target, with: source)

        XCTAssertEqual(try photoRows(in: target).map(\.id), [photo])
    }

    func testMergeLeavesOutAPhotoWhoseBytesAreNotOnThisDevice() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let downloaded = UUID()
        source.insert(RecipeModel(title: "Banana Bread", steps: [], isTypedSource: true, photos: [
            RecipePhotoModel(id: UUID(), position: 0, imageData: nil, thumbnailData: nil),
            RecipePhotoModel(id: downloaded, position: 1, imageData: Data([1]), thumbnailData: Data([2])),
        ]))
        try source.save()

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: target).first?.photos, [RecipePhoto(id: downloaded)])
    }

    func testAPhotoLeftOutIsCopiedByALaterMergeOnceItsBytesAreHere() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let photo = UUID()
        let row = RecipePhotoModel(id: photo, imageData: nil, thumbnailData: nil)
        source.insert(RecipeModel(title: "Banana Bread", steps: [], isTypedSource: true, photos: [row]))
        try source.save()
        try RecipeStoreCopier.merge(from: source, into: target)
        XCTAssertEqual(try recipes(in: target).first?.photos, [])

        row.imageData = Data([1])
        row.thumbnailData = Data([2])
        try source.save()
        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try recipes(in: target).first?.photos, [RecipePhoto(id: photo)])
        XCTAssertEqual(try SwiftDataRecipePhotoRepository(modelContext: target).image(id: photo), Data([1]))
    }

    func testMergeFillsInATargetRowThatLacksItsBytes() throws {
        let source = try makeInMemoryContext()
        let target = try makeInMemoryContext()
        let photo = UUID()
        let recipeID = UUID()
        target.insert(RecipeModel(id: recipeID, title: "Banana Bread", steps: [], isTypedSource: true, photos: [
            RecipePhotoModel(id: photo, imageData: nil, thumbnailData: nil),
        ]))
        try target.save()
        source.insert(RecipeModel(id: recipeID, title: "Banana Bread", steps: [], isTypedSource: true, photos: [
            RecipePhotoModel(id: photo, imageData: Data([1]), thumbnailData: Data([2])),
        ]))
        try source.save()

        try RecipeStoreCopier.merge(from: source, into: target)

        XCTAssertEqual(try photoRows(in: target).count, 1)
        let photos = SwiftDataRecipePhotoRepository(modelContext: target)
        XCTAssertEqual(try photos.image(id: photo), Data([1]))
        XCTAssertEqual(try photos.thumbnail(id: photo), Data([2]))
    }
}
