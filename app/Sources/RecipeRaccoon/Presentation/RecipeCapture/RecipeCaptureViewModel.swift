import Foundation
import Observation

@Observable
@MainActor
final class RecipeCaptureViewModel {
    var rawText: String = ""
    private(set) var isCapturing = false
    private(set) var errorMessage: String?

    private let captureRecipeUseCase: CaptureRecipeUseCase

    init(captureRecipeUseCase: CaptureRecipeUseCase) {
        self.captureRecipeUseCase = captureRecipeUseCase
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
            let recipe = try await captureRecipeUseCase.execute(text: rawText)
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
