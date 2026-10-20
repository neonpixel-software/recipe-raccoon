import Foundation

@MainActor
protocol SuggestTagsUseCase {
    /// The user's tags that fit a captured recipe, for the review screen to start with
    /// selected. Empty when nothing fits or the suggestion fails: tags are a convenience, so
    /// a failure never stops the capture.
    func execute(for recipe: Recipe) async -> [Tag]
}

@MainActor
final class DefaultSuggestTagsUseCase: SuggestTagsUseCase {
    private let fetchTagsUseCase: FetchTagsUseCase
    private let suggestionService: TagSuggestionService

    init(fetchTagsUseCase: FetchTagsUseCase, suggestionService: TagSuggestionService) {
        self.fetchTagsUseCase = fetchTagsUseCase
        self.suggestionService = suggestionService
    }

    func execute(for recipe: Recipe) async -> [Tag] {
        do {
            let tags = try fetchTagsUseCase.execute()
            guard !tags.isEmpty else { return [] }
            let names = try await suggestionService.suggestTags(
                title: recipe.title,
                ingredients: recipe.ingredients.map(\.rawText),
                from: tags.map(\.name)
            )
            var suggested: [Tag] = []
            for name in names {
                if let tag = tags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
                   !suggested.contains(tag) {
                    suggested.append(tag)
                }
            }
            return suggested
        } catch {
            Log.domain.failure("Couldn't suggest tags", error)
            return []
        }
    }
}
