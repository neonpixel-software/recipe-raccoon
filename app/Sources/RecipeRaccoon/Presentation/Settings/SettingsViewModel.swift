import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private(set) var storageMode: StorageMode
    private(set) var isSwitching = false
    private(set) var errorMessage: String?
    /// False in a build without the iCloud entitlement (CI, a clone without Signing.xcconfig).
    let isICloudAvailableInBuild: Bool

    private(set) var lastDensityRefresh: Date?
    private(set) var isRefreshingDensities = false
    private(set) var densityStatus: DensityRefreshStatus?

    private let changeStorageModeUseCase: ChangeStorageModeUseCase
    /// Nil in a build without the density API configuration (DensityAPI.xcconfig).
    private let refreshDensityCacheUseCase: RefreshDensityCacheUseCase?
    /// Nil in a build without the iCloud entitlement, and in UI test scenarios.
    private let syncStatusProvider: ICloudSyncStatusProvider?

    init(
        changeStorageModeUseCase: ChangeStorageModeUseCase,
        isICloudAvailableInBuild: Bool,
        refreshDensityCacheUseCase: RefreshDensityCacheUseCase? = nil,
        syncStatusProvider: ICloudSyncStatusProvider? = nil
    ) {
        self.changeStorageModeUseCase = changeStorageModeUseCase
        self.isICloudAvailableInBuild = isICloudAvailableInBuild
        self.refreshDensityCacheUseCase = refreshDensityCacheUseCase
        self.syncStatusProvider = syncStatusProvider
        storageMode = changeStorageModeUseCase.currentMode
        lastDensityRefresh = refreshDensityCacheUseCase?.lastRefresh
    }

    var isDensityAPIAvailableInBuild: Bool {
        refreshDensityCacheUseCase != nil
    }

    var canRefreshDensities: Bool {
        isDensityAPIAvailableInBuild && !isRefreshingDensities
    }

    /// Picks up a refresh that ran in the background since the screen was built.
    func reloadDensityStatus() {
        lastDensityRefresh = refreshDensityCacheUseCase?.lastRefresh
    }

    func refreshDensities() async {
        guard let refreshDensityCacheUseCase, !isRefreshingDensities else { return }

        isRefreshingDensities = true
        defer { isRefreshingDensities = false }

        do {
            let changes = try await refreshDensityCacheUseCase.execute()
            densityStatus = changes.isEmpty ? .upToDate : .updated
        } catch {
            Log.presentation.failure("Refreshing ingredient densities failed", error)
            densityStatus = .failed(DensityRefreshFailure(error))
        }
        lastDensityRefresh = refreshDensityCacheUseCase.lastRefresh
    }

    /// How sync is going, while recipes are stored in iCloud (#208). Nil in Local mode.
    var syncStatus: ICloudSyncStatus? {
        guard storageMode == .iCloud else { return nil }
        return syncStatusProvider?.status
    }

    var canChangeStorage: Bool {
        isICloudAvailableInBuild && !isSwitching
    }

    func selectStorageMode(_ mode: StorageMode) async {
        guard mode != storageMode, !isSwitching else { return }

        isSwitching = true
        defer { isSwitching = false }

        do {
            try await changeStorageModeUseCase.execute(mode)
            storageMode = mode
            errorMessage = nil
        } catch let StorageModeError.iCloudUnavailable(status) {
            errorMessage = Self.message(for: status)
        } catch {
            Log.presentation.failure("Switching storage mode failed", error)
            errorMessage = String(localized: "Couldn't change where recipes are stored. Try again.")
        }
    }

    private static func message(for status: ICloudAccountStatus) -> String {
        switch status {
        case .noAccount:
            String(localized: "Sign in to iCloud on this device to sync your recipes.")
        case .restricted:
            String(localized: "iCloud is restricted on this device, so recipes can't sync.")
        case .temporarilyUnavailable:
            String(localized: "iCloud is temporarily unavailable. Try again in a moment.")
        case .notConfiguredInBuild:
            String(localized: "iCloud sync isn't available in this build.")
        case .available, .couldNotDetermine:
            String(localized: "Couldn't reach iCloud. Check your connection and try again.")
        }
    }
}

extension ICloudSyncFailure {
    var message: String {
        switch self {
        case .storageFull:
            String(localized: "iCloud storage is full, so recipes can't sync. Free up space in iCloud, or switch to “On This Device”.")
        case .notSignedIn:
            String(localized: "Not signed in to iCloud, so recipes can't sync. Sign in on this device, or switch to “On This Device”.")
        case .temporary:
            String(localized: "Waiting for a connection to iCloud. Recipes sync once it's back.")
        case .stopped:
            String(localized: "Sync stopped. Close Recipe Raccoon completely and open it again. If it keeps happening, copy the error details and report it.")
        }
    }

    /// A temporary failure fixes itself, so it isn't shown as an error.
    var isError: Bool {
        self != .temporary
    }
}

/// The outcome of the last "Refresh Now" in Settings.
enum DensityRefreshStatus: Equatable {
    case upToDate
    case updated
    case failed(DensityRefreshFailure)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .upToDate:
            String(localized: "Ingredient densities are up to date.")
        case .updated:
            String(localized: "Ingredient densities updated.")
        case let .failed(failure):
            failure.message
        }
    }
}

/// Why a refresh failed, in terms the user can act on.
enum DensityRefreshFailure: Equatable {
    /// The request never got an answer: offline, DNS, TLS, timeout.
    case connection
    /// The API turned the read key down (401/403). Only a new app version can fix that.
    case rejected
    /// The API answered, but not with entries: a server error, rate limiting, a bad body.
    case serviceUnavailable
    /// The download worked but the cache couldn't be saved.
    case couldNotSave

    init(_ error: Error) {
        switch error {
        case DensityEntryFetchError.requestFailed:
            self = .connection
        case let DensityEntryFetchError.httpStatus(status) where status == 401 || status == 403:
            self = .rejected
        case DensityEntryFetchError.httpStatus, DensityEntryFetchError.invalidResponse:
            self = .serviceUnavailable
        default:
            self = .couldNotSave
        }
    }

    var message: String {
        switch self {
        case .connection:
            String(localized: "Couldn't refresh ingredient densities. Check your connection and try again.")
        case .rejected:
            String(localized: "The ingredient density service didn't accept this version of Recipe Raccoon. Update the app and try again.")
        case .serviceUnavailable:
            String(localized: "The ingredient density service isn't responding properly right now. Try again later.")
        case .couldNotSave:
            String(localized: "Couldn't save ingredient densities on this device. Try again.")
        }
    }
}
