# Recipe Raccoon

A NeonPixel app for macOS, iPadOS, and iOS. Gather recipes with zero friction: type one in or paste a URL, and it's stored clean — no ads, no life story, just the recipe.

> ⚠️ **Disclaimer:** This repository was built by three LLMs (large language models). The code was written by language models, but it holds the same standard as anything else here: it has to pass CI, the test suites, and the SonarCloud quality gate before it lands.

[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=neonpixel-software_recipe-raccoon&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=neonpixel-software_recipe-raccoon)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=neonpixel-software_recipe-raccoon&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=neonpixel-software_recipe-raccoon)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=neonpixel-software_recipe-raccoon&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=neonpixel-software_recipe-raccoon)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=neonpixel-software_recipe-raccoon&metric=coverage)](https://sonarcloud.io/summary/new_code?id=neonpixel-software_recipe-raccoon)
[![Duplicated Lines (%)](https://sonarcloud.io/api/project_badges/measure?project=neonpixel-software_recipe-raccoon&metric=duplicated_lines_density)](https://sonarcloud.io/summary/new_code?id=neonpixel-software_recipe-raccoon)

## Features

- **Zero-friction capture** — two clearly presented options on the add-recipe screen: *Type it* (free text) or *Paste a link* (URL). Apple Intelligence structures or extracts the recipe entirely on-device — no server round-trip. Devices without Apple Intelligence fall back straight to a blank structured form.
- **Review before save** — every capture path lands on an editable review screen. Nothing saves unreviewed.
- **Tags** — preset tags (breakfast, lunch, dinner, dessert, snack) plus unlimited custom tags, multiple per recipe, with tag filtering on the list.
- **Local or iCloud** — recipes stay on the device by default; a Settings switch syncs them to the user's other devices through their private iCloud database, and switching back keeps a local copy.

## Privacy

Recipe Raccoon collects **no** user data, shows **no** ads, and is completely anonymous. Recipe capture runs on-device via Apple Intelligence — a pasted URL is fetched directly from its source site, never proxied through our servers — and the only other network activity is the user's own iCloud sync and the density-data API. The App Store privacy declaration is "Data Not Collected": see the [privacy policy](PRIVACY.md) and [what's entered in App Store Connect](app/docs/app-store-connect.md).

## Repository layout

```
app/    SwiftUI client (macOS, iPadOS, iOS) — one shared codebase, Clean Architecture + MVVM, SwiftData
api/    .NET 10 density API (Minimal APIs, EF Core + PostgreSQL) — serves ingredient density data only
PLAN.md Source of truth for architecture and the phase-by-phase implementation plan
docs/history/ Dated notes behind each phase's status: device checks, issue fixes, TestFlight stages
```

The API does exactly one job — serve ingredient density data for unit conversion — and is fully decoupled from the client: it is not involved in recipe storage, sync, or capture.

## Development

### Swift app (`app/`)

The Xcode project is generated from [`project.yml`](app/project.yml) with [XcodeGen](https://github.com/yonaskolb/XcodeGen), from the `app/` directory:

```sh
xcodegen generate
```

Then open `app/RecipeRaccoon.xcodeproj` and use the `RecipeRaccoon-iOS` / `RecipeRaccoon-macOS` schemes (build, test, coverage). Deployment targets are iOS 26 / macOS 26; the UI is localized into English, Spanish, French, German, and Dutch.

Each scheme's tests include a small UI test target (`app/Tests/RecipeRaccoonUITests`) for layout that unit tests can't see. It launches the Debug app with `-UITestScenario <name>`, which swaps in an in-memory store in a fixed state, so your own recipes are never touched. On macOS a run asks you to authenticate to turn on Automation Mode, and the header checks take screenshots, which need the Screen Recording permission: if they fail with "Image creation failed", allow the prompt or add `RecipeRaccoon-macOSUITests-Runner` (in the DerivedData `Build/Products/Debug` folder) under Privacy & Security > Screen & System Audio Recording.

iCloud sync needs a signing team, which stays out of this public repo: copy `app/Config/Signing.xcconfig.example` to `app/Config/Signing.xcconfig` (gitignored), fill in your team ID, and run `xcodegen generate` again. Without it the app builds without the iCloud entitlement and the storage setting is disabled; that's how CI builds it.

### Density API (`api/`)

Local development uses [Podman](https://podman.io) for the PostgreSQL container. From the `api/` directory:

```sh
podman compose up -d        # starts Postgres on localhost:5433
dotnet ef database update \
  --project src/RecipeRaccoon.DensityApi.Infrastructure \
  --startup-project src/RecipeRaccoon.DensityApi.Api
dotnet run --project src/RecipeRaccoon.DensityApi.Api
dotnet test                 # unit + Testcontainers-backed integration tests
```

See [`api/README.md`](api/README.md) for full details (one-time `dotnet-ef` install, the Testcontainers/Podman socket setup), and [`api/docs/deploy.md`](api/docs/deploy.md) for the production deployment runbook: the VPS setup, the manually started deploy workflow (`.github/workflows/deploy-api.yml`), migrations and seeding over an SSH tunnel, and backups. It hasn't been run against the real VPS yet.

## Documentation

- [`PLAN.md`](PLAN.md) — architecture, data model, and the phase-by-phase plan with current status
- [`app/docs/plans/`](app/docs/plans/) — Swift app design docs (entry form, tagging, capture, localization)
- [`api/docs/plans/`](api/docs/plans/) — density API design docs
- [`api/docs/deploy.md`](api/docs/deploy.md) — deployment runbook for the density API
- [`app/docs/release.md`](app/docs/release.md) — release builds: versioning, the tag that starts them, and the Xcode Cloud Release workflow

Development proceeds in vertical slices (see `PLAN.md`); the project is not yet at its full v1 feature set. Still on the roadmap: checking live iCloud sync to the Mac on a TestFlight build (Phase 4.1, see `PLAN.md`), verification of the on-device AI capture on real devices (Phases 5.1/6.1/7.3), the client's density cache (Phase 10), and unit conversion — the volume/weight toggle on each recipe (Phase 11).

## CI & quality

GitHub Actions runs on every PR targeting `main` and every push to `main`: Swift build + test + coverage (iOS and macOS), .NET build + test, linting (SwiftLint/SwiftFormat, `dotnet format`), and a SonarCloud analysis with quality gate for the whole repo (the badges above). The 90% coverage target is enforced: each iOS and macOS build fails below 90% line coverage of `app/Sources`, and the .NET build below 90% of `api/src` ([`check-coverage.py`](.github/scripts/check-coverage.py); the minimum is `COVERAGE_MIN` in `ci.yml`). Files that no test can reasonably reach are listed in [`coverage-exclusions.txt`](.github/coverage-exclusions.txt), which SonarCloud uses too. When the gate fails, add tests, or exclude a file no test can reasonably reach and give the reason in that file. Don't lower the minimum. Each side is only checked when its build runs, so an app-only PR doesn't check the API. SonarCloud analyzes both sides in one project. The .NET scanner only sees Swift files through [`app/Sonar/RecipeRaccoon.App.Sonar.csproj`](app/Sonar/RecipeRaccoon.App.Sonar.csproj) (#138).

Xcode Cloud builds the app for TestFlight. Since the Xcode project is generated and gitignored, [`app/ci_scripts/ci_post_clone.sh`](app/ci_scripts/ci_post_clone.sh) runs `xcodegen generate` and resolves the Swift packages after each clone. For iCloud-enabled builds, set a secret `DEVELOPMENT_TEAM` environment variable in the Xcode Cloud workflow; the script writes it into `Signing.xcconfig`. Releases go out by pushing a `vX.Y.Z` tag, which starts the Xcode Cloud Release workflow for iOS and macOS: see [`app/docs/release.md`](app/docs/release.md).

## License

MIT — one [`LICENSE`](LICENSE) at the repo root covering the whole repository (`app/` + `api/`). See the [Licensing section of PLAN.md](PLAN.md#licensing) for the reasoning behind the choice.
