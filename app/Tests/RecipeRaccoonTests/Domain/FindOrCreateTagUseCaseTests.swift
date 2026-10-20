@testable import RecipeRaccoon
import XCTest

private final class FakeTagRepository: TagRepository {
    var findOrCreateResult: Result<Tag, Error> = .success(Tag(id: UUID(), name: "", isPreset: false))
    private(set) var requestedNames: [String] = []

    func fetchAll() throws -> [Tag] { [] }

    func findOrCreate(name: String) throws -> Tag {
        requestedNames.append(name)
        return try findOrCreateResult.get()
    }

    func delete(id _: UUID) throws {}
}

private struct RepositoryFailure: Error, Equatable {}

final class FindOrCreateTagUseCaseTests: XCTestCase {
    func testExecutePassesNameToRepositoryAndReturnsResult() throws {
        let tag = Tag(id: UUID(), name: "Spicy", isPreset: false)
        let repository = FakeTagRepository()
        repository.findOrCreateResult = .success(tag)
        let useCase = DefaultFindOrCreateTagUseCase(repository: repository)

        let result = try useCase.execute(name: "Spicy")

        XCTAssertEqual(result, tag)
        XCTAssertEqual(repository.requestedNames, ["Spicy"])
    }

    func testExecutePropagatesRepositoryError() {
        let repository = FakeTagRepository()
        repository.findOrCreateResult = .failure(RepositoryFailure())
        let useCase = DefaultFindOrCreateTagUseCase(repository: repository)

        XCTAssertThrowsError(try useCase.execute(name: "Spicy")) { error in
            XCTAssertTrue(error is RepositoryFailure)
        }
    }
}
