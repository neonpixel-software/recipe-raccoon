import Foundation

protocol TagSuggestionService: Sendable {
    /// The names from `tagNames` that fit the recipe, best first; empty if none does.
    func suggestTags(title: String, ingredients: [String], from tagNames: [String]) async throws -> [String]
}
