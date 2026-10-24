import Foundation

/// Reports how iCloud sync is going this session (#208). Implementations are observable, so a
/// view reading `status` updates when it changes.
@MainActor
protocol ICloudSyncStatusProvider: AnyObject {
    var status: ICloudSyncStatus { get }
}
