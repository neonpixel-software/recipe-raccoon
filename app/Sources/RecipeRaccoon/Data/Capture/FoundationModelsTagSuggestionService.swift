import Foundation
import FoundationModels

/// Picks the user's tags that fit a captured recipe with the on-device model, in a call of its
/// own after the capture so the extraction prompt (tuned in #76) stays as it is. The answer is
/// limited to the tag names given, at most three, so the model can't invent a tag. With only
/// the presets it takes about 0.3 s on the dev Mac; it picked Breakfast for pancakes, Lunch for
/// tomato soup, Dinner for spaghetti bolognese and Dessert for cookies.
///
/// Not unit tested, like FoundationModelsRecipeCaptureService: the model only runs on a
/// device with Apple Intelligence. DefaultSuggestTagsUseCase, which maps its answer to tags,
/// is tested.
final class FoundationModelsTagSuggestionService: TagSuggestionService {
    static let maximumTags = 3

    func suggestTags(title: String, ingredients: [String], from tagNames: [String]) async throws -> [String] {
        guard !tagNames.isEmpty else { return [] }
        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(name: "TagChoice", properties: [
                DynamicGenerationSchema.Property(
                    name: "tags",
                    description: "The tags from the list that fit this recipe, best first; empty if none fits",
                    schema: DynamicGenerationSchema(
                        arrayOf: DynamicGenerationSchema(name: "Tag", anyOf: tagNames),
                        minimumElements: 0,
                        maximumElements: Self.maximumTags
                    )
                ),
            ]),
            dependencies: []
        )
        let session = LanguageModelSession(instructions: {
            "Pick the tags that fit a recipe from this list: \(tagNames.joined(separator: ", ")). " +
                "Only pick a tag that clearly fits, such as the meal it's for or what kind of dish it is. " +
                "Pick none if none fits."
        })
        let response = try await session.respond(
            to: "Recipe: \(title)\nIngredients: \(ingredients.joined(separator: "; "))",
            schema: schema,
            options: GenerationOptions(samplingMode: .greedy)
        )
        return try response.content.value([String].self, forProperty: "tags")
    }
}
