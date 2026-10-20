import Foundation

/// Where WebKitWebPageHTMLLoader's web view may navigate: the page stays on the pasted link's
/// site, where a bot check's redirects stay too (Kinsta's goes to `?ki-cf-botcl=1`), and only
/// Cloudflare's challenge may open in a frame from elsewhere. Anything else, such as an ad's
/// frame or a redirect to another site, is cancelled.
enum WebPageNavigationPolicy {
    static let challengeHost = "challenges.cloudflare.com"

    static func allows(_ url: URL?, isMainFrame: Bool, siteHost: String?) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased() else { return false }
        // A frame the page writes itself (about:blank, about:srcdoc) loads nothing from elsewhere.
        if scheme == "about" { return !isMainFrame }
        guard scheme == "https", let host = url.host()?.lowercased() else { return false }
        if let siteHost, withoutWWW(host) == withoutWWW(siteHost.lowercased()) { return true }
        return !isMainFrame && host == challengeHost
    }

    /// example.com and www.example.com are the same site; sites redirect from one to the other.
    private static func withoutWWW(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
