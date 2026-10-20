import SwiftUI

struct RecipeListView: View {
    @State private var viewModel: RecipeListViewModel
    @State private var isPresentingNewRecipe = false
    @State private var isPresentingAddChooser = false
    @State private var isPresentingCapture = false
    @State private var isPresentingURLCapture = false
    @State private var isPresentingCaptureUnavailableAlert = false
    /// Staged between the capture sheet dismissing and the review sheet presenting, so the
    /// two sheet transitions don't race (see the sheet's onDismiss below).
    @State private var pendingCaptureReview: Recipe?
    @State private var pendingURLCaptureReview: Recipe?
    @State private var reviewingCapturedRecipe: Recipe?
    /// The tag whose Delete Tag was picked, until the confirmation is answered.
    @State private var tagPendingDeletion: Tag?

    @State private var isPresentingSettings = false
    /// Shown from a toolbar button on iOS/iPadOS; macOS has its own Settings window (⌘,).
    private let settingsViewModel: SettingsViewModel?

    /// Opens by itself at launch until it has been closed once (14.1). On iOS this screen
    /// presents it; the Mac opens it in its own window.
    private let welcomeGuideViewModel: WelcomeGuideViewModel?
    @State private var isPresentingWelcomeGuide = false
    /// Settings → Show Welcome Guide: staged until the Settings sheet has gone, so the two
    /// presentations don't race (like pendingCaptureReview).
    @State private var isWelcomeGuidePending = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    init(
        viewModel: RecipeListViewModel,
        settingsViewModel: SettingsViewModel? = nil,
        welcomeGuideViewModel: WelcomeGuideViewModel? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.settingsViewModel = settingsViewModel
        self.welcomeGuideViewModel = welcomeGuideViewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.allTags.isEmpty {
                    TagFilterRow(
                        tags: viewModel.allTags,
                        selectedTagID: viewModel.selectedTagID,
                        onSelect: { viewModel.selectTag($0) },
                        onDelete: { tagPendingDeletion = $0 }
                    )
                    .confirmationDialog(
                        Text("Delete “\(tagPendingDeletion?.name ?? "")”?"),
                        isPresented: Binding(
                            get: { tagPendingDeletion != nil },
                            set: { if !$0 { tagPendingDeletion = nil } }
                        ),
                        titleVisibility: .visible,
                        presenting: tagPendingDeletion
                    ) { tag in
                        Button("Delete", role: .destructive) { viewModel.deleteTag(tag) }
                        Button("Cancel", role: .cancel) { /* no-op: the dialog dismisses on its own */ }
                    } message: { _ in
                        Text("The tag comes off every recipe that has it. The recipes stay.")
                    }
                }

                Group {
                    if let errorMessage = viewModel.errorMessage {
                        ContentUnavailableView(
                            "Couldn't Load Recipes",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                    } else if viewModel.recipes.isEmpty {
                        ContentUnavailableView(
                            "No Recipes Yet",
                            systemImage: "fork.knife"
                        )
                    } else if viewModel.filteredRecipes.isEmpty {
                        ContentUnavailableView(
                            "No Recipes With This Tag",
                            systemImage: "tag"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredRecipes) { recipe in
                                    NavigationLink(destination: RecipeDetailView(
                                        viewModel: viewModel.makeDetailViewModel(for: recipe),
                                        onRecipeChanged: {
                                            viewModel.load()
                                            // An edit or delete can remove a custom tag (#211).
                                            viewModel.loadTags()
                                        }
                                    )) {
                                        RecipeRow(
                                            recipe: recipe,
                                            loadCover: { viewModel.coverThumbnailData(for: recipe) },
                                            onDelete: { viewModel.delete(recipe) }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .accessibilityIdentifier("RecipeList")
                    }
                }
                // The empty and error states only take the height they need; without this the
                // whole column (header included) gets centered in the window instead of pinned to the top.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(PCColor.background)
            .safeAreaInset(edge: .top, spacing: 0) {
                PCHeader(title: String(localized: "Recipes"))
            }
            .navigationTitle("")
            .pcHeaderBar()
            #if os(macOS)
            // macOS drew its own dark toolbar background over the header's pink here, while the
            // detail screen and iOS show the pink up to the window top (#104).
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            #endif
            .toolbar {
                #if os(iOS)
                if settingsViewModel != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isPresentingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                        .pcHeaderToolbarButton()
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddChooser = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("RecipeList.add")
                    .pcHeaderToolbarButton()
                    // Attached to the button, not the whole view: the dialog presents as a popover
                    // anchored to the view it's attached to (iPad, and iPhone on iOS 26), so on the
                    // NavigationStack content it floated in the middle of the list (#106).
                    .confirmationDialog("Add Recipe", isPresented: $isPresentingAddChooser, titleVisibility: .visible) {
                        Button("Type It") {
                            if viewModel.isCaptureAvailable {
                                isPresentingCapture = true
                            } else {
                                isPresentingCaptureUnavailableAlert = true
                            }
                        }
                        Button("Paste a Link") {
                            if viewModel.isCaptureAvailable {
                                isPresentingURLCapture = true
                            } else {
                                isPresentingCaptureUnavailableAlert = true
                            }
                        }
                        .accessibilityIdentifier("AddRecipe.pasteLink")
                        Button("Enter Manually") { isPresentingNewRecipe = true }
                        Button("Cancel", role: .cancel) { /* no-op: the dialog dismisses on its own */ }
                    }
                }
            }
            .alert("AI Capture Unavailable", isPresented: $isPresentingCaptureUnavailableAlert) {
                Button("OK") { isPresentingNewRecipe = true }
            } message: {
                Text("AI capture isn't available on this device. You can still enter the recipe by hand.")
            }
            .sheet(isPresented: $isPresentingNewRecipe) {
                RecipeFormView(viewModel: viewModel.makeNewRecipeFormViewModel()) { _ in
                    viewModel.load()
                    viewModel.loadTags()
                }
            }
            .sheet(isPresented: $isPresentingCapture, onDismiss: {
                if let recipe = pendingCaptureReview {
                    pendingCaptureReview = nil
                    reviewingCapturedRecipe = recipe
                }
            }) {
                RecipeCaptureView(viewModel: viewModel.makeCaptureViewModel()) { recipe in
                    pendingCaptureReview = recipe
                    isPresentingCapture = false
                }
            }
            .sheet(isPresented: $isPresentingURLCapture, onDismiss: {
                if let recipe = pendingURLCaptureReview {
                    pendingURLCaptureReview = nil
                    reviewingCapturedRecipe = recipe
                }
            }) {
                RecipeURLCaptureView(viewModel: viewModel.makeURLCaptureViewModel()) { recipe in
                    pendingURLCaptureReview = recipe
                    isPresentingURLCapture = false
                }
            }
            .sheet(item: $reviewingCapturedRecipe) { recipe in
                RecipeFormView(viewModel: viewModel.makeCaptureReviewFormViewModel(for: recipe)) { _ in
                    viewModel.load()
                    viewModel.loadTags()
                }
            }
        }
        .tint(PCColor.pink)
        .task {
            viewModel.load()
            viewModel.loadTags()
            if welcomeGuideViewModel?.showsOnLaunch == true {
                showWelcomeGuide()
            }
        }
        // A storage switch or an iCloud import changed the recipes underneath this screen.
        .onReceive(NotificationCenter.default.publisher(for: .recipeStoreDidChange)) { _ in
            viewModel.load()
            viewModel.loadTags()
        }
        #if os(iOS)
        .sheet(isPresented: $isPresentingSettings, onDismiss: {
            if isWelcomeGuidePending {
                isWelcomeGuidePending = false
                showWelcomeGuide()
            }
        }) {
            if let settingsViewModel {
                SettingsView(
                    viewModel: settingsViewModel,
                    onShowWelcomeGuide: welcomeGuideViewModel == nil ? nil : {
                        isWelcomeGuidePending = true
                        isPresentingSettings = false
                    }
                )
            }
        }
        .modifier(OptionalWelcomeGuide(
            isPresented: $isPresentingWelcomeGuide,
            viewModel: welcomeGuideViewModel,
            settingsViewModel: settingsViewModel
        ))
        #endif
    }

    private func showWelcomeGuide() {
        #if os(macOS)
        openWindow(id: WelcomeGuideView.windowID)
        #else
        isPresentingWelcomeGuide = true
        #endif
    }
}

#if os(iOS)
/// The welcome guide's presentation, when the list was given a guide (the app always does;
/// previews and tests may not).
private struct OptionalWelcomeGuide: ViewModifier {
    @Binding var isPresented: Bool
    let viewModel: WelcomeGuideViewModel?
    let settingsViewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        if let viewModel {
            content.welcomeGuide(isPresented: $isPresented, viewModel: viewModel, settingsViewModel: settingsViewModel)
        } else {
            content
        }
    }
}
#endif

private struct RecipeRow: View {
    let recipe: Recipe
    let loadCover: () -> Data?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Rows without photos stay as they were, without a placeholder.
            if let cover = recipe.photos.first {
                RecipeCoverThumbnail(photoID: cover.id, load: loadCover)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(PCFont.body(17, weight: .semibold))
                    .foregroundStyle(PCColor.textPrimary)

                if !recipe.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(recipe.tags) { tag in
                            Text(tag.localizedDisplayName())
                                .font(PCFont.body(11, weight: .bold))
                                .foregroundStyle(PCColor.ink)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(PCColor.teal, in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PCColor.textPrimary.opacity(0.35))
        }
        .padding(16)
        .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// The cover photo at the start of a list row, read lazily as the row appears.
struct RecipeCoverThumbnail: View {
    static let size: CGFloat = 56
    static let accessibilityIdentifier = "RecipeRowCover"

    let photoID: UUID
    let load: () -> Data?
    @State private var image: Image?

    var body: some View {
        ZStack {
            PCColor.background
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                // The cover's bytes haven't synced to this device yet.
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundStyle(PCColor.textPrimary.opacity(0.4))
            }
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
        .accessibilityIdentifier(Self.accessibilityIdentifier)
        // Keyed by the photo, so a new cover (Make Cover in the form) loads its own image.
        .task(id: photoID) { image = await PhotoPageImage.image(from: load) }
        .onReceive(NotificationCenter.default.publisher(for: .recipeStoreDidChange)) { _ in
            // Only while no photo is showing (its bytes weren't here yet). A photo that's
            // showing isn't read again: its id's bytes never change once stored, and a
            // different photo (a new cover) comes with a new id, which reruns the task.
            guard image == nil else { return }
            Task { image = await PhotoPageImage.image(from: load) }
        }
    }
}

// The preview doubles live in Data/DevSupport behind #if DEBUG, so the preview must too (#95).
#if DEBUG
#Preview {
    PCFontRegistrar.registerCustomFonts()
    return RecipeListView(viewModel: RecipeListViewModel(dependencies: .init(
        fetchRecipesUseCase: DefaultFetchRecipesUseCase(repository: PreviewRecipeRepository()),
        createRecipeUseCase: DefaultCreateRecipeUseCase(repository: PreviewRecipeRepository()),
        updateRecipeUseCase: DefaultUpdateRecipeUseCase(repository: PreviewRecipeRepository()),
        deleteRecipeUseCase: DefaultDeleteRecipeUseCase(repository: PreviewRecipeRepository()),
        fetchTagsUseCase: DefaultFetchTagsUseCase(repository: PreviewTagRepository()),
        findOrCreateTagUseCase: DefaultFindOrCreateTagUseCase(repository: PreviewTagRepository()),
        deleteTagUseCase: DefaultDeleteTagUseCase(repository: PreviewTagRepository()),
        captureRecipeUseCase: DefaultCaptureRecipeUseCase(captureService: PreviewRecipeCaptureService()),
        checkCaptureAvailabilityUseCase: DefaultCheckCaptureAvailabilityUseCase(captureService: PreviewRecipeCaptureService()),
        captureRecipeFromURLUseCase: DefaultCaptureRecipeFromURLUseCase(
            webPageFetcher: PreviewWebPageFetcher(),
            captureRecipeUseCase: DefaultCaptureRecipeUseCase(captureService: PreviewRecipeCaptureService())
        ),
        fetchPhotoThumbnailUseCase: DefaultFetchPhotoThumbnailUseCase(repository: PreviewRecipePhotoRepository()),
        fetchPhotoImageUseCase: DefaultFetchPhotoImageUseCase(repository: PreviewRecipePhotoRepository()),
        photoProcessor: ImageIOPhotoProcessor()
    )))
}
#endif
