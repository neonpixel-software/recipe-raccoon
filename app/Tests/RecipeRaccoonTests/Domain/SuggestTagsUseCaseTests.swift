@testable import RecipeRaccoon
import XCTest

private struct FakeFetchTagsUseCase: FetchTagsUseCase {
    var result: Result<[Tag], Error>

    func execute() throws -> [Tag] {
        try result.get()
    }
}

private struct SuggestionRequest {
    let title: String
    let ingredients: [String]
    let tagNames: [String]
}

/// Only used from the main actor by these tests.
private final class FakeTagSuggestionService: TagSuggestionService, @unchecked Sendable {
    var result: Result<[String], Error> = .success([])
    private(set) var requests: [SuggestionRequest] = []

    func suggestTags(title: String, ingredients: [String], from tagNames: [String]) async throws -> [String] {
        requests.append(SuggestionRequest(title: title, ingredients: ingredients, tagNames: tagNames))
        return try result.get()
    }
}

private struct SuggestionFailure: Error {}

@MainActor
final class SuggestTagsUseCaseTests: XCTestCase {
    private let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
    private let dessert = Tag(id: UUID(), name: "Dessert", isPreset: true)
    private let baking = Tag(id: UUID(), name: "Baking", isPreset: false)

    private func makeRecipe() -> Recipe {
        Recipe(
            id: UUID(),
            title: "Pancakes",
            ingredients: [IngredientLine(id: UUID(), rawText: "2 cups flour", amount: 2, unit: "cup", ingredientName: "flour")],
            steps: ["Cook."],
            source: .typed,
            tags: []
        )
    }

    private func makeUseCase(tags: Result<[Tag], Error>, service: FakeTagSuggestionService) -> DefaultSuggestTagsUseCase {
        DefaultSuggestTagsUseCase(fetchTagsUseCase: FakeFetchTagsUseCase(result: tags), suggestionService: service)
    }

    func testAsksAboutTheRecipeWithEveryTagName() async {
        let service = FakeTagSuggestionService()

        _ = await makeUseCase(tags: .success([breakfast, baking]), service: service).execute(for: makeRecipe())

        XCTAssertEqual(service.requests.map(\.title), ["Pancakes"])
        XCTAssertEqual(service.requests.first?.ingredients, ["2 cups flour"])
        XCTAssertEqual(service.requests.first?.tagNames, ["Breakfast", "Baking"])
    }

    func testMapsTheNamesToTagsInTheirOrderIgnoringCaseRepeatsAndUnknownNames() async {
        let service = FakeTagSuggestionService()
        service.result = .success(["baking", "Brunch", "Breakfast", "BAKING"])

        let tags = await makeUseCase(tags: .success([breakfast, dessert, baking]), service: service).execute(for: makeRecipe())

        XCTAssertEqual(tags, [baking, breakfast])
    }

    func testDoesntAskWhenThereAreNoTags() async {
        let service = FakeTagSuggestionService()

        let tags = await makeUseCase(tags: .success([]), service: service).execute(for: makeRecipe())

        XCTAssertEqual(tags, [])
        XCTAssertTrue(service.requests.isEmpty)
    }

    func testSuggestsNothingWhenTheModelFails() async {
        let service = FakeTagSuggestionService()
        service.result = .failure(SuggestionFailure())

        let tags = await makeUseCase(tags: .success([breakfast]), service: service).execute(for: makeRecipe())

        XCTAssertEqual(tags, [])
    }

    func testSuggestsNothingWhenTheTagsDontLoad() async {
        let service = FakeTagSuggestionService()

        let tags = await makeUseCase(tags: .failure(SuggestionFailure()), service: service).execute(for: makeRecipe())

        XCTAssertEqual(tags, [])
        XCTAssertTrue(service.requests.isEmpty)
    }
}
