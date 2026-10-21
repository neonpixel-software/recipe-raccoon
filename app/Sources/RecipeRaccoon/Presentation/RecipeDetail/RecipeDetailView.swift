import SwiftUI

struct RecipeDetailView: View {
    /// Owned as @State: the list builds the view model inside its NavigationLink destination,
    /// which runs again whenever the list re-renders. With @Bindable the detail switched to
    /// that new view model and lost an open edit sheet or delete confirmation (#89).
    /// The trade-off: the detail keeps its first view model even after the list reloads, so it
    /// only stays current because no other screen can change a recipe while its detail is showing.
    /// If that changes (search, sync), refresh `viewModel.recipe` from the repository here.
    @State private var viewModel: RecipeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.convertIngredientsToWeight) private var convertIngredientsToWeight
    /// The as-written/weight choice, remembered across recipes and launches.
    @AppStorage("showsIngredientWeights") private var showsWeights = false
    /// The cup and spoon size chosen in Settings.
    @AppStorage(VolumeStandard.storageKey) private var volumeStandard = VolumeStandard.regionDefault()
    @State private var weights: [UUID: IngredientWeight] = [:]
    @State private var viewerStart: PhotoViewerStart?

    /// Invoked whenever this recipe is edited or deleted, so the list that pushed this
    /// screen can refresh — NavigationStack's `.onAppear` on pop-back isn't reliably
    /// re-triggered on macOS, so the list can't rely on lifecycle events alone.
    private let onRecipeChanged: () -> Void

    init(viewModel: RecipeDetailViewModel, onRecipeChanged: @escaping () -> Void = { /* no-op: not every caller needs to react to changes */ }) {
        _viewModel = State(initialValue: viewModel)
        self.onRecipeChanged = onRecipeChanged
    }

    private var recipe: Recipe { viewModel.recipe }

    /// From this width on (a Mac window, an iPad, an iPhone in landscape) a recipe with photos
    /// shows them in a column beside it. Narrower, a full-width photo sits on top, as on an
    /// iPhone held upright, where it doesn't push the recipe far down.
    static let twoColumnMinWidth: CGFloat = 700
    /// The photo column's share of the width, up to the gallery's own limit.
    private static let photoColumnFraction: CGFloat = 0.42
    /// The margin around the photo column, as around the recipe.
    private static let columnMargin: CGFloat = 20

    /// The photo column's width in a `size` window: its share of the width, up to the gallery's
    /// limit, and narrower in a short window, so the 4:3 page and its dots (17 pt, with two or
    /// more photos) fit the height. The column doesn't scroll, so anything taller was clipped.
    static func photoColumnWidth(in size: CGSize, photoCount: Int) -> CGFloat {
        let dotsHeight: CGFloat = photoCount > 1 ? 17 : 0
        let fittingWidth = (size.height - 2 * columnMargin - dotsHeight) * 4 / 3
        return max(0, min(RecipePhotoGallery.maxWidth, size.width * photoColumnFraction, fittingWidth))
    }

    var body: some View {
        GeometryReader { geometry in
            if !recipe.photos.isEmpty, geometry.size.width >= Self.twoColumnMinWidth {
                // The photos stay in view beside the recipe while it scrolls.
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        recipeSections
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
                    gallery
                        .frame(width: Self.photoColumnWidth(in: geometry.size, photoCount: recipe.photos.count))
                        .padding([.top, .trailing], Self.columnMargin)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Recipes without photos look as they did before photos existed.
                        if !recipe.photos.isEmpty {
                            gallery
                        }
                        recipeSections
                    }
                    // Full width, leading: a short recipe otherwise sized the scroll view to its content,
                    // centered in the window, with the window's own background on both sides and, on
                    // macOS, no pink under the toolbar (#104).
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
        }
        .background(PCColor.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            PCHeader(title: recipe.title)
        }
        .navigationTitle("")
        .pcHeaderBar()
        #if os(macOS)
        // As on the list (#104): the pink reached up under the toolbar while the scroll view was
        // this screen's outermost view; inside the column layout macOS draws its own toolbar
        // background there instead.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { viewModel.isPresentingEdit = true }
                    .pcHeaderToolbarButton()
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) { viewModel.isPresentingDeleteConfirmation = true }
                    // Ink like Edit, deliberately not destructive red: on the pink header it has
                    // to be readable first. The dialog below keeps its red Delete as the guard.
                    .pcHeaderToolbarButton()
                    // On the button so the popover anchors to it, not mid-screen (#106).
                    .confirmationDialog(
                        "Delete this recipe?",
                        isPresented: $viewModel.isPresentingDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) { viewModel.delete() }
                        Button("Cancel", role: .cancel) { /* no-op: the dialog dismisses on its own */ }
                    }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingEdit) {
            RecipeFormView(viewModel: viewModel.makeEditFormViewModel()) { saved in
                viewModel.recipe = saved
                onRecipeChanged()
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $viewerStart) { start in
            PhotoViewer(photos: recipe.photos, startIndex: start.index, loadImage: viewModel.imageData(for:))
        }
        #else
        .sheet(item: $viewerStart) { start in
            PhotoViewer(photos: recipe.photos, startIndex: start.index, loadImage: viewModel.imageData(for:))
        }
        #endif
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted {
                onRecipeChanged()
                dismiss()
            }
        }
        .tint(PCColor.pink)
        .onChange(of: showsWeights, initial: true) { updateWeights() }
        .onChange(of: recipe.ingredients) { updateWeights() }
        .onChange(of: viewModel.shownServings) { updateWeights() }
        .onChange(of: volumeStandard) { updateWeights() }
    }

    private var gallery: some View {
        RecipePhotoGallery(
            photos: recipe.photos,
            loadImage: viewModel.imageData(for:),
            onOpen: { viewerStart = PhotoViewerStart(index: $0) }
        )
    }

    /// Tags, ingredients, equipment and steps: everything but the photos.
    private var recipeSections: some View {
        VStack(alignment: .leading, spacing: 32) {
            if !recipe.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(recipe.tags) { tag in
                        Text(tag.localizedDisplayName())
                            .font(PCFont.body(12, weight: .bold))
                            .foregroundStyle(PCColor.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(PCColor.teal, in: Capsule())
                    }
                }
            }

            section(title: String(localized: "Ingredients"), accent: PCColor.teal) {
                if !recipe.ingredients.isEmpty {
                    servingsRow
                    Picker("Measurements", selection: $showsWeights) {
                        Text("As Written").tag(false)
                        Text("Weight").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Group {
                    if recipe.ingredients.isEmpty {
                        Text("No ingredients listed")
                            .font(PCFont.body(15))
                            .foregroundStyle(PCColor.textPrimary.opacity(0.55))
                            .padding(16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.shownIngredients.enumerated()), id: \.element.id) { index, ingredient in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(PCColor.teal)
                                        .frame(width: 8, height: 8)
                                    IngredientLineText(
                                        ingredient: ingredient,
                                        weight: showsWeights ? weights[ingredient.id] : nil,
                                        original: originalText(of: ingredient, at: index)
                                    )
                                    Spacer()
                                }
                                .padding(.vertical, 12)

                                if index < recipe.ingredients.count - 1 {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            }

            // Hidden when empty: most recipes, including every one saved before #82, have none.
            if !recipe.equipment.isEmpty {
                section(title: String(localized: "Equipment"), accent: PCColor.deepTeal) {
                    VStack(spacing: 0) {
                        ForEach(Array(recipe.equipment.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(PCColor.deepTeal)
                                    .frame(width: 8, height: 8)
                                Text(item)
                                    .font(PCFont.body(15))
                                    .foregroundStyle(PCColor.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, 12)

                            if index < recipe.equipment.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                }
            }

            section(title: String(localized: "Steps"), accent: PCColor.pink) {
                if recipe.steps.isEmpty {
                    Text("No steps listed")
                        .font(PCFont.body(15))
                        .foregroundStyle(PCColor.textPrimary.opacity(0.55))
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(index + 1)")
                                    .font(PCFont.body(13, weight: .bold))
                                    .foregroundStyle(PCColor.ink)
                                    .frame(width: 26, height: 26)
                                    .background(PCColor.pink, in: Circle())
                                Text(step)
                                    .font(PCFont.body(15))
                                    .foregroundStyle(PCColor.textPrimary)
                                    .padding(.top, 3)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Servings and a −/+ control above the ingredients (Phase 15.3), with the recipe's own
    /// number and a reset button once it's changed; "Set Servings" opens Edit when the recipe has
    /// no number.
    @ViewBuilder private var servingsRow: some View {
        if let shown = viewModel.shownServings {
            HStack(spacing: 10) {
                Text("Servings")
                    .font(PCFont.body(15, weight: .semibold))
                    .foregroundStyle(PCColor.textPrimary)
                servingsButton("minus.circle.fill", label: "Fewer Servings", isEnabled: viewModel.canDecreaseServings) {
                    viewModel.decreaseServings()
                }
                Text(shown, format: .number)
                    .font(PCFont.body(15, weight: .semibold))
                    .foregroundStyle(PCColor.textPrimary)
                    .monospacedDigit()
                    // Two digits wide, so + doesn't move between 9 and 10.
                    .frame(minWidth: 20)
                    .accessibilityIdentifier("shownServings")
                servingsButton("plus.circle.fill", label: "More Servings", isEnabled: viewModel.canIncreaseServings) {
                    viewModel.increaseServings()
                }
                Spacer()
                if viewModel.isScaled, let own = recipe.servings {
                    Text("(recipe: \(own))")
                        .font(PCFont.body(13))
                        .foregroundStyle(PCColor.textPrimary.opacity(0.55))
                    servingsButton("arrow.counterclockwise.circle.fill", label: "Reset Servings", isEnabled: true) {
                        viewModel.resetServings()
                    }
                }
            }
        } else {
            Button {
                viewModel.isPresentingEdit = true
            } label: {
                Label("Set Servings", systemImage: "plus.circle.fill")
                    .font(PCFont.body(15, weight: .semibold))
                    .foregroundStyle(PCColor.deepTeal)
            }
            .buttonStyle(.plain)
        }
    }

    private func servingsButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(PCColor.deepTeal)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
    }

    /// The line as the recipe writes it, when the servings shown changed its text.
    private func originalText(of ingredient: IngredientLine, at index: Int) -> String? {
        guard recipe.ingredients.indices.contains(index) else { return nil }
        let original = recipe.ingredients[index].rawText
        return original == ingredient.rawText ? nil : original
    }

    /// Weighs the lines shown, so grams follow the servings; they come from the exact scaled
    /// amounts, not the rounded text.
    private func updateWeights() {
        weights = showsWeights ? convertIngredientsToWeight?.execute(viewModel.shownIngredients, standard: volumeStandard) ?? [:] : [:]
    }

    private func section(
        title: String,
        accent: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent)
                    .frame(width: 11, height: 11)
                Text(title.uppercased())
                    .font(PCFont.body(13, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(PCColor.textPrimary)
            }
            content()
        }
    }
}

// The preview doubles live in Data/DevSupport behind #if DEBUG, so the preview must too (#95).
#if DEBUG
#Preview {
    PCFontRegistrar.registerCustomFonts()
    return NavigationStack {
        RecipeDetailView(viewModel: RecipeDetailViewModel(
            recipe: SampleData.recipes[0],
            formDependencies: .preview,
            deleteRecipeUseCase: DefaultDeleteRecipeUseCase(repository: PreviewRecipeRepository()),
            fetchPhotoImageUseCase: DefaultFetchPhotoImageUseCase(repository: PreviewRecipePhotoRepository())
        ))
    }
}
#endif
