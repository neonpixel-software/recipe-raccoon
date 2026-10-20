@testable import RecipeRaccoon
import XCTest

private struct FakeTagRepository: TagRepository {
    var fetchAllResult: Result<[Tag], Error>

    func fetchAll() throws -> [Tag] {
        try fetchAllResult.get()
    }

    func findOrCreate(name: String) throws -> Tag {
        Tag(id: UUID(), name: name, isPreset: false)
    }

    func delete(id _: UUID) throws {}
}

private struct RepositoryFailure: Error, Equatable {}

final class FetchTagsUseCaseTests: XCTestCase {
    func testExecuteReturnsTagsFromRepository() throws {
        let tag = Tag(id: UUID(), name: "Breakfast", isPreset: true)
        let useCase = DefaultFetchTagsUseCase(repository: FakeTagRepository(fetchAllResult: .success([tag])))

        let tags = try useCase.execute()

        XCTAssertEqual(tags, [tag])
    }

    func testExecutePropagatesRepositoryError() {
        let useCase = DefaultFetchTagsUseCase(repository: FakeTagRepository(fetchAllResult: .failure(RepositoryFailure())))

        XCTAssertThrowsError(try useCase.execute()) { error in
            XCTAssertTrue(error is RepositoryFailure)
        }
    }
}
