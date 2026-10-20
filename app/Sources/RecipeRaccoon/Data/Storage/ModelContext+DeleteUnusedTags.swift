import Foundation
import SwiftData

extension ModelContext {
    /// Deletes the custom tags no recipe uses (#211), so a tag removed from its last recipe, a
    /// deleted recipe's tags or a typo'd tag leaves the filter bar. The preset tags always stay.
    ///
    /// Runs after the app's own saves and deletes, never after a CloudKit import: an import can
    /// bring a recipe whose tag hasn't arrived yet, and sweeping then would delete a tag another
    /// device still uses. A race remains when two devices edit before either syncs (one removes
    /// a tag's last use while the other adds it); the recipe then loses that tag, and typing it
    /// again brings it back.
    ///
    /// Saves only when it deleted something. Returns whether anything changed.
    @discardableResult
    func deleteUnusedTags() throws -> Bool {
        let unused = try fetch(FetchDescriptor<TagModel>()).filter { !$0.isPreset && ($0.recipes ?? []).isEmpty }
        guard !unused.isEmpty else { return false }
        for tag in unused {
            delete(tag)
        }
        try save()
        return true
    }
}
