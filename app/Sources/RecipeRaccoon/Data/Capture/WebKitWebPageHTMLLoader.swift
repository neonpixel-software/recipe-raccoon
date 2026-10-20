import WebKit

/// Loads a page in a hidden web view, for sites whose bot check turns URLSession away
/// (issue #225). The check is JavaScript, for example Kinsta's redirect and then Cloudflare's
/// "Just a moment…" challenge, and a web view runs it and passes by itself: about 4 s on the dev
/// Mac. The view keeps no cookies or storage between loads, and WebPageContentRules keeps it from
/// loading anything from other sites, so as with URLSession only the recipe's site sees the visit.
///
/// Not unit tested, like URLSessionWebPageHTMLLoader: it needs a real page behind a real bot
/// check. Its content rules and the status check it reuses (WebPageTextDecoding) are tested.
@MainActor
final class WebKitWebPageHTMLLoader: WebPageHTMLLoader {
    private let timeout: Duration

    /// `timeout` covers the whole load, bot check included. Measured on miljuschka.nl: 4–7 s, and
    /// 17.6 s for the first load after the iOS simulator started, so 30 s leaves room.
    init(timeout: Duration = .seconds(30)) {
        self.timeout = timeout
    }

    func html(from url: URL) async throws -> String {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        try await configuration.userContentController.add(WebPageContentRules.ruleList())
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let waiter = PageLoadWaiter(siteHost: url.host())
        webView.navigationDelegate = waiter
        defer { webView.stopLoading() }

        webView.load(URLRequest(url: url))
        try await waiter.waitForPage(timeout: timeout)

        guard let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String,
              !html.isEmpty else {
            throw WebPageFetchError.emptyContent
        }
        if html.utf8.count > WebPageTextDecoding.maxDownloadBytes {
            throw WebPageFetchError.tooLarge
        }
        return html
    }
}

/// Waits for the web view to finish a page that isn't an error page. A bot check's page has an
/// error status and moves on by itself, so it's skipped; one that never moves on runs into the
/// timeout and counts as blocked. Navigation is limited by WebPageNavigationPolicy.
@MainActor
private final class PageLoadWaiter: NSObject, WKNavigationDelegate {
    private let siteHost: String?
    private var continuation: CheckedContinuation<Void, Error>?
    private var isErrorPage = false

    init(siteHost: String?) {
        self.siteHost = siteHost
    }

    func waitForPage(timeout: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.finish(.failure(WebPageFetchError.blockedByBotCheck))
            }
        }
    }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        return WebPageNavigationPolicy.allows(navigationAction.request.url, isMainFrame: isMainFrame, siteHost: siteHost) ? .allow : .cancel
    }

    func webView(_: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard WebPageNavigationPolicy.allows(
            navigationResponse.response.url,
            isMainFrame: navigationResponse.isForMainFrame,
            siteHost: siteHost
        ) else {
            return .cancel
        }
        if navigationResponse.isForMainFrame {
            isErrorPage = (try? WebPageTextDecoding.validateStatus(of: navigationResponse.response)) == nil
        }
        return .allow
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        guard !isErrorPage else { return }
        finish(.success(()))
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        failed(with: error)
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        failed(with: error)
    }

    private func failed(with error: Error) {
        // The bot check's redirect cancels the page it replaces; the next page is still coming.
        let nsError = error as NSError
        guard nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled else { return }
        finish(.failure(WebPageFetchError.requestFailed(underlying: error)))
    }

    private func finish(_ result: Result<Void, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
