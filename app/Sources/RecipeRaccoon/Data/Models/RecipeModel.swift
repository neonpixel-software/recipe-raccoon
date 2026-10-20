import Foundation
import SwiftData

@Model
final class RecipeModel {
    var id: UUID = UUID()
    var title: String = ""
    /// Optional, so rows saved before servings existed (Phase 15) read as nil.
    var servings: Int?
    var steps: [String] = []
    var equipment: [String] = []
    var isTypedSource: Bool = false
    var sourceURL: URL?
    @Relationship(deleteRule: .cascade) var ingredients: [IngredientLineModel]? = []
    @Relationship var tags: [TagModel]? = []
    @Relationship(deleteRule: .cascade) var photos: [RecipePhotoModel]? = []

    init(
        id: UUID = UUID(),
        title: String,
        servings: Int? = nil,
        steps: [String],
        equipment: [String] = [],
        isTypedSource: Bool,
        sourceURL: URL? = nil,
        ingredients: [IngredientLineModel] = [],
        tags: [TagModel] = [],
        photos: [RecipePhotoModel] = []
    ) {
        self.id = id
        self.title = title
        self.servings = servings
        self.steps = steps
        self.equipment = equipment
        self.isTypedSource = isTypedSource
        self.sourceURL = sourceURL
        self.ingredients = ingredients
        self.tags = tags
        self.photos = photos
    }
}
