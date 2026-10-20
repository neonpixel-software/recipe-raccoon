@testable import RecipeRaccoon
import XCTest

final class WebPageNavigationPolicyTests: XCTestCase {
    private let siteHost = "miljuschka.nl"

    private func allows(_ string: String, isMainFrame: Bool = true, siteHost: String? = "miljuschka.nl") -> Bool {
        WebPageNavigationPolicy.allows(URL(string: string), isMainFrame: isMainFrame, siteHost: siteHost)
    }

    func testAllowsThePageAndTheBotChecksRedirectOnTheSameSite() {
        XCTAssertTrue(allows("https://miljuschka.nl/het-beste-bananenbrood-recept-ooit/"))
        XCTAssertTrue(allows("https://miljuschka.nl/het-beste-bananenbrood-recept-ooit/?ki-cf-botcl=1"))
        XCTAssertTrue(allows("https://miljuschka.nl/cdn-cgi/challenge-platform/h/b/orchestrate", isMainFrame: false))
    }

    func testTreatsWWWAndCaseAsTheSameSite() {
        XCTAssertTrue(allows("https://www.miljuschka.nl/recept/"))
        XCTAssertTrue(allows("https://MILJUSCHKA.nl/recept/", siteHost: "www.miljuschka.nl"))
    }

    func testCancelsOtherSitesInTheMainFrame() {
        XCTAssertFalse(allows("https://ads.example.com/landing"))
        XCTAssertFalse(allows("https://evilmiljuschka.nl/"))
        XCTAssertFalse(allows("https://challenges.cloudflare.com/cdn-cgi/challenge-platform/"))
    }

    func testAllowsOnlyCloudflaresChallengeFromAnotherSiteInAFrame() {
        XCTAssertTrue(allows("https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/b/turnstile/", isMainFrame: false))
        XCTAssertFalse(allows("https://googleads.g.doubleclick.net/pagead/ads", isMainFrame: false))
    }

    func testAllowsBlankFramesButNotABlankPage() {
        XCTAssertTrue(allows("about:blank", isMainFrame: false))
        XCTAssertTrue(allows("about:srcdoc", isMainFrame: false))
        XCTAssertFalse(allows("about:blank"))
    }

    func testCancelsOtherSchemesAndMissingURLs() {
        XCTAssertFalse(allows("http://miljuschka.nl/"))
        XCTAssertFalse(allows("javascript:alert(1)", isMainFrame: false))
        XCTAssertFalse(allows("itms-apps://apps.apple.com/app/id1"))
        XCTAssertFalse(WebPageNavigationPolicy.allows(nil, isMainFrame: false, siteHost: siteHost))
        XCTAssertFalse(allows("https://miljuschka.nl/", siteHost: nil))
    }
}
