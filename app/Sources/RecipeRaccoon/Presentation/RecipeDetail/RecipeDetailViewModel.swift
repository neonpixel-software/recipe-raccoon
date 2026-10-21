import Foundation
import Observation

@Observable
final class RecipeDetailViewModel {
    var recipe: Recipe {
        // An edit can change the recipe's servings; the screen then shows its new number.
        didSet { shownServings = recipe.servings }
    }

    /// The servings the ingredients are shown for (Phase 15.3), the recipe's own number on every
    /// open. Never saved: scaling only changes what this screen shows. nil while the recipe has
    /// no number.
    private(set) var shownServings: Int?
    var isPresentingEdit = false
    var isPresentingDeleteConfirmation = false
    private(set) var errorMessage: String?
    private(set) var isDeleted = false

    private let formDependencies: RecipeFormViewModel.Dependencies
    private let deleteRecipeUseCase: DeleteRecipeUseCase
    private let fetchPhotoImageUseCase: FetchPhotoImageUseCase

    init(
        recipe: Recipe,
        formDependencies: RecipeFormViewModel.Dependencies,
        deleteRecipeUseCase: DeleteRecipeUseCase,
        fetchPhotoImageUseCase: FetchPhotoImageUseCase
    ) {
        self.recipe = recipe
        shownServings = recipe.servings
        self.formDependencies = formDependencies
        self.deleteRecipeUseCase = deleteRecipeUseCase
        self.fetchPhotoImageUseCase = fetchPhotoImageUseCase
    }

    /// Whether the ingredients are shown for another number than the recipe's own.
    var isScaled: Bool {
        shownServings != recipe.servings
    }

    var canDecreaseServings: Bool {
        shownServings.map { $0 > Recipe.servingsRange.lowerBound } ?? false
    }

    var canIncreaseServings: Bool {
        shownServings.map { $0 < Recipe.servingsRange.upperBound } ?? false
    }

    func decreaseServings() {
        guard canDecreaseServings, let shown = shownServings else { return }
        shownServings = shown - 1
    }

    func increaseServings() {
        guard canIncreaseServings, let shown = shownServings else { return }
        shownServings = shown + 1
    }

    func resetServings() {
        shownServings = recipe.servings
    }

    /// The recipe's ingredient lines for the servings shown: scaled when they differ from the
    /// recipe's own, as written otherwise.
    var shownIngredients: [IngredientLine] {
        guard let shown = shownServings, let own = recipe.servings, shown != own else { return recipe.ingredients }
        let factor = Double(shown) / Double(own)
        return recipe.ingredients.map { $0.scaled(by: factor) }
    }

    /// A gallery photo's full image, or nil while its bytes aren't on this device.
    func imageData(for photo: RecipePhoto) -> Data? {
        try? fetchPhotoImageUseCase.execute(id: photo.id)
    }

    @MainActor
    func makeEditFormViewModel() -> RecipeFormViewModel {
        RecipeFormViewModel(mode: .edit(recipe), dependencies: formDependencies)
    }

    func delete() {
        do {
            try deleteRecipeUseCase.execute(id: recipe.id)
            errorMessage = nil
            isDeleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
