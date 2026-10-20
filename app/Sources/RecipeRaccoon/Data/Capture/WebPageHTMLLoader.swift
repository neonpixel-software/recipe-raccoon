import Foundation

/// Downloads a page's HTML for DefaultWebPageFetcher. URLSessionWebPageHTMLLoader does it
/// directly; WebKitWebPageHTMLLoader is for pages behind a bot check (issue #225).
protocol WebPageHTMLLoader: Sendable {
    func html(from url: URL) async throws -> String
}
