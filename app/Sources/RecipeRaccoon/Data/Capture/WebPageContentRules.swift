import WebKit

/// What WebKitWebPageHTMLLoader's web view may load: nothing from other sites, so ads and
/// trackers never see the visit, except Cloudflare's bot check, whose script and `blob:` worker
/// come from challenges.cloudflare.com (the check fails without either). No images, media or
/// fonts either, since only the HTML is read.
enum WebPageContentRules {
    /// Bump the version when the rules change: WebKit keeps compiled lists by identifier.
    static let identifier = "WebPageContentRules-1"

    static let json = #"""
    [
      {"trigger": {"url-filter": ".*", "load-type": ["third-party"]}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^https://challenges\\.cloudflare\\.com/"}, "action": {"type": "ignore-previous-rules"}},
      {"trigger": {"url-filter": "^blob:https://challenges\\.cloudflare\\.com/"}, "action": {"type": "ignore-previous-rules"}},
      {"trigger": {"url-filter": ".*", "resource-type": ["image", "media", "font"]}, "action": {"type": "block"}}
    ]
    """#

    @MainActor
    static func ruleList() async throws -> WKContentRuleList {
        guard let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: json
        ) else {
            // Never load the page without the rules; the user can still copy the recipe in.
            throw WebPageFetchError.blockedByBotCheck
        }
        return ruleList
    }
}
