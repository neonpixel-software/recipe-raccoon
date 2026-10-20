import Foundation

protocol TagRepository {
    func fetchAll() throws -> [Tag]
    func findOrCreate(name: String) throws -> Tag
    /// Deletes a custom tag and takes it off every recipe that has it. Does nothing for a
    /// preset or an unknown id.
    func delete(id: UUID) throws
}
