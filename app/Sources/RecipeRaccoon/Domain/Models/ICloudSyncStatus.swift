import Foundation

/// One finished round of CloudKit mirroring: setting up, importing other devices' changes, or
/// exporting this device's (#208).
struct ICloudSyncEvent: Equatable {
    enum Kind: Equatable, CaseIterable {
        case setup
        case `import`
        case export
    }

    let kind: Kind
    let endDate: Date
    /// Nil when the event succeeded.
    let failure: ICloudSyncFailure?
    /// The raw error, for an issue report. Nil when the event succeeded.
    let errorDetails: String?

    var succeeded: Bool {
        failure == nil
    }
}

/// Why sync isn't working, in terms the user can act on.
enum ICloudSyncFailure: Equatable {
    /// The user's iCloud storage is full, so nothing more can upload.
    case storageFull
    /// No iCloud account on the device, or it signed out.
    case notSignedIn
    /// Offline or CloudKit is busy. CloudKit retries by itself.
    case temporary
    /// Anything else, such as a schema the server rejects (#207). Mirroring stays stopped
    /// until the app restarts, since the container can't be reopened in-process.
    case stopped
}

/// What Settings shows about sync while storage is iCloud.
enum ICloudSyncStatus: Equatable {
    /// No sync event has finished yet this session.
    case waiting
    case synced(Date)
    case failed(ICloudSyncFailure, details: String)

    /// The status the latest event of each kind adds up to: the most recent failure while any
    /// kind's latest event failed (a later success of the same kind clears it), otherwise the
    /// most recent success. Only the latest event of each kind counts, and a failure that needs
    /// the user wins over a temporary one, so going offline doesn't hide a stopped sync.
    init(latestEvents events: [ICloudSyncEvent]) {
        let latestPerKind = Dictionary(events.map { ($0.kind, $0) }) { $0.endDate >= $1.endDate ? $0 : $1 }
        let byDate = latestPerKind.values.sorted { $0.endDate > $1.endDate }
        let failures = byDate.filter { !$0.succeeded }
        let shown = failures.first { $0.failure != .temporary } ?? failures.first
        if let failed = shown, let failure = failed.failure {
            self = .failed(failure, details: failed.errorDetails ?? "")
        } else if let latest = byDate.first {
            self = .synced(latest.endDate)
        } else {
            self = .waiting
        }
    }
}
