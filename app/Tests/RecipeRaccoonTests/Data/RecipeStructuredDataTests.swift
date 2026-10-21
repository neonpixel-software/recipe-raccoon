@testable import RecipeRaccoon
import XCTest

final class RecipeStructuredDataTests: XCTestCase {
    private func page(jsonLD: String) -> String {
        """
        <html><head>
        <script type="application/ld+json">\(jsonLD)</script>
        </head><body><nav>Home · Recipes · Search</nav></body></html>
        """
    }

    func testReturnsNilWhenPageHasNoJSONLD() {
        XCTAssertNil(RecipeStructuredData.recipeText(fromHTML: "<html><body><h1>Pancakes</h1></body></html>"))
    }

    func testReturnsNilWhenJSONLDHasNoRecipe() {
        let html = page(jsonLD: #"{"@context":"https://schema.org","@type":"Organization","name":"Recipe Site"}"#)

        XCTAssertNil(RecipeStructuredData.recipeText(fromHTML: html))
    }

    func testReturnsNilForMalformedJSONLD() {
        XCTAssertNil(RecipeStructuredData.recipeText(fromHTML: page(jsonLD: #"{"@type":"Recipe","name":"#)))
    }

    func testReturnsNilWhenRecipeHasNoIngredientsOrSteps() {
        XCTAssertNil(RecipeStructuredData.recipeText(fromHTML: page(jsonLD: #"{"@type":"Recipe","name":"Pancakes"}"#)))
    }

    func testFormatsTitleIngredientsAndHowToSteps() {
        let html = page(jsonLD: """
        {"@context":"https://schema.org","@type":"Recipe","name":"Easy pancakes",
         "recipeIngredient":["100g plain flour","2 large eggs"],
         "recipeInstructions":[{"@type":"HowToStep","text":"Whisk to a smooth batter."},
                               {"@type":"HowToStep","text":"Cook 1 min on each side."}]}
        """)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), """
        Easy pancakes

        Ingredients:
        - 100g plain flour
        - 2 large eggs

        Steps:
        1. Whisk to a smooth batter.
        2. Cook 1 min on each side.
        """)
    }

    func testFindsRecipeWhoseTypeIsAnArrayInsideATopLevelArray() {
        // Allrecipes/Serious Eats shape: [{"@type":["Recipe","NewsArticle"], ...}]
        let html = page(jsonLD: """
        [{"@type":["Recipe","NewsArticle"],"name":"Pancakes",
          "recipeIngredient":["1 cup milk"],"recipeInstructions":[{"@type":"HowToStep","text":"Mix."}]}]
        """)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Pancakes\n\nIngredients:\n- 1 cup milk\n\nSteps:\n1. Mix.")
    }

    func testFindsRecipeInsideGraph() {
        // Yoast/WordPress shape (e.g. Budget Bytes): the recipe is one node of an @graph.
        let html = page(jsonLD: """
        {"@context":"https://schema.org","@graph":[{"@type":"WebPage","name":"Page"},
          {"@type":"Recipe","name":"Pasta","recipeIngredient":["200 g pasta"],"recipeInstructions":"Boil the pasta."}]}
        """)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Pasta\n\nIngredients:\n- 200 g pasta\n\nSteps:\n1. Boil the pasta.")
    }

    func testSkipsNonRecipeScriptsAndUsesTheRecipeOne() {
        let html = """
        <script type="application/ld+json">{"@type":"BreadcrumbList"}</script>
        <script type='application/ld+json' class="yoast">{"@type":"Recipe","name":"Soup","recipeIngredient":["1 onion"]}</script>
        """

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Soup\n\nIngredients:\n- 1 onion")
    }

    func testFlattensHowToSectionsAndPlainStringSteps() {
        let html = page(jsonLD: """
        {"@type":"Recipe","name":"Cake","recipeIngredient":["2 eggs"],
         "recipeInstructions":[
           {"@type":"HowToSection","name":"Batter","itemListElement":[
             {"@type":"HowToStep","text":"Beat the eggs."},{"@type":"HowToStep","text":"Fold in flour."}]},
           "Bake 30 minutes."]}
        """)

        XCTAssertEqual(
            RecipeStructuredData.recipeText(fromHTML: html),
            "Cake\n\nIngredients:\n- 2 eggs\n\nSteps:\n1. Beat the eggs.\n2. Fold in flour.\n3. Bake 30 minutes."
        )
    }

    func testSplitsSingleStringInstructionsOnLineBreaks() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Tea","recipeIngredient":["1 tea bag"],"recipeInstructions":"Boil water.\nSteep 3 minutes."}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Tea\n\nIngredients:\n- 1 tea bag\n\nSteps:\n1. Boil water.\n2. Steep 3 minutes.")
    }

    func testAcceptsSingleStringIngredient() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Toast","recipeIngredient":"1 slice bread","recipeInstructions":"Toast it."}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Toast\n\nIngredients:\n- 1 slice bread\n\nSteps:\n1. Toast it.")
    }

    func testSplitsSingleStringIngredientsOnLineBreaks() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Pancakes","recipeIngredient":"1 cup flour\n\n2 eggs"}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Pancakes\n\nIngredients:\n- 1 cup flour\n- 2 eggs")
    }

    func testFallsBackToStepNameWhenTextIsMissing() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Toast","recipeInstructions":[{"@type":"HowToStep","name":"Toast the bread."}]}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Toast\n\nSteps:\n1. Toast the bread.")
    }

    func testDecodesEntitiesStripsTagsAndCollapsesWhitespace() {
        // Seen on real pages: "The Food Lab&#39;s …", non-breaking spaces, inline markup in steps.
        let html = page(jsonLD: """
        {"@type":"Recipe","name":"The Food Lab&#39;s Cookie &amp; Milk",
         "recipeIngredient":["2 to 3 very\\u00a0ripe  bananas"],
         "recipeInstructions":[{"@type":"HowToStep","text":"<p>Heat to 180&deg;C &#x2013; <b>not</b> hotter.</p>"}]}
        """)

        XCTAssertEqual(
            RecipeStructuredData.recipeText(fromHTML: html),
            "The Food Lab's Cookie & Milk\n\nIngredients:\n- 2 to 3 very ripe bananas\n\nSteps:\n1. Heat to 180°C – not hotter."
        )
    }

    func testDropsBlankIngredientsAndSteps() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Salad","recipeIngredient":["1 lettuce"," ",""],"recipeInstructions":["Chop.","  "]}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Salad\n\nIngredients:\n- 1 lettuce\n\nSteps:\n1. Chop.")
    }

    // MARK: recipeYield (Phase 15.2)

    func testAddsTheYieldAsAYieldLine() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Banana bread","recipeYield":"1 loaf","recipeIngredient":["3 bananas"]}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Banana bread\n\nYield: 1 loaf\n\nIngredients:\n- 3 bananas")
    }

    func testJoinsAYieldArrayAndReadsNumbers() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Soup","recipeYield":[4,"4 servings"],"recipeIngredient":["1 onion"]}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Soup\n\nYield: 4, 4 servings\n\nIngredients:\n- 1 onion")
    }

    func testLeavesOutAnEmptyYield() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Soup","recipeYield":[" "],"recipeIngredient":["1 onion"]}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Soup\n\nIngredients:\n- 1 onion")
    }

    func testSkipsABooleanYield() {
        let html = page(jsonLD: #"{"@type":"Recipe","name":"Soup","recipeYield":true,"recipeIngredient":["1 onion"]}"#)

        XCTAssertEqual(RecipeStructuredData.recipeText(fromHTML: html), "Soup\n\nIngredients:\n- 1 onion")
    }
}
