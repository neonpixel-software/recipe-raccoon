import Foundation
import SwiftData

extension RecipeModel {
    func toDomain() -> Recipe {
        Recipe(
            id: id,
            title: title,
            servings: validServings,
            ingredients: (ingredients ?? []).sorted { $0.position < $1.position }.map { $0.toDomain() },
            equipment: equipment,
            steps: steps,
            source: source,
            tags: (tags ?? []).map { $0.toDomain() },
            photos: sortedPhotos.map { RecipePhoto(id: $0.id) }
        )
    }

    /// Sorted by position, then by id. Two devices reordering the same gallery offline can
    /// leave colliding positions (CloudKit merges per record). Breaking ties by id gives every
    /// device the same order, and so the same cover. The next save numbers them 0..<n again.
    var sortedPhotos: [RecipePhotoModel] {
        (photos ?? []).sorted {
            ($0.position, $0.id.uuidString) < ($1.position, $1.id.uuidString)
        }
    }
}

extension RecipeModel {
    /// isTypedSource and sourceURL are set together by toModel(), but rows can also arrive
    /// through CloudKit (other devices, other app versions), so a URL-sourced row without a URL
    /// is treated as typed rather than crashing the list or a storage switch.
    private var source: RecipeSource {
        if !isTypedSource, let sourceURL {
            return .url(sourceURL)
        }
        return .typed
    }

    /// Rows can arrive through CloudKit from other app versions, so a number outside
    /// Recipe.servingsRange reads as unknown.
    private var validServings: Int? {
        servings.flatMap { Recipe.servingsRange.contains($0) ? $0 : nil }
    }
}

extension Recipe {
    func toModel() -> RecipeModel {
        let isTyped: Bool
        let url: URL?
        switch source {
        case .typed:
            isTyped = true
            url = nil
        case let .url(sourceURL):
            isTyped = false
            url = sourceURL
        }

        // tags is deliberately omitted (defaults to []): tags are a shared relationship
        // resolved to already-persisted TagModel rows by SwiftDataRecipeRepository, never
        // built via toModel() — see resolveTagModels(for:).
        return RecipeModel(
            id: id,
            title: title,
            servings: servings,
            steps: steps,
            equipment: equipment,
            isTypedSource: isTyped,
            sourceURL: url,
            ingredients: ingredientModels()
        )
    }

    /// Ingredient rows numbered by their index, since SwiftData doesn't keep the
    /// order of to-many relationships (RecipeModel.toDomain() sorts by position).
    func ingredientModels() -> [IngredientLineModel] {
        ingredients.enumerated().map { index, line in line.toModel(position: index) }
    }
}

extension RecipeModel {
    /// Replaces every field except tags with `recipe`'s. Tags are left to the caller,
    /// because they're a shared relationship that must resolve to rows already in `context`.
    /// `newPhotos` holds the bytes of photos that have no row yet (see replacePhotos).
    func overwrite(with recipe: Recipe, newPhotos: [UUID: ProcessedPhoto], in context: ModelContext) {
        title = recipe.title
        servings = recipe.servings
        steps = recipe.steps
        equipment = recipe.equipment
        switch recipe.source {
        case .typed:
            isTypedSource = true
            sourceURL = nil
        case let .url(url):
            isTypedSource = false
            sourceURL = url
        }

        // The .cascade delete rule only fires on parent deletion, not on reassigning
        // the relationship array, so old children must be deleted explicitly here or
        // they leak as orphaned rows.
        (ingredients ?? []).forEach { context.delete($0) }
        ingredients = recipe.ingredientModels()
        replacePhotos(with: recipe.photos, newPhotos: newPhotos, in: context)
    }

    /// Makes the gallery match `photos`, numbering positions 0..<n. Existing rows are kept
    /// (unlike ingredient lines, which are rebuilt), so unchanged photos aren't uploaded
    /// again. Rows not in `photos` are deleted. A photo without a row is inserted from
    /// `newPhotos`, or skipped if its bytes aren't there. A kept row missing its bytes takes
    /// them from `newPhotos`; a row that has them is never rewritten (a photo's bytes don't
    /// change).
    func replacePhotos(with photos: [RecipePhoto], newPhotos: [UUID: ProcessedPhoto], in context: ModelContext) {
        let current = self.photos ?? []
        var rowsByID: [UUID: RecipePhotoModel] = [:]
        for row in current where rowsByID[row.id] == nil {
            rowsByID[row.id] = row
        }

        var gallery: [RecipePhotoModel] = []
        for photo in photos where !gallery.contains(where: { $0.id == photo.id }) {
            if let row = rowsByID[photo.id] {
                if !row.hasBytes, let bytes = newPhotos[photo.id] {
                    row.imageData = bytes.imageData
                    row.thumbnailData = bytes.thumbnailData
                }
                gallery.append(row)
            } else if let bytes = newPhotos[photo.id] {
                let row = RecipePhotoModel(id: photo.id, imageData: bytes.imageData, thumbnailData: bytes.thumbnailData)
                context.insert(row)
                gallery.append(row)
            }
        }

        // The .cascade rule doesn't fire on reassigning the relationship (see overwrite),
        // so dropped rows, including duplicate rows for one id, are deleted here.
        let kept = Set(gallery.map(ObjectIdentifier.init))
        for row in current where !kept.contains(ObjectIdentifier(row)) {
            context.delete(row)
        }
        for (index, row) in gallery.enumerated() where row.position != index {
            row.position = index
        }
        self.photos = gallery
    }
}
