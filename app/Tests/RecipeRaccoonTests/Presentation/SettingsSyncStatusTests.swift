@testable import RecipeRaccoon
import SwiftUI
import ViewInspector
import XCTest

/// The sync status under the storage picker (#208).
@MainActor
final class SettingsSyncStatusTests: XCTestCase {
    private func makeViewModel(mode: StorageMode, status: ICloudSyncStatus) -> SettingsViewModel {
        let useCase = StubStorageModeUseCase()
        useCase.currentMode = mode
        let provider = StubSyncStatusProvider()
        provider.status = status
        return SettingsViewModel(changeStorageModeUseCase: useCase, isICloudAvailableInBuild: true, syncStatusProvider: provider)
    }

    // MARK: - View model

    func testNoStatusWhileLocal() {
        XCTAssertNil(makeViewModel(mode: .local, status: .failed(.stopped, details: "x")).syncStatus)
    }

    func testTheProvidersStatusWhileICloud() {
        let date = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(makeViewModel(mode: .iCloud, status: .synced(date)).syncStatus, .synced(date))
    }

    func testNoStatusWithoutAProvider() {
        let useCase = StubStorageModeUseCase()
        useCase.currentMode = .iCloud

        XCTAssertNil(SettingsViewModel(changeStorageModeUseCase: useCase, isICloudAvailableInBuild: true).syncStatus)
    }

    func testFailureMessages() {
        XCTAssertEqual(
            ICloudSyncFailure.storageFull.message,
            "iCloud storage is full, so recipes can't sync. Free up space in iCloud, or switch to “On This Device”."
        )
        XCTAssertEqual(
            ICloudSyncFailure.notSignedIn.message,
            "Not signed in to iCloud, so recipes can't sync. Sign in on this device, or switch to “On This Device”."
        )
        XCTAssertEqual(ICloudSyncFailure.temporary.message, "Waiting for a connection to iCloud. Recipes sync once it's back.")
        XCTAssertEqual(
            ICloudSyncFailure.stopped.message,
            "Sync stopped. Close Recipe Raccoon completely and open it again. If it keeps happening, copy the error details and report it."
        )
    }

    func testOnlyATemporaryFailureIsNotAnError() {
        XCTAssertFalse(ICloudSyncFailure.temporary.isError)
        for failure in [ICloudSyncFailure.storageFull, .notSignedIn, .stopped] {
            XCTAssertTrue(failure.isError, "\(failure)")
        }
    }

    // MARK: - View

    func testWaitingShowsTheFirstSyncText() throws {
        let sut = SettingsView(viewModel: makeViewModel(mode: .iCloud, status: .waiting))

        XCTAssertNoThrow(try sut.inspect().find(text: "Waiting for the first sync…"))
    }

    func testAnErrorShowsItsMessageAndCopiesItsDetails() throws {
        let sut = SettingsView(viewModel: makeViewModel(mode: .iCloud, status: .failed(.storageFull, details: "CKErrorDomain 25")))

        XCTAssertNoThrow(try sut.inspect().find(text: ICloudSyncFailure.storageFull.message))
        try sut.inspect().find(button: "Copy Error Details").tap()

        XCTAssertEqual(Self.pasteboardString(), "CKErrorDomain 25")
    }

    func testATemporaryFailureOffersNoCopy() {
        let sut = SettingsView(viewModel: makeViewModel(mode: .iCloud, status: .failed(.temporary, details: "offline")))

        XCTAssertNoThrow(try sut.inspect().find(text: ICloudSyncFailure.temporary.message))
        XCTAssertThrowsError(try sut.inspect().find(button: "Copy Error Details"))
    }

    func testLocalShowsNoSyncStatus() {
        let sut = SettingsView(viewModel: makeViewModel(mode: .local, status: .waiting))

        XCTAssertThrowsError(try sut.inspect().find(text: "Waiting for the first sync…"))
    }

    private static func pasteboardString() -> String? {
        #if os(macOS)
        NSPasteboard.general.string(forType: .string)
        #else
        UIPasteboard.general.string
        #endif
    }
}

@MainActor
private final class StubStorageModeUseCase: ChangeStorageModeUseCase {
    var currentMode: StorageMode = .local

    func execute(_: StorageMode) async throws { /* no-op: these tests don't switch storage */ }
}

@MainActor
private final class StubSyncStatusProvider: ICloudSyncStatusProvider {
    var status: ICloudSyncStatus = .waiting
}
