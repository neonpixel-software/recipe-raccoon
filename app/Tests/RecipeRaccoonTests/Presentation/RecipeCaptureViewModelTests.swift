@testable import RecipeRaccoon
import XCTest

private struct FakeCaptureRecipeUseCase: CaptureRecipeUseCase {
    var result: Result<Recipe, Error>

    func execute(text _: String) async throws -> Recipe {
        try result.get()
    }
}

private struct CaptureFailure: Error, Equatable {}

@MainActor
final class RecipeCaptureViewModelTests: XCTestCase {
    func testCanCaptureIsFalseWhenTextIsBlankOrWhitespace() {
        let viewModel = RecipeCaptureViewModel(captureRecipeUseCase: FakeCaptureRecipeUseCase(result: .success(makeRecipe())))

        viewModel.rawText = "   "

        XCTAssertFalse(viewModel.canCapture)
    }

    func testCanCaptureIsTrueWhenTextIsNonBlank() {
        let viewModel = RecipeCaptureViewModel(captureRecipeUseCase: FakeCaptureRecipeUseCase(result: .success(makeRecipe())))

        viewModel.rawText = "2 eggs\nMix well"

        XCTAssertTrue(viewModel.canCapture)
    }

    func testCaptureReturnsNilWithoutCallingUseCaseWhenTextIsBlank() async {
        let viewModel = RecipeCaptureViewModel(captureRecipeUseCase: FakeCaptureRecipeUseCase(result: .success(makeRecipe())))
        viewModel.rawText = "   "

        let result = await viewModel.capture()

        XCTAssertNil(result)
    }

    func testCaptureReturnsRecipeOnSuccessAndClearsError() async {
        let recipe = makeRecipe(title: "Pancakes")
        let viewModel = RecipeCaptureViewModel(captureRecipeUseCase: FakeCaptureRecipeUseCase(result: .success(recipe)))
        viewModel.rawText = "some recipe text"

        let result = await viewModel.capture()

        XCTAssertEqual(result, recipe)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isCapturing)
    }

    func testCaptureSetsErrorMessageAndReturnsNilOnFailureWithoutClearingText() async {
        let viewModel = RecipeCaptureViewModel(captureRecipeUseCase: FakeCaptureRecipeUseCase(result: .failure(CaptureFailure())))
        viewModel.rawText = "some recipe text"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.rawText, "some recipe text")
        XCTAssertFalse(viewModel.isCapturing)
    }

    /// A failure from the model itself (guardrail, schema mismatch) is logged, and the user
    /// sees the same message.
    func testCaptureShowsTheSameMessageWhenTheModelFails() async {
        let failure = RecipeCaptureError.captureFailed(underlying: CaptureFailure())
        let viewModel = RecipeCaptureViewModel(captureRecipeUseCase: FakeCaptureRecipeUseCase(result: .failure(failure)))
        viewModel.rawText = "some recipe text"

        let result = await viewModel.capture()

        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, String(localized: "Couldn't extract a recipe from that text. Check it over and try again."))
    }

    private func makeRecipe(title: String = "") -> Recipe {
        Recipe(id: UUID(), title: title, ingredients: [], steps: [], source: .typed, tags: [])
    }
}
