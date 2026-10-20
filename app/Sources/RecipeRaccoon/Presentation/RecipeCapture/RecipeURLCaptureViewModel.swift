import Foundation
import Observation

@Observable
@MainActor
final class RecipeURLCaptureViewModel {
    var urlText: String = ""
    private(set) var isCapturing = false
    private(set) var errorMessage: String?

    private let captureRecipeFromURLUseCase: CaptureRecipeFromURLUseCase

    init(captureRecipeFromURLUseCase: CaptureRecipeFromURLUseCase) {
        self.captureRecipeFromURLUseCase = captureRecipeFromURLUseCase
    }

    var canCapture: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func capture() async -> Recipe? {
        guard canCapture else { return nil }

        isCapturing = true
        defer { isCapturing = false }

        do {
            let recipe = try await captureRecipeFromURLUseCase.execute(urlString: urlText)
            errorMessage = nil
            return recipe
        } catch {
            Log.presentation.failure("Recipe URL capture failed", error)
            if case WebPageFetchError.tooLarge = error {
                errorMessage = String(localized: "That page is too large to read. Try a link to just the recipe.")
            } else if case WebPageFetchError.insecureConnection = error {
                errorMessage = String(localized: "That site doesn't use a secure connection (https), so it can't be opened.")
            } else if case WebPageFetchError.blockedByBotCheck = error {
                errorMessage = String(localized: "That site doesn't let apps read its pages. Copy the recipe from the site and paste it into Type It.")
            } else if error is WebPageFetchError {
                errorMessage = String(localized: "Couldn't load that page. Check the link and try again.")
            } else {
                errorMessage = String(localized: "Couldn't find a recipe on that page. Check it over and try again.")
            }
            return nil
        }
    }
}
