import SwiftUI

/// One ingredient line on the recipe screen. `weight` is nil in the As Written view; in the
/// Weight view it's the line's conversion result. `original` is the line as the recipe writes
/// it, when it's shown for other servings (Phase 15.3) and its text changed.
struct IngredientLineText: View {
    let ingredient: IngredientLine
    let weight: IngredientWeight?
    var original: String?

    var body: some View {
        switch weight {
        case let .grams(grams)?:
            let formatted = IngredientWeightFormatter.format(grams: grams)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ingredient.ingredientName.map { "\(formatted) \($0)" } ?? formatted)
                    .font(PCFont.body(15))
                    .foregroundStyle(PCColor.textPrimary)
                secondary(Text(ingredient.rawText))
            }
        case .unavailable(.noDensity)?:
            // A volume the app has no density for: keep the measurement as written and say so,
            // rather than guess a weight (PLAN.md 11.2).
            VStack(alignment: .leading, spacing: 2) {
                primary
                originalLine
                secondary(Text("Conversion not available"))
            }
        default:
            // As Written, or nothing to convert ("2 eggs", "salt to taste").
            if original == nil {
                primary
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    primary
                    originalLine
                }
            }
        }
    }

    private var primary: some View {
        Text(ingredient.rawText)
            .font(PCFont.body(15))
            .foregroundStyle(PCColor.textPrimary)
    }

    @ViewBuilder private var originalLine: some View {
        if let original {
            secondary(Text(verbatim: original))
        }
    }

    private func secondary(_ text: Text) -> some View {
        text
            .font(PCFont.body(13))
            .foregroundStyle(PCColor.textPrimary.opacity(0.55))
    }
}
