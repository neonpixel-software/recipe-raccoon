import CloudKit
import CoreData
import Foundation
import Observation

/// The parts of a mirroring event the monitor reads. `NSPersistentCloudKitContainer.Event` has
/// no public initializer, so tests post their own type under the same user info key.
protocol CloudKitSyncEventDescribing {
    var type: NSPersistentCloudKitContainer.EventType { get }
    var endDate: Date? { get }
    var succeeded: Bool { get }
    var error: (any Error)? { get }
}

extension NSPersistentCloudKitContainer.Event: CloudKitSyncEventDescribing {}

/// Follows CloudKit mirroring through `eventChangedNotification`, which SwiftData's CloudKit
/// store still posts, and keeps the latest finished event of each kind (#208). Only the iCloud
/// container posts these, so the Local store never changes the status. Create it before the
/// store opens, or the setup event is missed.
@Observable
@MainActor
final class CloudKitSyncMonitor: ICloudSyncStatusProvider {
    private(set) var status: ICloudSyncStatus = .waiting

    @ObservationIgnored private var latestEvents: [ICloudSyncEvent.Kind: ICloudSyncEvent] = [:]
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init(notificationCenter: NotificationCenter = .default) {
        observer = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? any CloudKitSyncEventDescribing
            let syncEvent = event.flatMap(Self.syncEvent(from:))
            MainActor.assumeIsolated {
                guard let syncEvent else { return }
                self?.record(syncEvent)
            }
        }
    }

    func record(_ event: ICloudSyncEvent) {
        latestEvents[event.kind] = event
        status = ICloudSyncStatus(latestEvents: Array(latestEvents.values))
    }

    /// Nil while the event is still running: it's posted again when it ends.
    nonisolated static func syncEvent(from event: any CloudKitSyncEventDescribing) -> ICloudSyncEvent? {
        guard let endDate = event.endDate, let kind = kind(of: event.type) else { return nil }
        guard !event.succeeded else {
            return ICloudSyncEvent(kind: kind, endDate: endDate, failure: nil, errorDetails: nil)
        }
        let error = event.error
        if let error {
            Log.data.failure("iCloud \(kind) failed", error)
        }
        return ICloudSyncEvent(
            kind: kind,
            endDate: endDate,
            failure: error.map(failure(for:)) ?? .stopped,
            errorDetails: error.map { String(describing: $0) } ?? "The sync event failed without an error."
        )
    }

    private nonisolated static func kind(of type: NSPersistentCloudKitContainer.EventType) -> ICloudSyncEvent.Kind? {
        switch type {
        case .setup: .setup
        case .import: .import
        case .export: .export
        @unknown default: nil
        }
    }

    /// Classifies an error by the most telling CloudKit error inside it: a partial failure
    /// holds one error per record, and Core Data wraps CloudKit's under NSUnderlyingErrorKey.
    nonisolated static func failure(for error: any Error) -> ICloudSyncFailure {
        let errors = flattened(error as NSError)
        for candidate in [ICloudSyncFailure.storageFull, .notSignedIn] where errors.contains(where: { classify($0) == candidate }) {
            return candidate
        }
        // Every inner error temporary, or no CloudKit error at all but a temporary one on top.
        let classified = errors.compactMap(classify)
        if !classified.isEmpty, classified.allSatisfy({ $0 == .temporary }) {
            return .temporary
        }
        return .stopped
    }

    /// Unavailable when the device has no iCloud account (CKAccountStatusNoAccount).
    nonisolated static let noAccountCoreDataCode = 134_400

    private nonisolated static func classify(_ error: NSError) -> ICloudSyncFailure? {
        if error.domain == NSCocoaErrorDomain, error.code == noAccountCoreDataCode {
            return .notSignedIn
        }
        guard error.domain == CKError.errorDomain else { return nil }
        switch CKError.Code(rawValue: error.code) {
        case .quotaExceeded:
            return .storageFull
        // Temporarily unavailable: the account needs the user to sign in again in Settings.
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .notSignedIn
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .temporary
        // A record that failed only because another one in its batch did says nothing itself.
        case .partialFailure, .batchRequestFailed:
            return nil
        default:
            return .stopped
        }
    }

    private nonisolated static func flattened(_ error: NSError) -> [NSError] {
        var inner: [NSError] = []
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            inner += flattened(underlying)
        }
        if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error] {
            inner += partial.values.flatMap { flattened($0 as NSError) }
        }
        return [error] + inner
    }
}
