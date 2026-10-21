import ImageIO
@testable import RecipeRaccoon
import SwiftData
import XCTest

final class UITestScenarioTests: XCTestCase {
    func testCurrentIsNilForANormalLaunch() {
        XCTAssertNil(UITestScenario.current(arguments: ["RecipeRaccoon", "-AppleLanguages", "(en)"]))
    }

    func testCurrentReadsTheNameAfterTheArgument() {
        for scenario in UITestScenario.allCases {
            let arguments = ["RecipeRaccoon", "-UITestScenario", scenario.rawValue, "-AppleLanguages", "(en)"]
            XCTAssertEqual(UITestScenario.current(arguments: arguments), scenario)
        }
    }

    @MainActor
    func testEachScenarioStartsWithItsRecipes() throws {
        let expectedCounts: [UITestScenario: Int] = [
            .empty: 0, .noMatchingTag: 1, .loadError: 0, .manyRecipes: 40, .recipeDetail: 1,
            .recipeWithPhotos: 1, .recipeWithPhotosDetail: 1, .servingsDetail: 1, .welcomeGuide: 0, .screenshots: 6,
        ]
        for scenario in UITestScenario.allCases {
            let container = try scenario.makeContainer(for: .local)
            let count = try container.mainContext.fetchCount(FetchDescriptor<RecipeModel>())
            XCTAssertEqual(count, expectedCounts[scenario], "\(scenario)")
        }
    }

    /// Only the welcomeGuide scenario opens the guide, or it would cover every other test's screen.
    func testOnlyTheWelcomeGuideScenarioShowsTheGuide() {
        for scenario in UITestScenario.allCases {
            XCTAssertEqual(scenario.showsWelcomeGuide, scenario == .welcomeGuide, "\(scenario)")
        }
    }

    /// The photo UI tests tell the photos apart by color: red is the cover, then green, then blue.
    @MainActor
    func testThePhotoScenariosSeedThreeColoredPhotosInOrder() throws {
        for scenario in [UITestScenario.recipeWithPhotos, .recipeWithPhotosDetail] {
            let container = try scenario.makeContainer(for: .local)
            let context = container.mainContext
            let recipe = try XCTUnwrap(SwiftDataRecipeRepository(modelContext: context).fetchAll().first)
            XCTAssertEqual(recipe.photos.count, 3, "\(scenario)")
            let photoRepository = SwiftDataRecipePhotoRepository(modelContext: context)
            let colors = try recipe.photos.map { photo in
                try Self.centerColor(of: XCTUnwrap(photoRepository.image(id: photo.id)))
            }
            XCTAssertEqual(colors, ["red", "green", "blue"], "\(scenario)")
            XCTAssertNotNil(try photoRepository.thumbnail(id: recipe.photos[0].id), "\(scenario)")
        }
    }

    func testOnlyTheDetailScenariosOpenOnARecipe() {
        let opening = UITestScenario.allCases.filter(\.opensRecipeDetail)
        XCTAssertEqual(Set(opening), [.recipeDetail, .recipeWithPhotosDetail, .servingsDetail])
    }

    /// The scaling UI test doubles "⅔ cup flour" in a recipe for 2 and checks "salt to taste" stays.
    @MainActor
    func testTheServingsScenarioSeedsARecipeForTwo() throws {
        let container = try UITestScenario.servingsDetail.makeContainer(for: .local)
        let recipe = try XCTUnwrap(SwiftDataRecipeRepository(modelContext: container.mainContext).fetchAll().first)

        XCTAssertEqual(recipe.servings, 2)
        XCTAssertEqual(recipe.ingredients.map(\.rawText), ["⅔ cup flour", "salt to taste"])
    }

    func testOnlyTheLoadErrorScenarioFailsToLoad() throws {
        let container = try ModelContainer.inMemory()
        let repository = SwiftDataRecipeRepository(modelContext: ModelContext(container))
        for scenario in UITestScenario.allCases {
            let wrapped = scenario.recipeRepository(wrapping: repository)
            if scenario == .loadError {
                XCTAssertThrowsError(try wrapped.fetchAll())
            } else {
                XCTAssertNoThrow(try wrapped.fetchAll(), "\(scenario)")
            }
        }
    }

    /// The strongest channel of the image's center pixel.
    private static func centerColor(of data: Data) throws -> String {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var rgba = [UInt8](repeating: 0, count: 4)
        rgba.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: -image.width / 2, y: -image.height / 2, width: image.width, height: image.height))
        }
        let channels = [("red", rgba[0]), ("green", rgba[1]), ("blue", rgba[2])]
        return channels.max { $0.1 < $1.1 }?.0 ?? ""
    }
}
