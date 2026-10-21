import SwiftUI

struct RecipeFormView: View {
    /// Owned as @State: callers build the view model inside a `.sheet` closure, which runs
    /// again whenever the presenting view re-renders. Holding it with @Bindable swapped in
    /// that new view model, whose tags never load because `.task` doesn't re-run (#84).
    @State private var viewModel: RecipeFormViewModel
    @Environment(\.dismiss) private var dismiss
    let onSave: (Recipe) -> Void

    init(viewModel: RecipeFormViewModel, onSave: @escaping (Recipe) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    titleField
                    servingsRow

                    formSection(title: String(localized: "Photos"), accent: PCColor.pink) {
                        RecipeFormPhotosSection(viewModel: viewModel)
                    }

                    formSection(title: String(localized: "Ingredients"), accent: PCColor.teal) {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.ingredients.enumerated()), id: \.element.id) { index, _ in
                                IngredientRow(
                                    draft: $viewModel.ingredients[index],
                                    canMoveUp: index > 0,
                                    canMoveDown: index < viewModel.ingredients.count - 1,
                                    onMoveUp: { viewModel.moveIngredientUp(at: index) },
                                    onMoveDown: { viewModel.moveIngredientDown(at: index) },
                                    onDelete: { viewModel.removeIngredient(at: index) }
                                )
                            }
                            addButton(title: String(localized: "Add Ingredient")) { viewModel.addIngredient() }
                        }
                    }

                    formSection(title: String(localized: "Equipment"), accent: PCColor.deepTeal) {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.equipment.enumerated()), id: \.element.id) { index, _ in
                                EquipmentRow(
                                    name: $viewModel.equipment[index].name,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < viewModel.equipment.count - 1,
                                    onMoveUp: { viewModel.moveEquipmentUp(at: index) },
                                    onMoveDown: { viewModel.moveEquipmentDown(at: index) },
                                    onDelete: { viewModel.removeEquipment(at: index) }
                                )
                            }
                            addButton(title: String(localized: "Add Equipment")) { viewModel.addEquipment() }
                        }
                    }

                    formSection(title: String(localized: "Steps"), accent: PCColor.pink) {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, _ in
                                StepRow(
                                    stepNumber: index + 1,
                                    text: $viewModel.steps[index].text,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < viewModel.steps.count - 1,
                                    onMoveUp: { viewModel.moveStepUp(at: index) },
                                    onMoveDown: { viewModel.moveStepDown(at: index) },
                                    onDelete: { viewModel.removeStep(at: index) }
                                )
                            }
                            addButton(title: String(localized: "Add Step")) { viewModel.addStep() }
                        }
                    }

                    formSection(title: String(localized: "Tags"), accent: PCColor.deepTeal) {
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.allTags) { tag in
                                TagChip(
                                    title: tag.localizedDisplayName(),
                                    isSelected: viewModel.selectedTagIDs.contains(tag.id),
                                    action: { viewModel.toggleTag(tag) }
                                )
                            }

                            if viewModel.isAddingNewTag {
                                TextField("Tag name", text: $viewModel.newTagName)
                                    .font(PCFont.body(13, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(PCColor.surface, in: Capsule())
                                    .frame(width: 120)
                                    .onSubmit { viewModel.confirmNewTag() }
                            } else {
                                TagChip(title: String(localized: "+ New Tag"), isSelected: false) {
                                    viewModel.beginAddingNewTag()
                                }
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        PCErrorMessage(errorMessage)
                    }
                }
                .padding(20)
            }
            .background(PCColor.background)
            .navigationTitle("Recipe")
            .task { viewModel.loadTags() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let saved = viewModel.save() {
                            onSave(saved)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .tint(PCColor.pink)
    }

    private var titleField: some View {
        TextField("Recipe title", text: $viewModel.title)
            .font(PCFont.body(20, weight: .semibold))
            .foregroundStyle(PCColor.textPrimary)
            .padding(16)
            .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var servingsRow: some View {
        HStack(spacing: 12) {
            Text("Servings")
                .font(PCFont.body(17, weight: .semibold))
                .foregroundStyle(PCColor.textPrimary)
            Spacer()
            if let servings = viewModel.servings {
                Stepper(value: Binding(get: { servings }, set: { viewModel.changeServings(to: $0) }), in: Recipe.servingsRange) {
                    Text(servings, format: .number)
                        .font(PCFont.body(17, weight: .semibold))
                        .foregroundStyle(PCColor.textPrimary)
                        .monospacedDigit()
                }
                .fixedSize()
                .accessibilityLabel(Text("Servings"))
                .accessibilityValue(Text(servings, format: .number))
                .accessibilityIdentifier("servingsStepper")
                Button {
                    viewModel.clearServings()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear Servings"))
            } else {
                Button {
                    viewModel.setServings()
                } label: {
                    Label("Set Servings", systemImage: "plus.circle.fill")
                        .font(PCFont.body(15, weight: .semibold))
                        .foregroundStyle(PCColor.deepTeal)
                }
                .buttonStyle(.plain)
            }
        }
        // The stepper's height, so the row doesn't grow when servings are set.
        .frame(minHeight: 32)
        .padding(16)
        .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func formSection(
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

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
                .font(PCFont.body(15, weight: .semibold))
                .foregroundStyle(PCColor.deepTeal)
        }
    }
}

private struct IngredientRow: View {
    @Binding var draft: IngredientLineDraft
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Amount", text: $draft.amount)
                        .frame(width: 64)
                    TextField("Unit", text: $draft.unit)
                        .frame(width: 72)
                    TextField("Ingredient name", text: $draft.ingredientName)
                }
                .font(PCFont.body(15))
                .foregroundStyle(PCColor.textPrimary)
                .textFieldStyle(.plain)
            }
            .padding(12)
            .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

            RowControls(canMoveUp: canMoveUp, canMoveDown: canMoveDown, onMoveUp: onMoveUp, onMoveDown: onMoveDown, onDelete: onDelete)
        }
    }
}

