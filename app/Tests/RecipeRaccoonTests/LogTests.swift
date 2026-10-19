@testable import RecipeRaccoon
import XCTest

final class LogTests: XCTestCase {
    func testSummarizesAFoundationErrorByDomainAndCode() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSFilePathErrorKey: "/Users/someone/recipe.txt"])

        XCTAssertEqual(error.logSummary, "NSCocoaErrorDomain 260")
    }

    /// The summary is logged public, so it must never carry an associated value: a failed page
    /// fetch wraps an error whose description holds the recipe's URL.
    func testSummarizesASwiftErrorWithoutItsAssociatedValues() {
        let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSURLErrorFailingURLStringErrorKey: "https://example.com/private-recipe"])
        let error = WebPageFetchError.requestFailed(underlying: underlying)

        XCTAssertEqual(error.logSummary, "RecipeRaccoon.WebPageFetchError 0")
    }

    /// The doc comment's example: a case without values counts after the ones with them.
    func testASwiftErrorsCodeIsItsCasePosition() {
        XCTAssertEqual(WebPageFetchError.tooLarge.logSummary, "RecipeRaccoon.WebPageFetchError 4")
    }

    func testAttemptReturnsTheResultWhenNothingThrows() {
        XCTAssertEqual(Log.data.attempt("Reading") { 42 }, 42)
    }

    /// The failure is logged and the caller carries on with nil, as the app's error paths do.
    func testAttemptReturnsNilWhenTheBodyThrows() {
        let result: Int? = Log.data.attempt("Reading") { throw CocoaError(.fileReadNoSuchFile) }

        XCTAssertNil(result)
    }
}
