import Foundation

struct Recipe: Identifiable, Equatable {
    let id: UUID
    var title: String
    /// How many servings (or items, for a yield like "12 muffins") the recipe makes, nil when
    /// unknown. Always within `servingsRange`.
    var servings: Int?
    var ingredients: [IngredientLine]
    /// Tools and cookware the recipe needs ("loaf pan", "whisk"), kept out of `ingredients`.
    var equipment: [String] = []
    var steps: [String]
    var source: RecipeSource
    var tags: [Tag]
    /// The gallery, cover first. Bytes load through RecipePhotoRepository.
    var photos: [RecipePhoto] = []

    static let servingsRange = 1...99
}

enum RecipeSource: Equatable {
    case typed
    case url(URL)
}