private struct EquipmentRow: View {
    @Binding var name: String
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("Tool or cookware", text: $name)
                .font(PCFont.body(15))
                .foregroundStyle(PCColor.textPrimary)
                .textFieldStyle(.plain)
                .padding(12)
                .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

            RowControls(canMoveUp: canMoveUp, canMoveDown: canMoveDown, onMoveUp: onMoveUp, onMoveDown: onMoveDown, onDelete: onDelete)
        }
    }
}

private struct StepRow: View {
    let stepNumber: Int
    @Binding var text: String
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(stepNumber)")
                    .font(PCFont.body(13, weight: .bold))
                    .foregroundStyle(PCColor.ink)
                    .frame(width: 26, height: 26)
                    .background(PCColor.pink, in: Circle())
                TextField("Step description", text: $text, axis: .vertical)
                    .font(PCFont.body(15))
                    .foregroundStyle(PCColor.textPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
            }
            .padding(12)
            .background(PCColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

            RowControls(canMoveUp: canMoveUp, canMoveDown: canMoveDown, onMoveUp: onMoveUp, onMoveDown: onMoveDown, onDelete: onDelete)
        }
    }
}

private struct RowControls: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onMoveUp) {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMoveUp)
            .accessibilityLabel(String(localized: "Move up"))
            Button(action: onMoveDown) {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMoveDown)
            .accessibilityLabel(String(localized: "Move down"))
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PCColor.pink)
            }
            .accessibilityLabel(String(localized: "Delete"))
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(PCColor.textPrimary.opacity(0.55))
        .buttonStyle(.plain)
        .padding(.top, 12)
    }
}

// The preview doubles live in Data/DevSupport behind #if DEBUG, so the preview must too (#95).
#if DEBUG
#Preview {
    PCFontRegistrar.registerCustomFonts()
    return RecipeFormView(
        viewModel: RecipeFormViewModel(mode: .create, dependencies: .preview),
        onSave: PreviewRecipeHandler.ignore
    )
}
#endif
