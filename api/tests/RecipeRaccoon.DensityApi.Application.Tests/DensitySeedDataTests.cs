using RecipeRaccoon.DensityApi.Application.Seeding;

namespace RecipeRaccoon.DensityApi.Application.Tests;

public class DensitySeedDataTests
{
    [Fact]
    public void Rows_AreTheUsdaRowsThenTheTranslatedOnes()
    {
        Assert.Equal([.. UsdaSeedData.Rows, .. TranslatedSeedNames.Rows], DensitySeedData.Rows);
    }

    [Fact]
    public void Names_AreUniqueIgnoringCase()
    {
        // The table's citext index would reject the second row; the seeder would skip it, and a
        // translated name used for two different ingredients would silently keep only the first.
        var duplicates = DensitySeedData.Rows
            .GroupBy(row => row.IngredientName, StringComparer.OrdinalIgnoreCase)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key);

        Assert.Empty(duplicates);
    }
}
