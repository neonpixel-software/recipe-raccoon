@testable import RecipeRaccoon
import SwiftData
import XCTest

@MainActor
final class ConvertIngredientsToWeightUseCaseTests: XCTestCase {
    private var container: ModelContainer?

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeUseCase(_ entries: [DensityEntry]) throws -> DefaultConvertIngredientsToWeightUseCase {
        let container = try DensityStore.makeContainer(inMemory: true)
        self.container = container
        let cache = SwiftDataDensityCacheRepository(modelContext: container.mainContext)
        _ = try cache.apply(entries)
        return DefaultConvertIngredientsToWeightUseCase(cacheRepository: cache)
    }

    private func entry(_ name: String, _ gramsPerMilliliter: Double) -> DensityEntry {
        DensityEntry(ingredientName: name, gramsPerMilliliter: gramsPerMilliliter, lastModified: Date(timeIntervalSince1970: 1))
    }

    private func line(_ rawText: String, _ amount: Double?, _ unit: String?, _ name: String?) -> IngredientLine {
        IngredientLine(id: UUID(), rawText: rawText, amount: amount, unit: unit, ingredientName: name)
    }

    /// PLAN.md 11.1 acceptance: toggling shows correct gram values for ingredients with density
    /// data. Densities are the USDA seed values.
    func testConvertsARecipeUsingTheCachedDensities() throws {
        let useCase = try makeUseCase([
            entry("all-purpose flour", 0.528344104716297),
            entry("granulated sugar", 0.845351),
            entry("milk", 1.030684),
        ])
        let flour = line("2 cups all-purpose flour", 2, "cups", "all-purpose flour")
        let sugar = line("1/2 cup sugar", 0.5, "cup", "granulated sugar")
        let milk = line("1 cup milk", 1, "cup", "milk")
        let eggs = line("2 eggs", 2, nil, "eggs")
        let saffron = line("1 tsp saffron", 1, "tsp", "saffron")

        let weights = useCase.execute([flour, sugar, milk, eggs, saffron], standard: .usCustomary)

        guard case let .grams(flourGrams)? = weights[flour.id],
              case let .grams(sugarGrams)? = weights[sugar.id],
              case let .grams(milkGrams)? = weights[milk.id] else { return XCTFail("Expected grams for flour, sugar and milk: \(weights)") }
        XCTAssertEqual(flourGrams, 250.0, accuracy: 0.1)
        XCTAssertEqual(sugarGrams, 100.0, accuracy: 0.1)
        XCTAssertEqual(milkGrams, 243.8, accuracy: 0.1)
        XCTAssertEqual(weights[eggs.id], .unavailable(.noMeasurementUnit))
        XCTAssertEqual(weights[saffron.id], .unavailable(.noDensity))
    }

    func testWithAnEmptyCacheOnlyWeightUnitsConvert() throws {
        let useCase = try makeUseCase([])
        let flour = line("1 cup flour", 1, "cup", "flour")
        let butter = line("100 g butter", 100, "g", "butter")

        let weights = useCase.execute([flour, butter], standard: .usCustomary)

        XCTAssertEqual(weights[flour.id], .unavailable(.noDensity))
        XCTAssertEqual(weights[butter.id], .grams(100))
    }

    /// An unreadable cache converts like an empty one: weight units only, no crash.
    func testAnUnreadableCacheConvertsLikeAnEmptyOne() {
        let useCase = DefaultConvertIngredientsToWeightUseCase(cacheRepository: UnreadableDensityCache())
        let flour = line("1 cup flour", 1, "cup", "all-purpose flour")
        let butter = line("100 g butter", 100, "g", "butter")

        let weights = useCase.execute([flour, butter], standard: .usCustomary)

        XCTAssertEqual(weights[flour.id], .unavailable(.noDensity))
        XCTAssertEqual(weights[butter.id], .grams(100))
    }

    /// The cup size is the user's Settings choice, passed in by the view (not the language).
    func testUsesTheChosenVolumeStandard() throws {
        let useCase = try makeUseCase([entry("all-purpose flour", 0.528344104716297)])
        let flour = line("1 cup flour", 1, "cup", "all-purpose flour")

        XCTAssertEqual(useCase.execute([flour], standard: .usCustomary)[flour.id], .grams(236.5882365 * 0.528344104716297))
        XCTAssertEqual(useCase.execute([flour], standard: .metric)[flour.id], .grams(250 * 0.528344104716297))
    }
}

private struct UnreadableDensityCache: DensityCacheRepository {
    func apply(_: [DensityEntry]) throws -> DensityCacheChanges { throw CocoaError(.fileReadCorruptFile) }
    func entry(forIngredientNamed _: String) throws -> DensityEntry? { throw CocoaError(.fileReadCorruptFile) }
    func allEntries() throws -> [DensityEntry] { throw CocoaError(.fileReadCorruptFile) }
    func isEmpty() throws -> Bool { throw CocoaError(.fileReadCorruptFile) }
}

final class DensityNameIndexTests: XCTestCase {
    private let index = DensityNameIndex([
        DensityEntry(ingredientName: "all-purpose flour", gramsPerMilliliter: 0.53, lastModified: .now),
        DensityEntry(ingredientName: "walnuts", gramsPerMilliliter: 0.5, lastModified: .now),
        DensityEntry(ingredientName: "butter", gramsPerMilliliter: 0.96, lastModified: .now),
        DensityEntry(ingredientName: "brown sugar", gramsPerMilliliter: 0.93, lastModified: .now),
    ])

    func testMatchesTheExactNameIgnoringCaseAndSpaces() {
        XCTAssertEqual(index.entry(forIngredientNamed: " Butter ")?.ingredientName, "butter")
    }

