# RecipeRaccoon.DensityApi

.NET 10 Minimal API serving ingredient density data (grams per millilitre). Clean
Architecture: `Domain` (entity + validation) → `Application` (services,
repository interface) → `Infrastructure` (EF Core + PostgreSQL) →
`Api` (Minimal API host).

## Local development

Uses [Podman](https://podman.io) rather than Docker — `podman machine init && podman machine start` once, then:

```sh
podman compose up -d                          # starts Postgres on localhost:5433
dotnet tool install --global dotnet-ef        # once
export PATH="$PATH:$HOME/.dotnet/tools"
dotnet ef database update \
  --project src/RecipeRaccoon.DensityApi.Infrastructure \
  --startup-project src/RecipeRaccoon.DensityApi.Api
dotnet run --project src/RecipeRaccoon.DensityApi.Api
```

`GET /health` confirms the host is up.

To load the seed densities (safe to re-run; ingredients already in the table are
left alone; add `--dry-run` to see what it would insert without writing):

```sh
dotnet run --project src/RecipeRaccoon.DensityApi.Seed -- \
  --connection "Host=localhost;Port=5433;Database=densityapi;Username=densityapi;Password=densityapi-local-dev"
```

## Data source

Seed density values come from [USDA FoodData Central](https://fdc.nal.usda.gov/)
(SR Legacy household-measure portion weights — the cup/tbsp unit is in the
`food_portion.modifier` column — converted to g/ml), which is public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Each seed entry
(`src/RecipeRaccoon.DensityApi.Application/Seeding/UsdaSeedData.cs`) cites its FDC
ID and the portion it came from. Don't add values copied from sources whose license doesn't
permit redistribution in this MIT-licensed repo (see PLAN.md Phase 9.1).

`TranslatedSeedNames` (next to `UsdaSeedData`) adds the Dutch, German, French and Spanish
names recipes use for the same ingredients. Each is a seed row with the English row's FDC
source and density, so the app's strict name matching finds "bloem" as well as
"all-purpose flour". To add a language or a name, add it there; re-running the seed tool
inserts only the new names.

> U.S. Department of Agriculture, Agricultural Research Service.
> FoodData Central. fdc.nal.usda.gov.

## Testing

```sh
dotnet test
```

The `Infrastructure.Tests` and `Api.Tests` data tests use
`Testcontainers.PostgreSql` — a real, throwaway Postgres container per
test method, with the actual EF Core migrations run against it.
Testcontainers talks to the Docker Engine API over the standard
`/var/run/docker.sock` path: `podman machine` forwards the in-machine API
socket to `~/.local/share/containers/podman/machine/podman.sock`, and the
`podman-mac-helper` system service (one-time `sudo podman-mac-helper
install`) keeps the `/var/run/docker.sock` link pointed at it. The only
prerequisite after that is a running Podman machine (`podman machine
start` again after a reboot). If the helper is missing or
`/var/run/docker.sock` is in use by another runtime, `podman machine
start` prints a `DOCKER_HOST` export for the machine socket — run it for
the test session, or install the helper.
The first run pulls `postgres:17` into the machine.
