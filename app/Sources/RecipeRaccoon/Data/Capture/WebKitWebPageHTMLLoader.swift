import WebKit

/// Loads a page in a hidden web view, for sites whose bot check turns URLSession away
/// (issue #225). The check is JavaScript, for example Kinsta's redirect and then Cloudflare's
/// "Just a moment…" challenge, and a web view runs it and passes by itself: 2–4 s on the dev
/// Mac. The view keeps no cookies or storage between loads, and WebPageContentRules keeps it from
/// loading anything from other sites, so as with URLSession only the recipe's site sees the visit.
///
/// Not unit tested, like URLSessionWebPageHTMLLoader: it needs a real page behind a real bot
/// check. Its content rules and the status check it reuses (WebPageTextDecoding) are tested.
@MainActor
final class WebKitWebPageHTMLLoader: WebPageHTMLLoader {
    private let timeout: Duration
    private let errorPageGrace: Duration

    /// `timeout` covers the whole load, bot check included. Measured on miljuschka.nl: 4–7 s, and
    /// 17.6 s for the first load after the iOS simulator started, so 30 s leaves room.
    ///
    /// `errorPageGrace` is how long an error page may sit before anything navigates. A bot check
    /// starts within 0.4 s of its page finishing (Kinsta's redirect at once, Cloudflare's challenge
    /// frame 0.1 s later, also on a cold iOS simulator); a plain 403 or 429 never does, so it
    /// fails after this rather than the whole timeout.
    init(timeout: Duration = .seconds(30), errorPageGrace: Duration = .seconds(5)) {
        self.timeout = timeout
        self.errorPageGrace = errorPageGrace
    }

    func html(from url: URL) async throws -> String {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        try await configuration.userContentController.add(WebPageContentRules.ruleList())
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let waiter = PageLoadWaiter(siteHost: url.host(), errorPageGrace: errorPageGrace)
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
/// error status and moves on by itself, so it's skipped. An error page that nothing follows
/// within the grace period, or a bot check that doesn't pass before the timeout, counts as
/// blocked. Navigation is limited by WebPageNavigationPolicy, in the decision-handler forms of
/// the policy methods rather than the async ones: SonarCloud's S7485 check only recognizes those.
@MainActor
private final class PageLoadWaiter: NSObject, WKNavigationDelegate {
    private let siteHost: String?
    private let errorPageGrace: Duration
    private var continuation: CheckedContinuation<Void, Error>?
    private var isErrorPage = false
    private var timeoutTask: Task<Void, Never>?
    private var errorPageTask: Task<Void, Never>?

    init(siteHost: String?, errorPageGrace: Duration) {
        self.siteHost = siteHost
        self.errorPageGrace = errorPageGrace
    }

    func waitForPage(timeout: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            timeoutTask = blockedAfter(timeout)
        }
    }

    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        errorPageTask?.cancel()
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let isAllowed = WebPageNavigationPolicy.allows(navigationAction.request.url, isMainFrame: isMainFrame, siteHost: siteHost)
        decisionHandler(isAllowed ? .allow : .cancel)
    }

    func webView(
        _: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        guard WebPageNavigationPolicy.allows(
            navigationResponse.response.url,
            isMainFrame: navigationResponse.isForMainFrame,
            siteHost: siteHost
        ) else {
            decisionHandler(.cancel)
            return
        }
        if navigationResponse.isForMainFrame {
            isErrorPage = (try? WebPageTextDecoding.validateStatus(of: navigationResponse.response)) == nil
        }
        decisionHandler(.allow)
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        guard !isErrorPage else {
            errorPageTask = blockedAfter(errorPageGrace)
            return
        }
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

    private func blockedAfter(_ delay: Duration) -> Task<Void, Never> {
        Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return // Cancelled: the page loaded, or something navigated.
            }
            self?.finish(.failure(WebPageFetchError.blockedByBotCheck))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        timeoutTask?.cancel()
        errorPageTask?.cancel()
        continuation?.resume(with: result)
        continuation = nil
    }
}
