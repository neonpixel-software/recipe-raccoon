import Foundation

protocol DeleteTagUseCase {
    func execute(id: UUID) throws
}

final class DefaultDeleteTagUseCase: DeleteTagUseCase {
    private let repository: TagRepository

    init(repository: TagRepository) {
        self.repository = repository
    }

    func execute(id: UUID) throws {
        try repository.delete(id: id)
    }
}
