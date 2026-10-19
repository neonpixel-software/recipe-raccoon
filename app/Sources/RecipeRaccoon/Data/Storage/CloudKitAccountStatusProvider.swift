import CloudKit
import Foundation

/// Also the reason the app links CloudKit directly. On 2026-09-30 a sandboxed Mac test app using
/// only SwiftData's CloudKit sync (which loads CloudKit on demand) was denied the CloudKit daemon
/// by the sandbox (`deny mach-lookup com.apple.cloudd`), and syncing started working as soon as it
/// linked CloudKit. Keep a direct CloudKit reference if this type is ever removed.
struct CloudKitAccountStatusProvider: ICloudAccountStatusProvider {
    let isEnabledInBuild: Bool

    func status() async -> ICloudAccountStatus {
        guard isEnabledInBuild else { return .notConfiguredInBuild }

        do {
            let status = try await CKContainer(identifier: RecipeStore.cloudKitContainerIdentifier).accountStatus()
            return Self.map(status)
        } catch {
            Log.data.failure("Checking the iCloud account failed", error)
            return .couldNotDetermine
        }
    }

    static func map(_ status: CKAccountStatus) -> ICloudAccountStatus {
        switch status {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .couldNotDetermine: .couldNotDetermine
        @unknown default: .couldNotDetermine
        }
    }
}
