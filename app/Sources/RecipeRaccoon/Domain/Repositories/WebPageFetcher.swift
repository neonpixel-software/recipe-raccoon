import Foundation

protocol WebPageFetcher: Sendable {
    func fetchPlainText(from url: URL) async throws -> String
}

enum WebPageFetchError: Error {
    case invalidURL
    case requestFailed(underlying: Error)
    case httpStatus(Int)
    case emptyContent
    case tooLarge
    case insecureConnection
    /// The site's bot check turned the app away, even in a web view (issue #225).
    case blockedByBotCheck
}
