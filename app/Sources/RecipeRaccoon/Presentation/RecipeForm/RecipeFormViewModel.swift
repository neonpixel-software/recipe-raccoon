import Foundation
import Observation

enum RecipeFormMode {
    case create
    case edit(Recipe)
    /// A freshly AI-captured recipe awaiting review before its first save — pre-fills like
    /// .edit, but save() creates a new record with a fresh id rather than updating.
    case capture(Recipe)
}

struct IngredientLineDraft: Identifiable, Equatable {
    let id: UUID
    var amount: String
    var unit: String
    var ingredientName: String
    /// The line this row was hydrated from, if any. Preserved so that saving without
    /// touching this row keeps its original wording ("1 ⅔ cups", "1 cup plus 2
    /// tablespoons") and doesn't drop an ingredient the structured fields alone can't
    /// represent — see buildRecipe().
    fileprivate let original: IngredientLine?

    init(id: UUID = UUID(), amount: String = "", unit: String = "", ingredientName: String = "") {
        self.id = id
        self.amount = amount
        self.unit = unit
        self.ingredientName = ingredientName
        original = nil
    }

    init(ingredientLine: IngredientLine) {
        id = ingredientLine.id
        amount = ingredientLine.amount.map(IngredientAmountFormatter.format) ?? ""
        unit = ingredientLine.unit ?? ""
        ingredientName = ingredientLine.ingredientName ?? ""
        original = ingredientLine
    }

    /// True while the fields still hold exactly what they were hydrated with.
    fileprivate var isUnchangedFromOriginal: Bool {
        guard let original else { return false }
        return isAmountUnchangedFromOriginal
            && unit == (original.unit ?? "")
            && ingredientName == (original.ingredientName ?? "")
    }

    /// True while the Amount field still shows the loaded amount. The field shows it
    /// rounded (0.333 as "0.33"), so buildRecipe() keeps the stored value rather than
    /// re-parsing the display text when only the unit or name was edited.
    fileprivate var isAmountUnchangedFromOriginal: Bool {
        guard let original else { return false }
        return amount == (original.amount.map(IngredientAmountFormatter.format) ?? "")
    }
}

struct EquipmentDraft: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
}

struct StepDraft: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

/// A photo in the form's strip. New photos stay in memory until Save; Cancel drops them.
struct PhotoDraft: Identifiable, Equatable {
    enum State: Equatable {
        /// Already saved with the recipe; its thumbnail loads from the store.
        case stored
        /// Picked or taken, still being scaled down.
        case processing
        /// Picked or taken and ready to save.
        case processed(ProcessedPhoto)
    }

    let id: UUID
    fileprivate(set) var state: State
}

/// Main-actor isolated: photos are processed asynchronously and land back in the form's state.
@MainActor
@Observable
final class RecipeFormViewModel {
    /// Bundles the use cases and services the form needs, so the list and detail screens can
    /// pass them along as one value and the initializer stays under SonarCloud's arity limit.
    struct Dependencies {
        let createRecipeUseCase: CreateRecipeUseCase
        let updateRecipeUseCase: UpdateRecipeUseCase
        let fetchTagsUseCase: FetchTagsUseCase
        let findOrCreateTagUseCase: FindOrCreateTagUseCase
        let fetchPhotoThumbnailUseCase: FetchPhotoThumbnailUseCase
        let photoProcessor: PhotoProcessor
    }

    /// Loads a picked or taken photo's bytes; nil when there's nothing to load.
    typealias PhotoLoader = @Sendable () async throws -> Data?

    var title: String
    /// nil shows "Set Servings"; a number shows the stepper (Recipe.servingsRange).
    private(set) var servings: Int?
    var ingredients: [IngredientLineDraft]
    var equipment: [EquipmentDraft]
    var steps: [StepDraft]
    private(set) var allTags: [Tag] = []
    var selectedTagIDs: Set<UUID>
    var newTagName: String = ""
    var isAddingNewTag: Bool = false
    private(set) var photos: [PhotoDraft]
    /// Shown in the Photos section when a picked or taken photo couldn't be added.
    private(set) var photoErrorMessage: String?
    private(set) var errorMessage: String?

    private let mode: RecipeFormMode
    private let dependencies: Dependencies
    /// The recipe's own tags at load time (edit mode only) — merged into allTags
    /// defensively in loadTags(), in case a fetch races ahead of a just-created tag.
    private let initialTags: [Tag]

