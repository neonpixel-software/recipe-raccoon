namespace RecipeRaccoon.DensityApi.Application.Seeding;

/// Everything the seed tool loads: the USDA rows under their English names, then the same
/// rows under the names recipes use in the app's other languages.
public static class DensitySeedData
{
    public static IReadOnlyList<DensitySeedRow> Rows { get; } = [.. UsdaSeedData.Rows, .. TranslatedSeedNames.Rows];
}
