import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    /// Read by the recipe screen's weight view; not part of the view model because nothing but
    /// this picker writes it.
    @AppStorage(VolumeStandard.storageKey) private var volumeStandard = VolumeStandard.regionDefault()
    /// Applied to the windows by AppThemeModifier.
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @Environment(\.openURL) private var openURL

    /// On iOS, opens the welcome guide: the list closes this sheet first and presents it.
    /// The Mac opens the guide's window itself.
    private let onShowWelcomeGuide: (() -> Void)?

    init(viewModel: SettingsViewModel, onShowWelcomeGuide: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onShowWelcomeGuide = onShowWelcomeGuide
    }

    var body: some View {
        #if os(macOS)
        form
            .frame(width: 440)
            .fixedSize(horizontal: false, vertical: true)
        #else
        NavigationStack {
            form
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #endif
    }

    private var form: some View {
        Form {
            Section {
                Picker("Store Recipes", selection: storageModeBinding) {
                    Text("On This Device").tag(StorageMode.local)
                    Text("iCloud").tag(StorageMode.iCloud)
                }
                .pickerStyle(.inline)
                .disabled(!viewModel.canChangeStorage)

                if viewModel.isSwitching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Moving your recipes…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !viewModel.isSwitching, let syncStatus = viewModel.syncStatus {
                    syncStatusRow(syncStatus)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text(footerText)
            }

            appearanceSection

            languageSection

            volumeStandardSection

            densitySection

            if canShowWelcomeGuide {
                Section("Help") {
                    Button("Show Welcome Guide", action: showWelcomeGuide)
                }
            }

            // The Mac has About Recipe Raccoon in its app menu instead.
            #if os(iOS)
            Section {
                NavigationLink("About Recipe Raccoon") { AboutView() }
            }
            #endif
        }
        .formStyle(.grouped)
        .task { viewModel.reloadDensityStatus() }
    }

    @ViewBuilder
    private func syncStatusRow(_ status: ICloudSyncStatus) -> some View {
        switch status {
        case .waiting:
            Text("Waiting for the first sync…")
                .foregroundStyle(.secondary)
        case let .synced(date):
            Text(Self.lastSyncedText(date))
                .foregroundStyle(.secondary)
        case let .failed(failure, details):
            Text(failure.message)
                .foregroundStyle(failure.isError ? .red : .secondary)
            if failure.isError {
                Button("Copy Error Details") { Self.copyToPasteboard(details) }
            }
        }
    }

    /// Resolves to the catalog key "Last synced %@"; LocalizedSettingsStringsTests checks that.
    static func lastSyncedText(_ date: Date) -> LocalizedStringKey {
        "Last synced \(date, format: .relative(presentation: .named))"
    }

    static func copyToPasteboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $theme) {
                Text("System").tag(AppTheme.system)
                Text("Light").tag(AppTheme.light)
                Text("Dark").tag(AppTheme.dark)
            }
            .pickerStyle(.inline)
        }
    }

    /// The app follows the device's language. The system has a per-app language setting, and
    /// iOS can't switch an app's language while it runs, so this only leads there.
    private var languageSection: some View {
        Section {
            LabeledContent("Language", value: Self.currentLanguageName)
            #if os(macOS)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                    openURL(url)
                }
            }
            #else
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            #endif
        } footer: {
            Text(languageFooterText)
        }
    }

    private var languageFooterText: LocalizedStringKey {
        #if os(macOS)
        "Recipe Raccoon uses your Mac's language. To choose another one for this app only, add Recipe Raccoon under Applications in Language & Region."
        #else
        "Recipe Raccoon uses your device's language. To use another one for this app only, choose it under Language in Settings. If it isn't listed, add it to your device's languages first."
        #endif
    }

    /// The language the app runs in, as `languageName(for:)` names it.
    static var currentLanguageName: String {
        languageName(for: Bundle.main.preferredLocalizations.first ?? "en")
    }

    /// A localization's language in that language ("Español"), as the system names it. The
    /// catalogs are bare language codes, but a region ("en-GB") is dropped anyway. "Base" has no
    /// name of its own and means the development language, English. Capitalized because Spanish
    /// and French name their languages in lowercase ("español", "français").
    static func languageName(for identifier: String) -> String {
        let locale = Locale(identifier: identifier == "Base" ? "en" : identifier)
        let code = locale.language.languageCode?.identifier ?? identifier
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? identifier
    }

    private var volumeStandardSection: some View {
        Section {
            Picker("Cups and Spoons", selection: $volumeStandard) {
                Text("US Customary").tag(VolumeStandard.usCustomary)
                Text("Metric").tag(VolumeStandard.metric)
            }
            .pickerStyle(.inline)
        } header: {
            Text("Measurements")
        } footer: {
            Text("Used to show ingredients by weight. A US cup is 237 ml; a metric cup is 250 ml.")
        }
    }

    private var densitySection: some View {
        Section {
            if let lastRefresh = viewModel.lastDensityRefresh {
                Text(Self.lastUpdatedText(lastRefresh))
            } else {
                Text("Not downloaded yet")
            }

            HStack(spacing: 8) {
                Button("Refresh Now") {
                    Task { await viewModel.refreshDensities() }
                }
                .disabled(!viewModel.canRefreshDensities)

                if viewModel.isRefreshingDensities {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let status = viewModel.densityStatus {
                Text(status.message)
                    .foregroundStyle(status.isFailure ? .red : .secondary)
            }
        } header: {
            Text("Ingredient Densities")
        } footer: {
            Text(densityFooterText)
        }
    }

    private var canShowWelcomeGuide: Bool {
        #if os(macOS)
        true
        #else
        onShowWelcomeGuide != nil
        #endif
    }

    private func showWelcomeGuide() {
        #if os(macOS)
        openWindow(id: WelcomeGuideView.windowID)
        #else
        onShowWelcomeGuide?()
        #endif
    }

    /// Resolves to the catalog key "Last updated %@"; LocalizedSettingsStringsTests checks that.
    static func lastUpdatedText(_ date: Date) -> LocalizedStringKey {
        "Last updated \(date, format: .relative(presentation: .named))"
    }

    private var densityFooterText: LocalizedStringKey {
        if !viewModel.isDensityAPIAvailableInBuild {
            return "Ingredient densities aren't available in this build."
        }
        return "Recipe Raccoon uses ingredient densities to convert between volume and weight. It checks for updates once a day."
    }

    private var footerText: LocalizedStringKey {
        if !viewModel.isICloudAvailableInBuild {
            return "iCloud sync isn't available in this build."
        }
        return "With iCloud, your recipes sync to your other devices signed in to the same account. Switching back to this device keeps a copy of every recipe here and stops syncing."
    }

    private var storageModeBinding: Binding<StorageMode> {
        Binding(
            get: { viewModel.storageMode },
            set: { mode in Task { await viewModel.selectStorageMode(mode) } }
        )
    }
}
