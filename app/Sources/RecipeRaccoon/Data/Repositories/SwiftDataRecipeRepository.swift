import Foundation
import SwiftData

final class SwiftDataRecipeRepository: RecipeRepository {
    /// Resolved on every call rather than stored, so a storage switch (PersistenceController)
    /// retargets the repository without rebuilding it.
    private let currentModelContext: () -> ModelContext
    private var modelContext: ModelContext {
        currentModelContext()
    }

    init(modelContext: @escaping @autoclosure () -> ModelContext) {
        currentModelContext = modelContext
    }

    func fetchAll() throws -> [Recipe] {
        let descriptor = FetchDescriptor<RecipeModel>(sortBy: [SortDescriptor(\.title)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func create(_ recipe: Recipe, newPhotos: [UUID: ProcessedPhoto]) throws {
        let model = recipe.toModel()
        model.tags = try resolveTagModels(for: recipe.tags)
        modelContext.insert(model)
        model.replacePhotos(with: recipe.photos, newPhotos: newPhotos, in: modelContext)
        try modelContext.save()
        try modelContext.deleteUnusedTags()
    }

    func update(_ recipe: Recipe, newPhotos: [UUID: ProcessedPhoto]) throws {
        let targetID = recipe.id
        let descriptor = FetchDescriptor<RecipeModel>(predicate: #Predicate { $0.id == targetID })
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RecipeRepositoryError.recipeNotFound
        }

        model.overwrite(with: recipe, newPhotos: newPhotos, in: modelContext)

        // Tags are a shared (non-owned) relationship: resolve to the existing,
        // already-persisted TagModel rows by id rather than remapping via
        // toModel(), which would insert duplicate rows for the same tag.
        model.tags = try resolveTagModels(for: recipe.tags)

        try modelContext.save()
        try modelContext.deleteUnusedTags()
    }

    /// A tag can be gone by the time its recipe saves: the unused-tag cleanup (#211) after
    /// another save, or a delete from another device, while a form still offered it. Such a tag
    /// is matched by name or made again, trimmed and ignoring case like
    /// SwiftDataTagRepository.findOrCreate, rather than dropped.
    private func resolveTagModels(for tags: [Tag]) throws -> [TagModel] {
        guard !tags.isEmpty else { return [] }
        let ids = Set(tags.map(\.id))
        let descriptor = FetchDescriptor<TagModel>(predicate: #Predicate { ids.contains($0.id) })
        let found = try modelContext.fetch(descriptor)
        let missing = tags.filter { tag in !found.contains { $0.id == tag.id } }
        guard !missing.isEmpty else { return found }

        var all = try modelContext.fetch(FetchDescriptor<TagModel>())
        var resolved = found
        for tag in missing {
            let name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if !resolved.contains(where: { $0 === match }) { resolved.append(match) }
            } else {
                let model = TagModel(name: name, isPreset: false)
                modelContext.insert(model)
                all.append(model)
                resolved.append(model)
            }
        }
        return resolved
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<RecipeModel>(predicate: #Predicate { $0.id == id })
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RecipeRepositoryError.recipeNotFound
        }
        modelContext.delete(model)
        try modelContext.save()
        try modelContext.deleteUnusedTags()
    }
}
