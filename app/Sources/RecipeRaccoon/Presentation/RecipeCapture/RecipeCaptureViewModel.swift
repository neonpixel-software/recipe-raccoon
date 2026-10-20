import Foundation
import Observation

@Observable
@MainActor
final class RecipeCaptureViewModel {
    var rawText: String = ""
    private(set) var isCapturing = false
    private(set) var errorMessage: String?

    private let captureRecipeUseCase: CaptureRecipeUseCase
    /// Picks the tags the review screen starts with selected; nil starts it with none.
    private let suggestTagsUseCase: SuggestTagsUseCase?

    init(captureRecipeUseCase: CaptureRecipeUseCase, suggestTagsUseCase: SuggestTagsUseCase? = nil) {
        self.captureRecipeUseCase = captureRecipeUseCase
        self.suggestTagsUseCase = suggestTagsUseCase
    }

    var canCapture: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func capture() async -> Recipe? {
        guard canCapture else { return nil }

        isCapturing = true
        defer { isCapturing = false }

        do {
            var recipe = try await captureRecipeUseCase.execute(text: rawText)
            if recipe.tags.isEmpty, let suggestTagsUseCase {
                recipe.tags = await suggestTagsUseCase.execute(for: recipe)
            }
            errorMessage = nil
            return recipe
        } catch {
            // Log the underlying cause (guardrail rejection, model unavailable, schema
            // mismatch, etc.) for on-device verification; the user only sees the generic
            // message below.
            if case let RecipeCaptureError.captureFailed(underlying) = error {
                Log.presentation.failure("Recipe capture failed", underlying)
            }
            errorMessage = String(localized: "Couldn't extract a recipe from that text. Check it over and try again.")
            return nil
        }
    }
}
