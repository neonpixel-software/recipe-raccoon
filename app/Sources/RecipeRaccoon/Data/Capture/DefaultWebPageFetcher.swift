import Foundation

/// Downloads a page directly and, when a bot check turns that away, once more in a web view.
/// Then reduces it to the text handed to the model: the recipe's JSON-LD when the page has it,
/// else the page's plain text.
final class DefaultWebPageFetcher: WebPageFetcher {
    /// Statuses a bot check answers with: Cloudflare's challenge is a 403 or 503, and some
    /// rate limiters show theirs with a 429 (issue #225). Any other error status is final.
    static let botCheckStatuses: Set<Int> = [403, 429, 503]

    private let directLoader: WebPageHTMLLoader
    private let browserLoader: WebPageHTMLLoader

    init(directLoader: WebPageHTMLLoader, browserLoader: WebPageHTMLLoader) {
        self.directLoader = directLoader
        self.browserLoader = browserLoader
    }

    func fetchPlainText(from url: URL) async throws -> String {
        let html = try await html(from: url)
        if let recipeText = RecipeStructuredData.recipeText(fromHTML: html) {
            return WebPageTextDecoding.truncated(recipeText)
        }
        guard let plainText = await HTMLPlainTextConverter.plainText(fromHTML: HTMLContentReducer.reduced(html)) else {
            throw WebPageFetchError.emptyContent
        }
        return WebPageTextDecoding.truncated(plainText)
    }

    private func html(from url: URL) async throws -> String {
        do {
            return try await directLoader.html(from: url)
        } catch let WebPageFetchError.httpStatus(status) where Self.botCheckStatuses.contains(status) {
            return try await browserLoader.html(from: url)
        }
    }
}
