@testable import RecipeRaccoon
import XCTest

final class WebPageContentRulesTests: XCTestCase {
    @MainActor
    func testRulesCompile() async throws {
        _ = try await WebPageContentRules.ruleList()
    }

    func testBlocksThirdPartyLoadsThenAllowsCloudflaresChallenge() throws {
        let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(WebPageContentRules.json.utf8)) as? [[String: [String: Any]]])

        XCTAssertEqual(rules.count, 4)
        XCTAssertEqual(rules[0]["trigger"]?["load-type"] as? [String], ["third-party"])
        XCTAssertEqual(rules[0]["action"]?["type"] as? String, "block")
        XCTAssertEqual(rules[1]["trigger"]?["url-filter"] as? String, #"^https://challenges\.cloudflare\.com/"#)
        XCTAssertEqual(rules[1]["action"]?["type"] as? String, "ignore-previous-rules")
        XCTAssertEqual(rules[2]["trigger"]?["url-filter"] as? String, #"^blob:https://challenges\.cloudflare\.com/"#)
        XCTAssertEqual(rules[2]["action"]?["type"] as? String, "ignore-previous-rules")
        XCTAssertEqual(rules[3]["trigger"]?["resource-type"] as? [String], ["image", "media", "font"])
        XCTAssertEqual(rules[3]["action"]?["type"] as? String, "block")
    }
}
