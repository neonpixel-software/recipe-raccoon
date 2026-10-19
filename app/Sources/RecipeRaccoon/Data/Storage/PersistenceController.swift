import CoreData
import Foundation
import SwiftData

extension Notification.Name {
    /// Posted when the recipes behind the repositories changed outside the app's own edits:
    /// a storage switch, or a CloudKit import. Screens showing recipes reload on it.
    static let recipeStoreDidChange = Notification.Name("RecipeRaccoon.recipeStoreDidChange")
}

/// Hands repositories the current store's context. A storage switch swaps `context`,
/// so repositories and the view models holding them never need rebuilding.
final class ModelContextProvider {
    fileprivate(set) var context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }
}

/// Owns the recipe store for the current storage mode and switches between them.
@MainActor
final class PersistenceController: StorageModeSwitcher {
    typealias ContainerFactory = @MainActor (StorageMode) throws -> ModelContainer

    static let storageModeKey = "storageMode"

    let contextProvider: ModelContextProvider
    private(set) var currentMode: StorageMode

    /// One container per mode for the whole session. Opening the same CloudKit-backed store a
    /// second time in one process breaks mirroring, so a switch back reuses the old container
    /// instead of making a new one. (The iCloud container therefore keeps importing until the
    /// app quits, even after a switch to Local; local edits never reach it.)
    private var containers: [StorageMode: ModelContainer] = [:]
    private let makeContainer: ContainerFactory
    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let seedsSampleData: Bool
    private var remoteChangeObserver: (any NSObjectProtocol)?

    /// - Parameter isICloudEnabledInBuild: without the entitlement a stored `.iCloud`
    ///   preference is ignored, since opening a CloudKit-backed store would fail.
    init(
        defaults: UserDefaults = .standard,
        isICloudEnabledInBuild: Bool,
        seedsSampleData: Bool = false,
        notificationCenter: NotificationCenter = .default,
        makeContainer: @escaping ContainerFactory
    ) throws {
        let storedMode = defaults.string(forKey: Self.storageModeKey).flatMap(StorageMode.init(rawValue:)) ?? .local
        let mode = isICloudEnabledInBuild ? storedMode : .local

        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.seedsSampleData = seedsSampleData
        self.makeContainer = makeContainer
        currentMode = mode

        let container = try makeContainer(mode)
        containers[mode] = container
        contextProvider = ModelContextProvider(context: container.mainContext)
        prepare(container.mainContext, for: mode)

        remoteChangeObserver = notificationCenter.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleRemoteChange() }
        }
    }

    func switchTo(_ mode: StorageMode) throws {
        guard mode != currentMode else { return }

        let source = contextProvider.context
        let target = try container(for: mode).mainContext
        switch mode {
        case .iCloud:
            // A reused container may have imported duplicate tags while in Local mode (remote
            // changes are ignored then). Merging first makes the merge link recipes to the row
            // every device keeps; otherwise another device's dedup can delete the row a recipe
            // was just linked to, and the recipe loses the tag here.
            try target.deduplicateTags()
            try RecipeStoreCopier.merge(from: source, into: target)
        case .local:
            try RecipeStoreCopier.replace(contentsOf: target, with: source)
        }

        currentMode = mode
        defaults.set(mode.rawValue, forKey: Self.storageModeKey)
        contextProvider.context = target
        notificationCenter.post(name: .recipeStoreDidChange, object: self)
    }

    /// A CloudKit import landed: merge any preset tags another device seeded, then let
    /// screens reload. Imports into the iCloud container while in Local mode are ignored here;
    /// switchTo(.iCloud) merges their duplicates before copying.
    func handleRemoteChange() {
        guard currentMode == .iCloud else { return }
        deduplicateTags(in: contextProvider.context)
        notificationCenter.post(name: .recipeStoreDidChange, object: self)
    }

    private func container(for mode: StorageMode) throws -> ModelContainer {
        if let existing = containers[mode] { return existing }
        let container = try makeContainer(mode)
        containers[mode] = container
        prepare(container.mainContext, for: mode)
        return container
    }

    private func prepare(_ context: ModelContext, for mode: StorageMode) {
        context.seedPresetTagsIfNeeded()
        if mode == .iCloud {
            deduplicateTags(in: context)
        }

        #if DEBUG
        // Local only, so debug devices don't each push the sample recipes to iCloud.
        if seedsSampleData, mode == .local {
            context.seedSampleDataIfNeeded()
        }
        #endif
    }

    private func deduplicateTags(in context: ModelContext) {
        Log.data.attempt("Failed to merge duplicate tags") { try context.deduplicateTags() }
    }
}
