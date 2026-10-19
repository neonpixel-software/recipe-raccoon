import Foundation
import os

/// Loggers for the app's error paths, one per layer, so failures reach the unified log
/// (Console, sysdiagnose) in TestFlight and App Store builds. `print()` output only shows under
/// the Xcode debugger: on a normal launch it's discarded (#214). The logs stay on the device.
enum Log {
    /// The app's bundle identifier, the same on iOS and macOS (project.yml).
    private static let subsystem = "com.neonpixel.reciperaccoon"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let domain = Logger(subsystem: subsystem, category: "domain")
    static let presentation = Logger(subsystem: subsystem, category: "presentation")
}

extension Logger {
    /// Logs that `what` failed: `what` and the error's `logSummary` in the clear, its
    /// description private ("Failed to seed preset tags: NSCocoaErrorDomain 134030 <private>").
    func failure(_ what: String, _ error: any Error) {
        self.error("\(what, privacy: .public): \(error.logSummary, privacy: .public) \(error.localizedDescription)")
    }

    /// Runs `body` and returns its result, or logs the failure and returns nil when it throws:
    /// for failures that only need logging.
    @discardableResult
    func attempt<T>(_ what: String, _ body: () throws -> T) -> T? {
        do {
            return try body()
        } catch {
            failure(what, error)
            return nil
        }
    }
}

extension Error {
    /// The error's domain and code ("NSCocoaErrorDomain 134030"), which never hold user content,
    /// so they can be logged `.public` and read in a user's sysdiagnose. The description can quote
    /// a URL or recipe text and stays private. A Swift error's domain is its type
    /// ("RecipeRaccoon.WebPageFetchError 4" is `.tooLarge`), and its code the case's position,
    /// counting the cases with associated values first. Keep it that way: an error type of our
    /// own must not put user content in a custom domain.
    var logSummary: String {
        let nsError = self as NSError
        return "\(nsError.domain) \(nsError.code)"
    }
}
