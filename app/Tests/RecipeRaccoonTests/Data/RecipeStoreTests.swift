@testable import RecipeRaccoon
import SwiftData
import XCTest

final class RecipeStoreTests: XCTestCase {
    func testLocalStoreKeepsSwiftDatasDefaultFileAndDoesNotSync() {
        let configuration = RecipeStore.configuration(for: .local)

        XCTAssertEqual(configuration.url.lastPathComponent, "default.store")
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
    }

    func testICloudStoreUsesItsOwnFileAndThePrivateCloudKitContainer() {
        let configuration = RecipeStore.configuration(for: .iCloud)

        XCTAssertEqual(configuration.url.lastPathComponent, "iCloud.store")
        XCTAssertEqual(configuration.cloudKitContainerIdentifier, "iCloud.com.neonpixel.reciperaccoon")
    }

    func testDensityEntriesAreNotPartOfTheSyncedSchema() {
        let entityNames = RecipeStore.schema.entities.map(\.name)

        XCTAssertFalse(entityNames.contains("DensityEntryModel"))
        XCTAssertEqual(Set(entityNames), ["RecipeModel", "IngredientLineModel", "TagModel", "RecipePhotoModel"])
    }

    /// Stores created before Phase 4.1 also hold DensityEntryModel. Opening one with the
    /// recipe-only schema must migrate it and keep the recipes, since the Local store stays
    /// at SwiftData's default location on existing devices.
    func testAStoreCreatedWithTheDensityModelOpensWithTheRecipeSchemaAndKeepsItsRecipes() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")

        do {
            let oldSchema = Schema([RecipeModel.self, IngredientLineModel.self, TagModel.self, DensityEntryModel.self])
            let oldContainer = try ModelContainer(
                for: oldSchema,
                configurations: ModelConfiguration(schema: oldSchema, url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(oldContainer)
            context.insert(RecipeModel(title: "Pancakes", steps: ["Fry"], isTypedSource: true))
            context.insert(DensityEntryModel(ingredientName: "flour", gramsPerMilliliter: 0.53, lastModified: .now))
            try context.save()
        }

        let container = try ModelContainer(
            for: RecipeStore.schema,
            configurations: ModelConfiguration(schema: RecipeStore.schema, url: url, cloudKitDatabase: .none)
        )

        let recipes = try SwiftDataRecipeRepository(modelContext: ModelContext(container)).fetchAll()
        XCTAssertEqual(recipes.map(\.title), ["Pancakes"])
    }

    /// Stores saved before photos existed (Phase 13, e.g. by the v0.1.0 TestFlight build) open
    /// with the photo schema, keep their recipes, and can take photos afterwards. They predate
    /// servings too (Phase 15), so their recipes have none.
    func testAStoreCreatedBeforePhotosOpensWithThePhotoSchemaAndKeepsItsRecipes() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")

        do {
            let oldSchema = Schema(versionedSchema: PrePhotosSchema.self)
            let oldContainer = try ModelContainer(
                for: oldSchema,
                configurations: ModelConfiguration(schema: oldSchema, url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(oldContainer)
            context.insert(PrePhotosSchema.RecipeModel(title: "Pancakes"))
            try context.save()
        }

        let container = try ModelContainer(
            for: RecipeStore.schema,
            configurations: ModelConfiguration(schema: RecipeStore.schema, url: url, cloudKitDatabase: .none)
        )
        // One context for every call: the repository evaluates its context argument on each use.
        let context = ModelContext(container)
        let repository = SwiftDataRecipeRepository(modelContext: context)
        var recipe = try XCTUnwrap(repository.fetchAll().first)
        XCTAssertEqual(recipe.title, "Pancakes")
        XCTAssertEqual(recipe.photos, [])
        XCTAssertNil(recipe.servings)

        let photo = UUID()
        recipe.photos = [RecipePhoto(id: photo)]
        try repository.update(recipe, newPhotos: [photo: ProcessedPhoto(imageData: Data([1]), thumbnailData: Data([2]))])
        XCTAssertEqual(try repository.fetchAll().first?.photos, [RecipePhoto(id: photo)])
    }
}

/// The recipe models as they were before Phase 13 added RecipePhotoModel (main at 97b33e1).
private enum PrePhotosSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [RecipeModel.self, IngredientLineModel.self, TagModel.self]
    }

    @Model
    final class RecipeModel {
        var id: UUID = UUID()
        var title: String = ""
        var steps: [String] = []
        var equipment: [String] = []
        var isTypedSource: Bool = false
        var sourceURL: URL?
        @Relationship(deleteRule: .cascade) var ingredients: [IngredientLineModel]? = []
        @Relationship var tags: [TagModel]? = []

        init(title: String) {
            self.title = title
            isTypedSource = true
        }
    }

    @Model
    final class IngredientLineModel {
        var id: UUID = UUID()
        var rawText: String = ""
        var amount: Double?
        var unit: String?
        var ingredientName: String?
        var position: Int = 0
        @Relationship(inverse: \RecipeModel.ingredients) var recipe: RecipeModel?

        init() {}
    }

    @Model
    final class TagModel {
        var id: UUID = UUID()
        var name: String = ""
        var isPreset: Bool = false
        @Relationship(inverse: \RecipeModel.tags) var recipes: [RecipeModel]?

        init() {}
    }
}