    init(mode: RecipeFormMode, dependencies: Dependencies) {
        self.mode = mode
        self.dependencies = dependencies

        switch mode {
        case .create:
            title = ""
            servings = nil
            ingredients = []
            equipment = []
            steps = []
            initialTags = []
            photos = []
        case let .edit(recipe), let .capture(recipe):
            title = recipe.title
            servings = recipe.servings
            ingredients = recipe.ingredients.map { IngredientLineDraft(ingredientLine: $0) }
            equipment = recipe.equipment.map { EquipmentDraft(name: $0) }
            steps = recipe.steps.map { StepDraft(text: $0) }
            initialTags = recipe.tags
            photos = recipe.photos.map { PhotoDraft(id: $0.id, state: .stored) }
        }
        selectedTagIDs = Set(initialTags.map(\.id))
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessingPhotos
    }

    var isProcessingPhotos: Bool {
        photos.contains { $0.state == .processing }
    }

    /// The number "Set Servings" starts the stepper at.
    static let defaultServings = 4

    func setServings() {
        servings = Self.defaultServings
    }

    /// Clamped to Recipe.servingsRange. Changes a number that's set only: with none set, the
    /// form shows "Set Servings" (setServings()) instead of the stepper.
    func changeServings(to value: Int) {
        guard servings != nil else { return }
        servings = min(max(value, Recipe.servingsRange.lowerBound), Recipe.servingsRange.upperBound)
    }

    func clearServings() {
        servings = nil
    }

    func addIngredient() {
        ingredients.append(IngredientLineDraft())
    }

    func removeIngredient(at index: Int) {
        guard ingredients.indices.contains(index) else { return }
        ingredients.remove(at: index)
    }

    func moveIngredientUp(at index: Int) {
        guard ingredients.indices.contains(index), index > 0 else { return }
        ingredients.swapAt(index, index - 1)
    }

    func moveIngredientDown(at index: Int) {
        guard ingredients.indices.contains(index), index < ingredients.count - 1 else { return }
        ingredients.swapAt(index, index + 1)
    }

    func addEquipment() {
        equipment.append(EquipmentDraft())
    }

    func removeEquipment(at index: Int) {
        guard equipment.indices.contains(index) else { return }
        equipment.remove(at: index)
    }

    func moveEquipmentUp(at index: Int) {
        guard equipment.indices.contains(index), index > 0 else { return }
        equipment.swapAt(index, index - 1)
    }

    func moveEquipmentDown(at index: Int) {
        guard equipment.indices.contains(index), index < equipment.count - 1 else { return }
        equipment.swapAt(index, index + 1)
    }

    func addStep() {
        steps.append(StepDraft())
    }

    func removeStep(at index: Int) {
        guard steps.indices.contains(index) else { return }
        steps.remove(at: index)
    }

    func moveStepUp(at index: Int) {
        guard steps.indices.contains(index), index > 0 else { return }
        steps.swapAt(index, index - 1)
    }

    func moveStepDown(at index: Int) {
        guard steps.indices.contains(index), index < steps.count - 1 else { return }
        steps.swapAt(index, index + 1)
    }

    /// Adds one photo per loader to the end of the strip, each with its own spinner, then
    /// loads and scales them down one at a time (a camera original can be 48 MP). A photo that
    /// fails is dropped and reported in the Photos section; the others are unaffected.
    func addPhotos(_ loaders: [PhotoLoader]) async {
        guard !loaders.isEmpty else { return }
        photoErrorMessage = nil
        let ids = loaders.map { _ in UUID() }
        photos += ids.map { PhotoDraft(id: $0, state: .processing) }

        for (id, load) in zip(ids, loaders) {
            let processed: ProcessedPhoto?
            do {
                if let data = try await load() {
                    processed = try await dependencies.photoProcessor.process(data)
                } else {
                    processed = nil
                }
            } catch {
                processed = nil
            }
            // The photo may have been deleted while it was processing.
            guard let index = photos.firstIndex(where: { $0.id == id }) else { continue }
            if let processed {
                photos[index].state = .processed(processed)
            } else {
                photos.remove(at: index)
                photoErrorMessage = String(localized: "A photo couldn't be added.")
            }
        }
    }

    /// The thumbnail to show for a photo: in memory for a new one, from the store for a saved
    /// one. Nil while processing, or when a saved photo's bytes aren't on this device yet.
    func thumbnailData(for photo: PhotoDraft) -> Data? {
        switch photo.state {
        case .stored: try? dependencies.fetchPhotoThumbnailUseCase.execute(id: photo.id)
        case .processing: nil
        case let .processed(processed): processed.thumbnailData
        }
    }

