import SwiftData
import SwiftUI

@main
struct RecipeRaccoonApp: App {
    private let persistence: PersistenceController
    private let recipeRepository: RecipeRepository
    private let tagRepository: TagRepository
    private let photoRepository: RecipePhotoRepository
    private let captureService: RecipeCaptureService
    private let webPageFetcher: WebPageFetcher
    private let captureRecipeUseCase: CaptureRecipeUseCase
    private let checkCaptureAvailabilityUseCase: CheckCaptureAvailabilityUseCase
    private let settingsViewModel: SettingsViewModel
    private let welcomeGuideViewModel: WelcomeGuideViewModel
    /// The local-only density cache (Phase 10). Nil when the store couldn't open; the app
    /// works without it, since only unit conversion needs densities.
    private let densityContainer: ModelContainer?
    /// Nil without the store or the density API configuration (DensityAPI.xcconfig).
    private let refreshDensityCacheUseCase: RefreshDensityCacheUseCase?
    /// Nil only when the density store couldn't open.
    private let convertIngredientsToWeightUseCase: ConvertIngredientsToWeightUseCase?
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    init() {
        PCFontRegistrar.registerCustomFonts()

        do {
            persistence = try PersistenceController(
                isICloudEnabledInBuild: Self.isICloudEnabled,
                seedsSampleData: Self.seedsSampleData,
                makeContainer: Self.makeContainer
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let contextProvider = persistence.contextProvider
        recipeRepository = Self.recipeRepository(wrapping: SwiftDataRecipeRepository(modelContext: contextProvider.context))
        tagRepository = SwiftDataTagRepository(modelContext: contextProvider.context)
        photoRepository = SwiftDataRecipePhotoRepository(modelContext: contextProvider.context)
        let captureService = Self.makeCaptureService()
        self.captureService = captureService
        webPageFetcher = URLSessionWebPageFetcher()
        captureRecipeUseCase = DefaultCaptureRecipeUseCase(captureService: captureService)
        checkCaptureAvailabilityUseCase = DefaultCheckCaptureAvailabilityUseCase(captureService: captureService)
        densityContainer = Log.app.attempt("Failed to open the density cache") { try Self.makeDensityContainer() }
        convertIngredientsToWeightUseCase = densityContainer.map {
            DefaultConvertIngredientsToWeightUseCase(cacheRepository: SwiftDataDensityCacheRepository(modelContext: $0.mainContext))
        }
        if Self.usesDensityAPI, let densityContainer,
           let configuration = DensityAPIConfiguration(infoDictionary: Bundle.main.infoDictionary) {
            refreshDensityCacheUseCase = DefaultRefreshDensityCacheUseCase(
                remoteSource: URLSessionDensityEntryRemoteSource(configuration: configuration),
                cacheRepository: SwiftDataDensityCacheRepository(modelContext: densityContainer.mainContext),
                refreshLog: UserDefaultsDensityRefreshLog()
            )
        } else {
            refreshDensityCacheUseCase = nil
        }

        settingsViewModel = SettingsViewModel(
            changeStorageModeUseCase: DefaultChangeStorageModeUseCase(
                switcher: persistence,
                accountStatusProvider: CloudKitAccountStatusProvider(isEnabledInBuild: BuildConfiguration.isICloudEnabled)
            ),
            isICloudAvailableInBuild: BuildConfiguration.isICloudEnabled,
            refreshDensityCacheUseCase: refreshDensityCacheUseCase
        )
        welcomeGuideViewModel = WelcomeGuideViewModel(
            status: Self.makeWelcomeGuideStatus(),
            isCaptureAvailable: checkCaptureAvailabilityUseCase.execute
        )
    }

    // MARK: - UI test runs

    // A UI test run (-UITestScenario, Debug only) gets an in-memory store in a fixed state,
    // no sample recipes, no density API and a fixed-size Mac window; see
    // Data/DevSupport/UITestScenario.swift. The unit tests' host app gets an empty in-memory
    // store without iCloud: CloudKit imports into the developer's real store post
    // recipeStoreDidChange, which the views under test react to (#160).
    #if DEBUG
    private static let uiTestScenario = UITestScenario.current()
    private static let usesRealStore = uiTestScenario == nil && !isHostingUnitTests
    private static let seedsSampleData = usesRealStore
    private static let usesDensityAPI = usesRealStore
    /// Internal so a test can check the unit tests' host app runs without iCloud (#160).
    static let isICloudEnabled = BuildConfiguration.isICloudEnabled && !isHostingUnitTests
    #if os(macOS)
    private static let uiTestWindowSize = uiTestScenario?.macWindowContentSize
    #else
    /// iOS windows always fill the screen.
    private static let uiTestWindowSize: CGSize? = nil
    #endif
    static let makeContainer: PersistenceController.ContainerFactory =
        uiTestScenario?.makeContainer(for:)
            ?? (isHostingUnitTests ? RecipeStore.makeInMemoryContainer(for:) : RecipeStore.makeContainer(for:))

    private static func recipeRepository(wrapping repository: RecipeRepository) -> RecipeRepository {
        uiTestScenario?.recipeRepository(wrapping: repository) ?? repository
    }

    private static func makeCaptureService() -> RecipeCaptureService {
        uiTestScenario?.treatsCaptureAsAvailable == true ? PreviewRecipeCaptureService() : FoundationModelsRecipeCaptureService()
    }

    @MainActor
    private static func makeDensityContainer() throws -> ModelContainer {
        try uiTestScenario?.makeDensityContainer() ?? DensityStore.makeContainer()
    }

    /// Whether this run is the host app of the unit tests, which start it like a normal launch.
    static let isHostingUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// UI test runs and the unit tests' host app keep the seen flag in memory: a UI test only
    /// sees the guide when its scenario asks for it, and neither touches the developer's flag.
    private static func makeWelcomeGuideStatus() -> WelcomeGuideStatus {
        if let uiTestScenario {
            return InMemoryWelcomeGuideStatus(hasSeen: !uiTestScenario.showsWelcomeGuide)
        }
        if isHostingUnitTests {
            return InMemoryWelcomeGuideStatus(hasSeen: true)
        }
        return UserDefaultsWelcomeGuideStatus()
    }
    #else
    // What the Debug values are for a normal launch. Neither test kind runs against Release:
    // unit tests need @testable (Debug), and -UITestScenario is Debug only.
    private static let seedsSampleData = false
    private static let usesDensityAPI = true
    static let isICloudEnabled = BuildConfiguration.isICloudEnabled
    private static let makeContainer: PersistenceController.ContainerFactory = RecipeStore.makeContainer(for:)

    private static func recipeRepository(wrapping repository: RecipeRepository) -> RecipeRepository {
        repository
    }

    private static func makeCaptureService() -> RecipeCaptureService {
        FoundationModelsRecipeCaptureService()
    }

    private static func makeDensityContainer() throws -> ModelContainer {
        try DensityStore.makeContainer()
    }

    private static func makeWelcomeGuideStatus() -> WelcomeGuideStatus {
        UserDefaultsWelcomeGuideStatus()
    }
    #endif

    private func makeRecipeListViewModel() -> RecipeListViewModel {
        let viewModel = RecipeListViewModel(dependencies: .init(
            fetchRecipesUseCase: DefaultFetchRecipesUseCase(repository: recipeRepository),
            createRecipeUseCase: DefaultCreateRecipeUseCase(repository: recipeRepository),
            updateRecipeUseCase: DefaultUpdateRecipeUseCase(repository: recipeRepository),
            deleteRecipeUseCase: DefaultDeleteRecipeUseCase(repository: recipeRepository),
            fetchTagsUseCase: DefaultFetchTagsUseCase(repository: tagRepository),
            findOrCreateTagUseCase: DefaultFindOrCreateTagUseCase(repository: tagRepository),
            captureRecipeUseCase: captureRecipeUseCase,
            checkCaptureAvailabilityUseCase: checkCaptureAvailabilityUseCase,
            captureRecipeFromURLUseCase: DefaultCaptureRecipeFromURLUseCase(
                webPageFetcher: webPageFetcher,
                captureRecipeUseCase: captureRecipeUseCase
            ),
            fetchPhotoThumbnailUseCase: DefaultFetchPhotoThumbnailUseCase(repository: photoRepository),
            fetchPhotoImageUseCase: DefaultFetchPhotoImageUseCase(repository: photoRepository),
            photoProcessor: ImageIOPhotoProcessor()
        ))
        #if DEBUG
        // Tapping a chip doesn't reach the app on GitHub's macOS runner, so the scenario
        // starts with the tag selected instead.
        if let tagName = Self.uiTestScenario?.selectedTagName {
            viewModel.selectTag((try? tagRepository.fetchAll())?.first { $0.name == tagName }?.id)
        }
        #endif
        return viewModel
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if Self.uiTestScenario?.opensRecipeDetail == true, let recipe = try? recipeRepository.fetchAll().first {
            NavigationStack {
                RecipeDetailView(viewModel: makeRecipeListViewModel().makeDetailViewModel(for: recipe))
            }
        } else {
            recipeList
        }
        #else
        recipeList
        #endif
    }

    private var recipeList: some View {
        RecipeListView(
            viewModel: makeRecipeListViewModel(),
            settingsViewModel: settingsViewModel,
            welcomeGuideViewModel: welcomeGuideViewModel
        )
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.convertIngredientsToWeight, convertIngredientsToWeightUseCase)
                .appTheme()
                // The periodic check (Phase 10.2): on launch and whenever the app comes back,
                // refresh densities if the last refresh is more than a day old.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active, let refreshDensityCacheUseCase else { return }
                    Task {
                        do {
                            try await refreshDensityCacheUseCase.executeIfStale()
                        } catch {
                            Log.app.failure("Refreshing ingredient densities failed", error)
                        }
                    }
                }
                // Only UI test runs fix the window size; Release builds leave both modifiers out.
                #if DEBUG
                .frame(width: Self.uiTestWindowSize?.width, height: Self.uiTestWindowSize?.height)
                #if os(macOS)
                .onAppear {
                    if Self.uiTestScenario == .screenshots { UITestScenario.prepareScreenshotWindow() }
                }
                #endif
                #endif
        }
        #if DEBUG && os(macOS)
        .windowResizability(Self.uiTestWindowSize == nil ? .automatic : .contentSize)
        #endif
        #if os(macOS)
        .commands {
            AboutCommands()
            WelcomeGuideCommands()
        }
        #endif

        #if os(macOS)
        Settings {
            // Also here: with the recipe window closed, a theme change would otherwise wait.
            SettingsView(viewModel: settingsViewModel)
                .appTheme()
        }

        // Opened by the recipe window at launch, Settings and the Help menu; never by itself,
        // and not reopened by state restoration once closed.
        Window("Welcome Guide", id: WelcomeGuideView.windowID) {
            // Like Settings: with the recipe window closed, a theme change would otherwise wait.
            WelcomeGuideWindow(viewModel: welcomeGuideViewModel, settingsViewModel: settingsViewModel)
                .appTheme()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("About Recipe Raccoon", id: AboutView.windowID) {
            AboutView()
                .frame(width: AboutView.macSize.width, height: AboutView.macSize.height)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        #endif
    }
}
