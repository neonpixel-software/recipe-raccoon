using RecipeRaccoon.DensityApi.Application.Seeding;
using RecipeRaccoon.DensityApi.Domain;

namespace RecipeRaccoon.DensityApi.Application.Tests;

public class TranslatedSeedNamesTests
{
    [Fact]
    public void Translations_NameAUsdaRow()
    {
        var english = UsdaSeedData.Rows.Select(row => row.IngredientName).ToHashSet();

        Assert.All(TranslatedSeedNames.Translations, translation => Assert.Contains(translation.EnglishName, english));
    }

    [Fact]
    public void Translations_EachHaveOneEntryAndANameInSomeLanguage()
    {
        var duplicates = TranslatedSeedNames.Translations
            .GroupBy(translation => translation.EnglishName)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key);

        Assert.Empty(duplicates);
        Assert.All(TranslatedSeedNames.Translations, translation => Assert.NotEmpty(translation.Names));
    }

    [Fact]
    public void Names_AreCanonicalAndLowerCase()
    {
        Assert.All(TranslatedSeedNames.Translations.SelectMany(translation => translation.Names), name =>
        {
            Assert.Equal(IngredientNames.Canonicalize(name), name);
            Assert.Equal(name.ToLowerInvariant(), name);
        });
    }

    [Fact]
    public void Rows_CopyTheEnglishRowsSourceAndDensity()
    {
        var english = UsdaSeedData.Rows.ToDictionary(row => row.IngredientName);
        var flour = english["all-purpose flour"];

        var bloem = Assert.Single(TranslatedSeedNames.Rows, row => row.IngredientName == "bloem");

        Assert.Equal(flour with { IngredientName = "bloem" }, bloem);
        Assert.Equal(flour.GramsPerMilliliter, bloem.GramsPerMilliliter);
    }

    [Fact]
    public void Rows_LeaveOutNamesEqualToTheEnglishOneAndRepeatsAcrossLanguages()
    {
        // German "butter" is the English name; French and Spanish share "miel".
        Assert.DoesNotContain(TranslatedSeedNames.Rows, row => row.IngredientName == "butter");
        Assert.Single(TranslatedSeedNames.Rows, row => row.IngredientName == "miel");
    }

    [Fact]
    public void Rows_SpellAnApostropheBothWays()
    {
        Assert.Single(TranslatedSeedNames.Rows, row => row.IngredientName == "huile d'olive");
        Assert.Single(TranslatedSeedNames.Rows, row => row.IngredientName == "huile d’olive");
    }

    [Fact]
    public void Rows_EveryNameWithAnApostropheHasItsTwin()
    {
        var names = TranslatedSeedNames.Rows.Select(row => row.IngredientName).ToHashSet();

        Assert.All(names.Where(name => name.Contains('\'')), name => Assert.Contains(name.Replace('\'', '’'), names));
        Assert.All(names.Where(name => name.Contains('’')), name => Assert.Contains(name.Replace('’', '\''), names));
    }

    /// In Belgium, Canada and Switzerland "sucre en poudre" is powdered sugar, so it can't stand
    /// for granulated (PR #213 review).
    [Fact]
    public void Rows_LeaveOutNamesThatMeanDifferentProductsByRegion()
    {
        Assert.DoesNotContain(TranslatedSeedNames.Rows, row => row.IngredientName == "sucre en poudre");
    }
}
