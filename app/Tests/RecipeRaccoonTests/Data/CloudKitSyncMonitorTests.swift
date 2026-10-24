import CloudKit
import CoreData
@testable import RecipeRaccoon
import XCTest

/// Stands in for `NSPersistentCloudKitContainer.Event`, which has no public initializer.
private struct FakeSyncEvent: CloudKitSyncEventDescribing {
    var type: NSPersistentCloudKitContainer.EventType = .export
    var endDate: Date? = Date(timeIntervalSince1970: 1_000_000)
    var succeeded = true
    var error: (any Error)?
}

@MainActor
final class CloudKitSyncMonitorTests: XCTestCase {
    private let notificationCenter = NotificationCenter()

    private func post(_ event: FakeSyncEvent) {
        notificationCenter.post(
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            userInfo: [NSPersistentCloudKitContainer.eventNotificationUserInfoKey: event]
        )
    }

    private func waitForStatus(of monitor: CloudKitSyncMonitor, _ isExpected: @escaping (ICloudSyncStatus) -> Bool) {
        let changed = expectation(for: NSPredicate { _, _ in MainActor.assumeIsolated { isExpected(monitor.status) } }, evaluatedWith: nil)
        wait(for: [changed], timeout: 2)
    }

    private func ckError(_ code: CKError.Code, userInfo: [String: Any] = [:]) -> NSError {
        NSError(domain: CKError.errorDomain, code: code.rawValue, userInfo: userInfo)
    }

    // MARK: - Notifications

    func testStartsWaiting() {
        XCTAssertEqual(CloudKitSyncMonitor(notificationCenter: notificationCenter).status, .waiting)
    }

    func testAFailedExportShowsAnError() {
        let monitor = CloudKitSyncMonitor(notificationCenter: notificationCenter)

        post(FakeSyncEvent(type: .export, succeeded: false, error: ckError(.quotaExceeded)))

        waitForStatus(of: monitor) {
            if case .failed(.storageFull, _) = $0 { return true }
            return false
        }
    }

    func testALaterSuccessOfTheSameKindClearsTheError() {
        let monitor = CloudKitSyncMonitor(notificationCenter: notificationCenter)
        post(FakeSyncEvent(type: .export, succeeded: false, error: ckError(.networkUnavailable)))
        waitForStatus(of: monitor) { $0 != .waiting }

        let later = Date(timeIntervalSince1970: 2_000_000)
        post(FakeSyncEvent(type: .export, endDate: later))

        waitForStatus(of: monitor) { $0 == .synced(later) }
    }

    func testARunningEventAndOtherNotificationsChangeNothing() {
        let monitor = CloudKitSyncMonitor(notificationCenter: notificationCenter)

        post(FakeSyncEvent(endDate: nil))
        notificationCenter.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, userInfo: ["other": 1])

        // Let the main queue run the observer's blocks.
        let settled = expectation(description: "settled")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.2)
        XCTAssertEqual(monitor.status, .waiting)
    }

    // MARK: - Events

    func testSyncEventKinds() {
        XCTAssertEqual(CloudKitSyncMonitor.syncEvent(from: FakeSyncEvent(type: .setup))?.kind, .setup)
        XCTAssertEqual(CloudKitSyncMonitor.syncEvent(from: FakeSyncEvent(type: .import))?.kind, .import)
        XCTAssertEqual(CloudKitSyncMonitor.syncEvent(from: FakeSyncEvent(type: .export))?.kind, .export)
    }

    func testASucceededEventHasNoFailure() throws {
        let event = try XCTUnwrap(CloudKitSyncMonitor.syncEvent(from: FakeSyncEvent()))

        XCTAssertNil(event.failure)
        XCTAssertNil(event.errorDetails)
    }

    func testAFailedEventKeepsTheRawErrorForAReport() throws {
        let error = ckError(.serverRejectedRequest)
        let event = try XCTUnwrap(CloudKitSyncMonitor.syncEvent(from: FakeSyncEvent(succeeded: false, error: error)))

        XCTAssertEqual(event.failure, .stopped)
        XCTAssertEqual(event.errorDetails, String(describing: error))
    }

    func testAFailedEventWithoutAnErrorCountsAsStopped() throws {
        let event = try XCTUnwrap(CloudKitSyncMonitor.syncEvent(from: FakeSyncEvent(succeeded: false)))

        XCTAssertEqual(event.failure, .stopped)
        XCTAssertNotNil(event.errorDetails)
    }

    // MARK: - Classifying errors

    func testCloudKitErrors() {
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: ckError(.quotaExceeded)), .storageFull)
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: ckError(.notAuthenticated)), .notSignedIn)
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: ckError(.accountTemporarilyUnavailable)), .notSignedIn)
        for code in [CKError.Code.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy] {
            XCTAssertEqual(CloudKitSyncMonitor.failure(for: ckError(code)), .temporary, "\(code)")
        }
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: ckError(.serverRejectedRequest)), .stopped)
    }

    func testCoreDataNoAccountError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: CloudKitSyncMonitor.noAccountCoreDataCode)

        XCTAssertEqual(CloudKitSyncMonitor.failure(for: error), .notSignedIn)
    }

    func testAnUnknownErrorCountsAsStopped() {
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: NSError(domain: NSCocoaErrorDomain, code: 134_060)), .stopped)
    }

    /// The #207 case: a batch rejected because one record had a field production lacked.
    func testAPartialFailureIsClassifiedByItsRecordErrors() {
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: partialFailure(["photo": .invalidArguments, "recipe": .batchRequestFailed])), .stopped)
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: partialFailure(["photo": .quotaExceeded, "recipe": .batchRequestFailed])), .storageFull)
        XCTAssertEqual(CloudKitSyncMonitor.failure(for: partialFailure(["recipe": .networkFailure])), .temporary)
    }

    private func partialFailure(_ codes: [String: CKError.Code]) -> NSError {
        ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: codes.mapValues { ckError($0) }])
    }

    func testAWrappedCloudKitErrorIsFound() {
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_419, userInfo: [NSUnderlyingErrorKey: ckError(.quotaExceeded)])

        XCTAssertEqual(CloudKitSyncMonitor.failure(for: wrapped), .storageFull)
    }
}
