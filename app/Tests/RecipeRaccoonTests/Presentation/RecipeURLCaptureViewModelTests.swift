@testable import RecipeRaccoon
import XCTest

private struct FakeCaptureRecipeFromURLUseCase: CaptureRecipeFromURLUseCase {
    var result: Result<Recipe, Error>

    func execute(urlString _: String) async throws -> Recipe {
        try result.get()
    }
}

private struct AICaptureFailure: Error, Equatable {}

@MainActor
private final class FakeSuggestTagsUseCase: SuggestTagsUseCase {
    let tags: [Tag]
    private(set) var requestedTitles: [String] = []

    init(tags: [Tag]) {
        self.tags = tags
    }

    func execute(for recipe: Recipe) async -> [Tag] {
        requestedTitles.append(recipe.title)
        return tags
    }
}

@MainActor
final class RecipeURLCaptureViewModelTests: XCTestCase {
    func testCanCaptureIsFalseWhenURLTextIsBlankOrWhitespace() {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .success(makeRecipe())))

        viewModel.urlText = "   "

        XCTAssertFalse(viewModel.canCapture)
    }

    func testCanCaptureIsTrueWhenURLTextIsNonBlank() {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .success(makeRecipe())))

        viewModel.urlText = "https://example.com/recipe"

        XCTAssertTrue(viewModel.canCapture)
    }

    func testCaptureReturnsNilWithoutCallingUseCaseWhenURLTextIsBlank() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .success(makeRecipe())))
        viewModel.urlText = "   "

        let result = await viewModel.capture()

        XCTAssertNil(result)
    }

    func testCaptureReturnsRecipeOnSuccessAndClearsError() async {
        let recipe = makeRecipe(title: "Pancakes")
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .success(recipe)))
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertEqual(result, recipe)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isCapturing)
    }

    func testCaptureSetsPageLoadMessageOnWebPageFetchError() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .failure(WebPageFetchError.invalidURL)))
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "Couldn't load that page. Check the link and try again.")
    }

    func testCaptureSetsPageLoadMessageOnHTTPStatusError() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .failure(WebPageFetchError.httpStatus(404))))
        viewModel.urlText = "https://example.com/missing-recipe"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "Couldn't load that page. Check the link and try again.")
    }

    func testCaptureSetsTooLargeMessageOnTooLargeError() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .failure(WebPageFetchError.tooLarge)))
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "That page is too large to read. Try a link to just the recipe.")
    }

    func testCaptureSetsInsecureConnectionMessageOnInsecureConnectionError() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .failure(WebPageFetchError.insecureConnection)))
        viewModel.urlText = "http://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "That site doesn't use a secure connection (https), so it can't be opened.")
    }

    func testCaptureSetsBotCheckMessageOnBlockedByBotCheckError() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .failure(WebPageFetchError.blockedByBotCheck)))
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "That site doesn't let apps read its pages. Copy the recipe from the site and paste it into Type It.")
    }

    func testCaptureSetsExtractionMessageOnNonFetchError() async {
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .failure(AICaptureFailure())))
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "Couldn't find a recipe on that page. Check it over and try again.")
        XCTAssertEqual(viewModel.urlText, "https://example.com/recipe")
        XCTAssertFalse(viewModel.isCapturing)
    }

    func testCaptureStartsTheRecipeWithTheSuggestedTags() async {
        let breakfast = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let recipe = makeRecipe(title: "Pancakes")
        let suggest = FakeSuggestTagsUseCase(tags: [breakfast])
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .success(recipe)), suggestTagsUseCase: suggest)
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertEqual(result?.tags, [breakfast])
        XCTAssertEqual(suggest.requestedTitles, ["Pancakes"])
    }

    func testCaptureKeepsTagsTheRecipeAlreadyHas() async {
        let dinner = Tag(id: UUID(), name: "Dinner", isPreset: true)
        var recipe = makeRecipe(title: "Stew")
        recipe.tags = [dinner]
        let suggest = FakeSuggestTagsUseCase(tags: [Tag(id: UUID(), name: "Lunch", isPreset: true)])
        let viewModel = RecipeURLCaptureViewModel(captureRecipeFromURLUseCase: FakeCaptureRecipeFromURLUseCase(result: .success(recipe)), suggestTagsUseCase: suggest)
        viewModel.urlText = "https://example.com/recipe"

        let result = await viewModel.capture()

        XCTAssertEqual(result?.tags, [dinner])
        XCTAssertEqual(suggest.requestedTitles, [])
    }

    private func makeRecipe(title: String = "") -> Recipe {
        Recipe(id: UUID(), title: title, ingredients: [], steps: [], source: .typed, tags: [])
    }
}
