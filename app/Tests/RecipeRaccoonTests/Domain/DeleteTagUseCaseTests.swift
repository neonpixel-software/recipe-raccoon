@testable import RecipeRaccoon
import XCTest

private final class FakeTagRepository: TagRepository {
    private(set) var deletedIDs: [UUID] = []

    func fetchAll() throws -> [Tag] { [] }

    func findOrCreate(name: String) throws -> Tag {
        Tag(id: UUID(), name: name, isPreset: false)
    }

    func delete(id: UUID) throws {
        deletedIDs.append(id)
    }
}

final class DeleteTagUseCaseTests: XCTestCase {
    func testExecutePassesTheIDToTheRepository() throws {
        let repository = FakeTagRepository()
        let id = UUID()

        try DefaultDeleteTagUseCase(repository: repository).execute(id: id)

        XCTAssertEqual(repository.deletedIDs, [id])
    }
}