    func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
    }

    func makeCover(at index: Int) {
        guard photos.indices.contains(index), index > 0 else { return }
        photos.insert(photos.remove(at: index), at: 0)
    }

    func movePhotoLeft(at index: Int) {
        guard photos.indices.contains(index), index > 0 else { return }
        photos.swapAt(index, index - 1)
    }

    func movePhotoRight(at index: Int) {
        guard photos.indices.contains(index), index < photos.count - 1 else { return }
        photos.swapAt(index, index + 1)
    }

    func loadTags() {
        do {
            var tags = try dependencies.fetchTagsUseCase.execute()
            for tag in initialTags where !tags.contains(where: { $0.id == tag.id }) {
                tags.append(tag)
            }
            allTags = tags.sortedPresetsFirst()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleTag(_ tag: Tag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }

    func beginAddingNewTag() {
        isAddingNewTag = true
    }

    func confirmNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        newTagName = ""
        isAddingNewTag = false
        guard !trimmed.isEmpty else { return }

        do {
            let tag = try dependencies.findOrCreateTagUseCase.execute(name: trimmed)
            if !allTags.contains(where: { $0.id == tag.id }) {
                allTags.append(tag)
            }
            selectedTagIDs.insert(tag.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save() -> Recipe? {
        guard canSave else { return nil }

        let recipe = buildRecipe()
        let newPhotos = photos.reduce(into: [UUID: ProcessedPhoto]()) { newPhotos, photo in
            if case let .processed(processed) = photo.state {
                newPhotos[photo.id] = processed
            }
        }

        do {
            switch mode {
            case .create, .capture:
                try dependencies.createRecipeUseCase.execute(recipe, newPhotos: newPhotos)
            case .edit:
                try dependencies.updateRecipeUseCase.execute(recipe, newPhotos: newPhotos)
            }
            errorMessage = nil
            return recipe
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func buildRecipe() -> Recipe {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let builtIngredients = ingredients.compactMap { draft -> IngredientLine? in
            // An untouched row saves exactly as loaded, so the original wording and the
            // unrounded amount survive a save from the review or edit screen (issue #87).
            if let original = draft.original, draft.isUnchangedFromOriginal, !original.rawText.isEmpty {
                return original
            }

            let amount = draft.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            let unit = draft.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = draft.ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !amount.isEmpty || !unit.isEmpty || !name.isEmpty else {
                // No structured fields were ever filled in for this row. If it was
                // hydrated from an existing line with no structured data (e.g. a raw
                // AI-captured ingredient), keep it as-is rather than silently dropping
                // it just because the structured-only form can't represent it.
                guard let original = draft.original, !original.rawText.isEmpty else { return nil }
                return IngredientLine(id: draft.id, rawText: original.rawText)
            }

            let rawText = [amount, unit, name].filter { !$0.isEmpty }.joined(separator: " ")
            // Accepts what cooks type ("1 1/2", "1½", "2,5") as well as plain decimals. A
            // unit typed into the Amount field ("100g") isn't split out, so that stays nil.
            let parsedAmount = draft.isAmountUnchangedFromOriginal
                ? draft.original?.amount
                : IngredientAmountParser.parse(amount).flatMap { $0.unit == nil ? $0.value : nil }
            return IngredientLine(
                id: draft.id,
                rawText: rawText,
                amount: parsedAmount,
                unit: unit.isEmpty ? nil : unit,
                ingredientName: name.isEmpty ? nil : name
            )
        }
        let builtEquipment = equipment
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let builtSteps = steps
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Falls back to initialTags for any id not (yet) in allTags, so a save that
        // somehow races ahead of loadTags() still preserves the recipe's original
        // tags rather than silently dropping them. Filters a combined ordered list
        // (rather than mapping over selectedTagIDs directly) since Set iteration
        // order is undefined and tags is an ordered array.
        let tagSource = allTags + initialTags.filter { initial in !allTags.contains { $0.id == initial.id } }
        let selectedTags = tagSource.filter { selectedTagIDs.contains($0.id) }

        // Only the id and source differ per mode. .edit preserves both from the
        // original; .capture is a fresh record built from the captured draft, so it
        // gets a new id but keeps the draft's source.
        let (id, source) = switch mode {
        case .create: (UUID(), RecipeSource.typed)
        case let .capture(original): (UUID(), original.source)
        case let .edit(original): (original.id, original.source)
        }
        return Recipe(
            id: id,
            title: trimmedTitle,
            servings: servings,
            ingredients: builtIngredients,
            equipment: builtEquipment,
            steps: builtSteps,
            source: source,
            tags: selectedTags,
            photos: photos.map { RecipePhoto(id: $0.id) }
        )
    }
}