    func testAHyphenAndASpaceAreTheSame() {
        XCTAssertEqual(index.entry(forIngredientNamed: "all purpose flour")?.ingredientName, "all-purpose flour")
        XCTAssertEqual(index.entry(forIngredientNamed: "All-Purpose Flour")?.ingredientName, "all-purpose flour")
    }

    func testSingularAndPluralAreTheSame() {
        XCTAssertEqual(index.entry(forIngredientNamed: "walnut")?.ingredientName, "walnuts")
        XCTAssertEqual(index.entry(forIngredientNamed: "butters")?.ingredientName, "butter")
    }

    /// No guessing (PLAN.md): a different ingredient is never substituted.
    func testDoesNotMatchADifferentOrMoreSpecificIngredient() {
        XCTAssertNil(index.entry(forIngredientNamed: "salted butter"))
        XCTAssertNil(index.entry(forIngredientNamed: "sugar"))
        XCTAssertNil(index.entry(forIngredientNamed: "flour"))
        XCTAssertNil(index.entry(forIngredientNamed: ""))
    }

    /// The butter entry is unsalted butter, and softening, melting or warming it doesn't change
    /// what a cup of it weighs, in any of the app's languages.
    func testIgnoresWordsThatDontChangeTheWeightOfACup() {
        let index = DensityNameIndex([
            DensityEntry(ingredientName: "butter", gramsPerMilliliter: 0.96, lastModified: .now),
            DensityEntry(ingredientName: "boter", gramsPerMilliliter: 0.96, lastModified: .now),
            DensityEntry(ingredientName: "beurre", gramsPerMilliliter: 0.96, lastModified: .now),
            DensityEntry(ingredientName: "mantequilla", gramsPerMilliliter: 0.96, lastModified: .now),
            DensityEntry(ingredientName: "olive oil", gramsPerMilliliter: 0.91, lastModified: .now),
            DensityEntry(ingredientName: "aceite de oliva", gramsPerMilliliter: 0.91, lastModified: .now),
            DensityEntry(ingredientName: "milch", gramsPerMilliliter: 1.03, lastModified: .now),
            DensityEntry(ingredientName: "huile d'olive", gramsPerMilliliter: 0.91, lastModified: .now),
            DensityEntry(ingredientName: "honig", gramsPerMilliliter: 1.42, lastModified: .now),
        ])
        let names = [
            "unsalted butter": "butter",
            "Butter, softened": "butter",
            "melted unsalted butter": "butter",
            "butter (at room temperature)": "butter",
            "zachte boter": "boter",
            "boter (gesmolten)": "boter",
            "weiche Butter": "butter",
            "zerlassene Butter": "butter",
            "lauwarme Milch": "milch",
            "beurre fondu": "beurre",
            "beurre à température ambiante": "beurre",
            "mantequilla derretida": "mantequilla",
            "mantequilla sin sal, a temperatura ambiente": "mantequilla",
            "extra-virgin olive oil": "olive oil",
            "aceite de oliva virgen extra": "aceite de oliva",
            "aceite de oliva virgen": "aceite de oliva",
            "huile d'olive vierge extra": "huile d'olive",
            "gekühlte Milch": "milch",
            "flüssiger Honig": "honig",
            // Typed without accents.
            "beurre a temperature ambiante": "beurre",
            "flussige Butter": "butter",
            "mantequilla fria": "mantequilla",
        ]
        for (name, expected) in names {
            XCTAssertEqual(index.entry(forIngredientNamed: name)?.ingredientName, expected, name)
        }
    }

    /// Words that change what a cup holds stay part of the name: sifted flour, packed sugar and
    /// chopped nuts weigh differently, and fresh breadcrumbs or whole peppercorns are other
    /// ingredients. A name made only of ignored words matches nothing.
    func testKeepsWordsThatChangeTheWeightOfACup() {
        XCTAssertNil(index.entry(forIngredientNamed: "all-purpose flour, sifted"))
        XCTAssertNil(index.entry(forIngredientNamed: "packed brown sugar"))
        XCTAssertNil(index.entry(forIngredientNamed: "chopped walnuts"))
        XCTAssertNil(index.entry(forIngredientNamed: "fresh butter"))
        XCTAssertNil(index.entry(forIngredientNamed: "melted"))
        XCTAssertNil(index.entry(forIngredientNamed: "(softened)"))
    }

    /// Softening and melting are ignored only for fats: a cup of melted chocolate chips weighs
    /// far more than a cup of chips, and soft breadcrumbs, soft flour and harina blanda are
    /// other products.
    func testIgnoresSofteningAndMeltingOnlyForFats() {
        let index = DensityNameIndex([
            DensityEntry(ingredientName: "chocolate chips", gramsPerMilliliter: 0.71, lastModified: .now),
            DensityEntry(ingredientName: "breadcrumbs", gramsPerMilliliter: 0.46, lastModified: .now),
            DensityEntry(ingredientName: "flour", gramsPerMilliliter: 0.53, lastModified: .now),
            DensityEntry(ingredientName: "harina", gramsPerMilliliter: 0.53, lastModified: .now),
            DensityEntry(ingredientName: "coconut oil", gramsPerMilliliter: 0.92, lastModified: .now),
        ])
        XCTAssertNil(index.entry(forIngredientNamed: "melted chocolate chips"))
        XCTAssertNil(index.entry(forIngredientNamed: "soft breadcrumbs"))
        XCTAssertNil(index.entry(forIngredientNamed: "soft flour"))
        XCTAssertNil(index.entry(forIngredientNamed: "harina blanda"))
        XCTAssertEqual(index.entry(forIngredientNamed: "cold chocolate chips")?.ingredientName, "chocolate chips")
        XCTAssertEqual(index.entry(forIngredientNamed: "coconut oil, melted")?.ingredientName, "coconut oil")
    }
}
