using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using RecipeRaccoon.DensityApi.Api.Endpoints;
using RecipeRaccoon.DensityApi.Application.Seeding;
using RecipeRaccoon.DensityApi.Infrastructure;
using Testcontainers.PostgreSql;

namespace RecipeRaccoon.DensityApi.Api.Tests;

/// PLAN.md Phase 9.1's acceptance check, end to end: after seeding a real (migrated)
/// database, the read endpoint returns sensible densities for common ingredients.
public class DensityEntriesSeedTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:17")
        .Build();

    private DbContextOptions<DensityApiDbContext> _options = null!;
    private DensityApiWebApplicationFactory _factory = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        _options = new DbContextOptionsBuilder<DensityApiDbContext>()
            .UseNpgsql(_container.GetConnectionString())
            .Options;
        await using var context = new DensityApiDbContext(_options);
        await context.Database.MigrateAsync();

        _factory = new DensityApiWebApplicationFactory { ConnectionString = _container.GetConnectionString() };
    }

    public async Task DisposeAsync()
    {
        await _factory.DisposeAsync();
        await _container.DisposeAsync();
    }

    private async Task<DensitySeedResult> SeedAsync(bool dryRun = false)
    {
        await using var context = new DensityApiDbContext(_options);
        var seeder = new DensitySeeder(new DensityEntryRepository(context));
        return await seeder.SeedAsync(DensitySeedData.Rows, dryRun, CancellationToken.None);
    }

    [Fact]
    public async Task Get_AfterSeeding_ReturnsSensibleDensitiesForStaples()
    {
        await SeedAsync();
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Api-Key", DensityApiWebApplicationFactory.ReadApiKey);

        var response = await client.GetAsync("/density-entries");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var entries = (await response.Content.ReadFromJsonAsync<List<DensityEntryResponse>>())!;
        Assert.Equal(DensitySeedData.Rows.Count, entries.Count);
        var byName = entries.ToDictionary(entry => entry.IngredientName, entry => entry.GramsPerMilliliter);
        Assert.InRange(byName["all-purpose flour"], 0.50, 0.56);
        Assert.InRange(byName["granulated sugar"], 0.82, 0.88);
        Assert.InRange(byName["butter"], 0.93, 0.99);
        // A Dutch recipe's names find the same values (TranslatedSeedNames).
        Assert.Equal(byName["all-purpose flour"], byName["bloem"]);
        Assert.Equal(byName["granulated sugar"], byName["suiker"]);
    }

    [Fact]
    public async Task Seed_RunTwice_InsertsNothingTheSecondTime()
    {
        var first = await SeedAsync();
        var second = await SeedAsync();

        Assert.Equal(DensitySeedData.Rows.Count, first.Inserted.Count);
        Assert.Empty(second.Inserted);
        Assert.Equal(DensitySeedData.Rows.Count, second.Skipped.Count);
    }

    [Fact]
    public async Task Seed_DryRun_WritesNothing()
    {
        var dryRun = await SeedAsync(dryRun: true);

        Assert.Equal(DensitySeedData.Rows.Count, dryRun.Inserted.Count);
        await using var context = new DensityApiDbContext(_options);
        Assert.Equal(0, await context.DensityEntries.CountAsync());
    }
}
