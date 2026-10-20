#if DEBUG
import Foundation

/// Suggests no tags, so previews and the UI test scenarios (whose capture is
/// PreviewRecipeCaptureService) open the review screen as before.
struct PreviewTagSuggestionService: TagSuggestionService {
    func suggestTags(title _: String, ingredients _: [String], from _: [String]) async throws -> [String] {
        []
    }
}
#endif
