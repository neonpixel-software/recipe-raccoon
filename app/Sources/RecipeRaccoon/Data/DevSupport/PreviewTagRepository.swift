#if DEBUG
import Foundation

/// Feeds a couple of sample tags into SwiftUI previews without touching a real SwiftData store.
struct PreviewTagRepository: TagRepository {
    func fetchAll() throws -> [Tag] {
        [
            Tag(id: UUID(), name: "Breakfast", isPreset: true),
            Tag(id: UUID(), name: "Dinner", isPreset: true),
        ]
    }

    func findOrCreate(name: String) throws -> Tag {
        Tag(id: UUID(), name: name, isPreset: false)
    }

    func delete(id _: UUID) throws {
        // Nothing stored to delete.
    }
}
#endif
