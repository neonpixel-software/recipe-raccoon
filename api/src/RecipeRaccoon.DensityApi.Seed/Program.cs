using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using RecipeRaccoon.DensityApi.Application;
using RecipeRaccoon.DensityApi.Application.Seeding;
using RecipeRaccoon.DensityApi.Infrastructure;

// Import of DensitySeedData (the USDA rows and their translated names) into the density table
// (PLAN.md Phase 9.1). Safe to re-run: ingredients already in the table are reported and left
// alone (see DensitySeeder), so a re-run adds only the names that are new.
//
//   dotnet run --project src/RecipeRaccoon.DensityApi.Seed -- --connection "<connection string>" [--dry-run]
//
// Without --connection it reads ConnectionStrings__DensityApi from the environment, the same
// variable the API host uses in production (docs/deploy.md §4). --dry-run reports what would be
// inserted without writing anything.

string? connectionString = null;
var dryRun = false;
// A queue rather than an index loop, so taking --connection's value doesn't move a loop
// counter from inside the loop body.
var remaining = new Queue<string>(args);
while (remaining.TryDequeue(out var arg))
{
    switch (arg)
    {
        case "--connection":
            if (!remaining.TryDequeue(out connectionString))
            {
                await Console.Error.WriteLineAsync("--connection needs a connection string after it.");
                return 2;
            }
            break;
        case "--dry-run":
            dryRun = true;
            break;
        default:
            // Fail loudly rather than ignore it: an argument the tool doesn't expect usually
            // means the command line didn't reach it as intended.
            await Console.Error.WriteLineAsync($"Unexpected argument '{arg}'. Usage: --connection \"<connection string>\" [--dry-run]");
            return 2;
    }
}

connectionString ??= Environment.GetEnvironmentVariable("ConnectionStrings__DensityApi");
if (connectionString is null)
{
    await Console.Error.WriteLineAsync("Pass --connection \"<connection string>\" or set ConnectionStrings__DensityApi.");
    return 2;
}

await using var services = new ServiceCollection()
    .AddDensityApiInfrastructure(connectionString)
    .BuildServiceProvider();
await using var scope = services.CreateAsyncScope();

// Migrations are a deliberate manual step (docs/deploy.md §8), so don't run them here, but
// don't seed a schema that's behind the model either.
var context = scope.ServiceProvider.GetRequiredService<DensityApiDbContext>();
var pending = (await context.Database.GetPendingMigrationsAsync()).ToList();
if (pending.Count > 0)
{
    await Console.Error.WriteLineAsync($"The database has {pending.Count} pending migration(s) ({string.Join(", ", pending)}). Run `dotnet ef database update` first.");
    return 1;
}

var seeder = new DensitySeeder(scope.ServiceProvider.GetRequiredService<IDensityEntryRepository>());
var result = await seeder.SeedAsync(DensitySeedData.Rows, dryRun, CancellationToken.None);
var inserted = dryRun ? "would insert" : "inserted";

foreach (var entry in result.Inserted)
{
    Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"{inserted}  {entry.IngredientName}: {entry.GramsPerMilliliter:0.####} g/ml"));
}

foreach (var (row, existing) in result.Skipped)
{
    // Compared at the precision the note prints, not exactly: the stored value has been
    // through a Postgres double round trip.
    var note = Math.Abs(existing.GramsPerMilliliter - row.GramsPerMilliliter) < 0.00005
        ? "same value"
        : string.Create(CultureInfo.InvariantCulture, $"kept {existing.GramsPerMilliliter:0.####} g/ml, seed has {row.GramsPerMilliliter:0.####}");
    Console.WriteLine($"exists    {existing.IngredientName} ({note})");
}

Console.WriteLine($"{result.Inserted.Count} {inserted}, {result.Skipped.Count} already present.");
if (dryRun)
{
    Console.WriteLine("Dry run: nothing was written.");
}

return 0;
