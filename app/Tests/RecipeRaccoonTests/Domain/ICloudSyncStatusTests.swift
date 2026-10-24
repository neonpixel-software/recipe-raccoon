@testable import RecipeRaccoon
import XCTest

final class ICloudSyncStatusTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func event(_ kind: ICloudSyncEvent.Kind, at seconds: TimeInterval, failure: ICloudSyncFailure? = nil) -> ICloudSyncEvent {
        ICloudSyncEvent(
            kind: kind,
            endDate: start.addingTimeInterval(seconds),
            failure: failure,
            errorDetails: failure.map { "details \($0)" }
        )
    }

    func testNoEventsIsWaiting() {
        XCTAssertEqual(ICloudSyncStatus(latestEvents: []), .waiting)
    }

    func testSuccessesGiveTheMostRecentSyncTime() {
        let status = ICloudSyncStatus(latestEvents: [event(.setup, at: 0), event(.export, at: 20), event(.import, at: 10)])

        XCTAssertEqual(status, .synced(start.addingTimeInterval(20)))
    }

    func testAFailureWinsOverALaterSuccessOfAnotherKind() {
        let status = ICloudSyncStatus(latestEvents: [event(.export, at: 10, failure: .storageFull), event(.import, at: 20)])

        XCTAssertEqual(status, .failed(.storageFull, details: "details storageFull"))
    }

    func testTheMostRecentFailureIsShown() {
        let status = ICloudSyncStatus(latestEvents: [
            event(.setup, at: 5, failure: .stopped),
            event(.export, at: 10, failure: .notSignedIn),
        ])

        XCTAssertEqual(status, .failed(.notSignedIn, details: "details notSignedIn"))
    }

    func testAnEventSucceedsWithoutAFailure() {
        XCTAssertTrue(event(.import, at: 0).succeeded)
        XCTAssertFalse(event(.import, at: 0, failure: .temporary).succeeded)
    }
}
