@testable import RecipeRaccoon
import XCTest

final class DefaultWebPageFetcherTests: XCTestCase {
    private let url = URL(string: "https://example.com/banana-bread")!

    private let recipePage = """
    <html><head><script type="application/ld+json">
    {"@type":"Recipe","name":"Banana bread","recipeIngredient":["3 ripe bananas"],
     "recipeInstructions":[{"@type":"HowToStep","text":"Mash the bananas."}]}
    </script></head><body><nav>Home</nav></body></html>
    """

    func testUsesTheDirectPageWithoutTheBrowser() async throws {
        let browser = FakeHTMLLoader(result: .failure(WebPageFetchError.emptyContent))
        let fetcher = DefaultWebPageFetcher(directLoader: FakeHTMLLoader(result: .success(recipePage)), browserLoader: browser)

        let text = try await fetcher.fetchPlainText(from: url)

        XCTAssertEqual(text, "Banana bread\n\nIngredients:\n- 3 ripe bananas\n\nSteps:\n1. Mash the bananas.")
        XCTAssertEqual(browser.requestedURLs, [])
    }

    func testRetriesInTheBrowserForEachBotCheckStatus() async throws {
        for status in [403, 429, 503] {
            let browser = FakeHTMLLoader(result: .success(recipePage))
            let fetcher = DefaultWebPageFetcher(
                directLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.httpStatus(status))),
                browserLoader: browser
            )

            let text = try await fetcher.fetchPlainText(from: url)

            XCTAssertTrue(text.hasPrefix("Banana bread"), "\(status)")
            XCTAssertEqual(browser.requestedURLs, [url], "\(status)")
        }
    }

    func testDoesNotRetryOtherErrorStatuses() async {
        let browser = FakeHTMLLoader(result: .success(recipePage))
        let fetcher = DefaultWebPageFetcher(
            directLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.httpStatus(404))),
            browserLoader: browser
        )

        await assertThrows(fetcher, "httpStatus(404)")
        XCTAssertEqual(browser.requestedURLs, [])
    }

    func testDoesNotRetryOtherFetchErrors() async {
        let browser = FakeHTMLLoader(result: .success(recipePage))
        let fetcher = DefaultWebPageFetcher(
            directLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.tooLarge)),
            browserLoader: browser
        )

        await assertThrows(fetcher, "tooLarge")
        XCTAssertEqual(browser.requestedURLs, [])
    }

    func testPassesOnTheBrowsersError() async {
        let fetcher = DefaultWebPageFetcher(
            directLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.httpStatus(403))),
            browserLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.blockedByBotCheck))
        )

        await assertThrows(fetcher, "blockedByBotCheck")
    }

    func testFallsBackToPlainTextWithoutRecipeJSONLD() async throws {
        let html = "<html><body><h1>Banana bread</h1><p>3 ripe bananas</p></body></html>"
        let fetcher = DefaultWebPageFetcher(
            directLoader: FakeHTMLLoader(result: .success(html)),
            browserLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.emptyContent))
        )

        let text = try await fetcher.fetchPlainText(from: url)

        XCTAssertTrue(text.contains("Banana bread"))
        XCTAssertTrue(text.contains("3 ripe bananas"))
    }

    func testThrowsEmptyContentForAPageWithoutText() async {
        let fetcher = DefaultWebPageFetcher(
            directLoader: FakeHTMLLoader(result: .success("<html><body></body></html>")),
            browserLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.tooLarge))
        )

        await assertThrows(fetcher, "emptyContent")
    }

    func testTruncatesLongPlainText() async throws {
        let html = "<html><body><p>\(String(repeating: "flour ", count: 2000))</p></body></html>"
        let fetcher = DefaultWebPageFetcher(
            directLoader: FakeHTMLLoader(result: .success(html)),
            browserLoader: FakeHTMLLoader(result: .failure(WebPageFetchError.emptyContent))
        )

        let text = try await fetcher.fetchPlainText(from: url)

        XCTAssertEqual(text.count, WebPageTextDecoding.maxPlainTextCharacters)
    }

    /// `expected` is the error as it prints, for example "httpStatus(404)".
    private func assertThrows(
        _ fetcher: DefaultWebPageFetcher,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await fetcher.fetchPlainText(from: url)
            XCTFail("Expected an error", file: file, line: line)
        } catch let error as WebPageFetchError {
            XCTAssertEqual(String(describing: error), expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error \(error)", file: file, line: line)
        }
    }
}

private final class FakeHTMLLoader: WebPageHTMLLoader, @unchecked Sendable {
    private let result: Result<String, Error>
    private let lock = NSLock()
    private var urls: [URL] = []

    init(result: Result<String, Error>) {
        self.result = result
    }

    var requestedURLs: [URL] {
        lock.withLock { urls }
    }

    func html(from url: URL) async throws -> String {
        lock.withLock { urls.append(url) }
        return try result.get()
    }
}
