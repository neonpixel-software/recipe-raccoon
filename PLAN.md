# Recipe Raccoon — Plan

A NeonPixel app for macOS, iPadOS, and iOS. Lets you gather recipes with zero friction: type one in or paste a URL, and it's stored clean, no ads, no life story, just the recipe. Tag recipes (breakfast, dinner, custom tags, multiple per recipe) and switch ingredient measurements between volume (cups, spoons) and weight (grams). The app gathers no data of the user and no ads will be shown. The app is completely anonymous.

This is the source of truth for architecture and the phase-by-phase implementation plan. The name-brainstorm/decision history lives in the vault note this was moved from.

## Architecture

One SwiftUI codebase targets all three platforms (macOS, iPadOS, iOS). Local data uses SwiftData; when a user opts into iCloud (a settings toggle, not a default), the same SwiftData store syncs via CloudKit, no separate code path.

Recipe capture (typed text and URL extraction) runs entirely on-device via Apple Intelligence — no server round-trip, keeps it fast and private. Devices without Apple Intelligence support fall back straight to a blank structured entry form.

A separate, purpose-built .NET API (hosted on an existing Ubuntu 26.04 VPS) does exactly one job: serve ingredient density data (grams per millilitre) for unit conversion. It is not involved in recipe storage, sync, or capture — fully decoupled from the client app.

## Platform & deployment target

`app/project.yml` pins a 26.0 minimum for both iOS and macOS. This is a deliberate product-scope decision, not an oversight (issue #53): Apple Intelligence — the mechanism behind both capture paths (Phase 5, Phase 6) — requires iOS 26, so the floor is necessary for the app's core capture experience to exist at all. The app ships AI-first and accepts excluding the entire pre-iOS-26 installed base as a trade-off, rather than lowering the floor and gating every AI-dependent code path behind availability checks to give older OSes a non-AI story.

The "no Apple Intelligence available → blank form" fallback (Phase 5.2) is not an older-OS compatibility path — every supported device already runs iOS 26+. It's for iOS 26 devices whose hardware doesn't meet Apple Intelligence's requirements (e.g. older chips that received iOS 26 but not Apple Intelligence). Manual entry, tagging, sync, and density conversion work identically there; only the AI-assisted capture step is skipped.

Revisit only if pre-26 demand turns out to be significant enough to justify the added complexity of an older-OS, non-AI code path.

## Architecture & coding guidelines

Priority for this project: maintainable, testable, scalable over fastest-to-ship. Clean Architecture on both the client and the API, targeting **90%+ test coverage** on both projects.

**Swift app (Clean Architecture + MVVM, not MV):** MV was considered but rejected — it binds views straight to SwiftData's query system, which couples UI to persistence and undermines the whole point of Clean Architecture. Layers:
- **Domain** — plain Swift structs (`Recipe`, `IngredientLine`, `Tag`, `DensityEntry`) and protocols (repositories, capture service). No SwiftData or networking imports; fully unit-testable in isolation.
- **Data** — concrete implementations: SwiftData-backed repositories, the Apple Intelligence capture service, the density API client. SwiftData `@Model` classes are kept fully separate from domain structs, with explicit mapping code between them (more boilerplate, chosen deliberately for full decoupling over the lighter-weight option of models doing double duty).
- **Use cases** — orchestration (e.g. "capture recipe from text," "convert ingredient units"), depending only on domain protocols, never concrete implementations.
- **Presentation** — thin MVVM view models per screen: hold view state, call use cases, expose results. No business logic in views or view models.

**.NET density API (Clean Architecture, Minimal APIs, no MediatR):** Domain (density entry + validation rules), Application (plain services — "get density entries," "upsert density entry" — no CQRS/MediatR, judged unnecessary ceremony for an API this size), Infrastructure (EF Core, DB, API key enforcement), thin Minimal API endpoint layer on top.

**Testing strategy:**
- Domain + use-case layers (Swift) and Domain + Application layers (.NET): unit tests with fakes, no real persistence.
- Data/Infrastructure layers: integration tests against an in-memory SwiftData store / a real or in-memory test database.
- View models: tested against fake use cases, asserting state transitions (loading/success/error).
- UI tests (XCUITest): only for what needs a running app, mainly layout and window geometry, plus accessibility structure (SwiftUI's accessibility tree is empty in unit tests). Logic belongs in the layers above. Examples: where the header band sits under the toolbar or nav bar, that it stays put while the list scrolls, and that the detail content uses the full width (#98, #104). One shared source folder (`app/Tests/RecipeRaccoonUITests`) builds `RecipeRaccoon-iOSUITests` and `RecipeRaccoon-macOSUITests`, and both are in their scheme's test action, so CI runs them on every push/PR next to the unit tests.
- UI test start state: each test launches the Debug app with `-UITestScenario <name>` (`Data/DevSupport/UITestScenario.swift`, covered by `UITestScenarioTests`). That swaps in an in-memory store with no CloudKit, sample data or density API, starts in a fixed state (empty, no matching tag, load error, many recipes, recipe detail) and, on the Mac, uses a fixed 900×600 content size. An unknown or missing scenario name stops the app, so a test never runs against the developer's own store. Local setup (Automation Mode, Screen Recording for the screenshot checks) is in the README.
- UI test rules: on GitHub's macOS runner, synthesized clicks don't reach the app, so tests can't rely on mouse input. A scenario has to start in the state the test needs. Scroll-wheel input works there but sometimes moves the list less or not at all, so scroll in steps and poll for a positive result rather than waiting a fixed time. A new UI test must be seen failing without its fix before it counts.
- Apple Intelligence capture service: tested via a fake conforming to the same protocol for use-case tests (output isn't fully deterministic); real device checks with sample recipes handled as manual/semi-automated verification, not strict pass-fail units.
- .NET API layer: integration tests against the actual Minimal API endpoints, specifically proving read/write API key enforcement, not just happy-path responses.

**Tooling:** SwiftLint + SwiftFormat on the Swift side, `.editorconfig` + `dotnet format` on the .NET side, both enforced in CI (GitHub Actions) alongside tests and coverage on every push/PR. The 90% coverage target is a CI gate (issue #135): each iOS and macOS build, and the API build, fails below 90% line coverage of its sources, excluding the files listed in `.github/coverage-exclusions.txt`. UI test coverage counts. The configs are checked in (`app/.swiftformat`, `app/.swiftlint.yml`, `api/.editorconfig`) and written to match the conventions each codebase already uses rather than re-styling it (issue #51); CI pins the tool version each config was validated against.

## Data model

- **Recipe** — title, ingredient lines, equipment (tools and cookware, e.g. "loaf pan"), steps, source (`typed` or the original URL), tags.
- **Photo** — an image the user added to a recipe (photo library or camera), stored scaled down without metadata. A recipe has any number, in order; the first is its cover. Syncs with the recipe.
- **Ingredient line** — raw text as entered/extracted, plus (where AI could identify it) structured amount, unit, and ingredient name. The structured fields are what make conversion possible; lines without them show as-is.
- **Tag** — name + flag for built-in preset vs. user-created. Many-to-many with recipes. Presets ship in-app (breakfast, lunch, dinner, dessert, etc.); users can add their own freely.
- **Density entry** — ingredient name → grams per millilitre. Metric is the base unit; cups and spoons are derived from it on the client, because "a cup" varies by country (US 236.6 ml, metric 250 ml). Sourced from the .NET API, cached locally on-device.

## Recipe capture

Two clearly presented options on the add-recipe screen — "Type it" or "Paste a link" — so URL support is discoverable, not a hidden trick.

**Typed:** user enters free text, Apple Intelligence structures it into title/ingredients/steps, result lands on an editable review screen before saving. Nothing saves unreviewed.

**URL:** app fetches the page, Apple Intelligence extracts just the recipe (ignoring ads, backstory, comments), same editable review screen.

**No Apple Intelligence available:** skip the AI step, open a blank structured form instead. Same data model, same review screen, just manual entry.

## Unit conversion

Every recipe view has a volume/weight toggle. Switching to weight converts each ingredient line using its density entry, if one is cached locally. If no density value exists for an ingredient, that line shows its original measurement with a small "conversion not available" note — no guessing, no generic estimate substituted in.

## Storage & sync

Single settings choice: **Local** or **iCloud**. Switching to iCloud migrates existing recipes up; switching back keeps a local-only copy on that device. This setting only affects recipes — the density cache is a local performance cache regardless, it doesn't need to sync.

## Backend: density API (.NET)

Hosted on Nick's existing Ubuntu 26.04 VPS. Two access tiers:
- **Read** — low-privilege API key baked into the app, used for fetching/refreshing density entries.
- **Write** — higher-privilege API key held by Nick, used to add/edit entries. No admin UI needed yet; a script is enough for now.

Seeded once from public-domain USDA FoodData Central portion weights (see Phase 9.1), then curated by hand over time through the authenticated write endpoints.

**Refresh cadence:** the app checks for new/changed density entries periodically in the background, and also lets the user trigger a manual refresh. Either way, results are cached locally so conversion keeps working offline.

## Licensing

**MIT**, one root `LICENSE` covering the whole repo (`app/` + `api/`).

The repo originally shipped as GPL-3.0, which conflicts with the App Store: Apple's distribution terms (no redistribution of modified copies, DRM/signing lock-in) are incompatible with the freedoms GPLv3 grants, and the FSF documents the App Store as an unsupported channel for GPLv3 software. On iOS/iPadOS the App Store is effectively the only realistic distribution route, so this had to be resolved before Phase 4's sync work and the eventual store submission (issue #46).

MIT rather than Apache 2.0 — both are permissive and resolve the App Store conflict, the only substantive difference being Apache's patent grant: at solo-author scale that clause is dormant, MIT is the more idiomatic choice in the Swift/App Store ecosystem, and it's the shortest license (least friction for anyone adopting or vendoring pieces). Revisit the choice if the project ever grows a team of contributors.

One license for the whole monorepo: the API is never distributed via the App Store (own VPS, own app), but a per-component split would only add maintenance surface for no benefit. Relicensed as sole copyright holder — no third-party contributions existed, so no consents were needed; the repo's earlier commits retain the old GPL-3.0 `LICENSE` in git history.

## Implementation plan

Ordered as vertical slices — each phase leaves the app in a working, testable state rather than building all data layer, then all UI, then all AI.

Each item has its acceptance criteria and a short status: when it was done, what's left and its known limits. The dated notes behind each status (checks on devices, issue fixes, TestFlight stages) are in [`docs/history/`](docs/history/), one file per phase, linked from each item.

**Open now:**
- **4.2 Sync status in Settings:** the in-app check on a TestFlight build in iCloud mode.
- **12.4 TestFlight → production rollout:** `v1.1.0` is in the external beta (Stage 2), then App Review (Stage 3) and release (Stage 4). The real-iPad checks are in #219.
- The undecided items at the end of this file.

### Phase 1: Foundation
- [x] **1.1 Project scaffold** — new SwiftUI multiplatform app targeting macOS, iPadOS, iOS. One shared codebase, one target per platform.
  Acceptance: app builds and runs on all three platform simulators/destinations with an empty root view.
- [x] **1.2 SwiftData model layer** — `Recipe`, `IngredientLine`, `Tag`, `DensityEntry` models per the data model above, local-only (no CloudKit yet).
  Acceptance: models compile, a recipe with ingredients and tags can be created and fetched in a unit test or preview.
- [x] **1.3 Recipe list + detail view (read-only)** — basic list of saved recipes, tapping one shows title/ingredients/steps.
  Acceptance: seeding a couple of sample recipes via SwiftData shows them correctly on all three platforms.
- [x] **1.4 Visual design pass** — define the app's visual identity (color palette, typography, iconography, spacing/layout conventions) and apply it to the recipe list/detail views built in 1.3, replacing default system styling.
  Acceptance: recipe list and detail views reflect a deliberate, documented visual style that reads consistently across macOS, iPadOS, and iOS.

**Checkpoint:** app runs on Mac, iPad, iPhone with the app's visual design applied; sample recipes persist and display. Review before continuing.

### Phase 2: Manual entry & review screen
- [x] **2.1 Structured entry/edit form** — title, ingredient lines (amount, unit, name, raw text), steps. This is both the no-AI fallback and the review screen every capture path lands on later.
  Acceptance: a recipe can be created, edited, and deleted entirely by hand; changes persist via SwiftData.

**Checkpoint:** full manual CRUD works end-to-end on all platforms.

### Phase 3: Tagging
- [x] **3.1 Tag model + assignment UI** — preset tags shipped in-app, custom tag creation, multi-tag assignment on the entry/edit form.
  Acceptance: a recipe can carry multiple tags mixing presets and custom ones; tags persist.
- [x] **3.2 Filter recipe list by tag** — simple filter/segmented control on the list view.
  Acceptance: selecting a tag narrows the list to matching recipes; clearing it restores the full list.
  Status: done. Since 1.1 (#211), a custom tag no recipe uses is deleted after a save or delete, and Delete Tag on a custom chip takes it off every recipe; the five presets always stay. Known limit: if two devices edit before syncing, a recipe can lose a tag. Not built: renaming a tag, a Manage Tags screen. [History](docs/history/phase-03-tagging.md#32)

**Checkpoint:** tagging usable end-to-end.

### Phase 4: Settings & iCloud sync
- [x] **4.1 Settings screen with storage toggle** — Local vs. iCloud choice, wired to SwiftData's CloudKit-backed store.
  Acceptance: switching to iCloud migrates existing recipes and they appear on a second signed-in device/simulator; switching back leaves a local-only copy.
  Status: done 2026-10-15 on the `v1.0.1` TestFlight builds. Design: `app/docs/plans/2026-09-30-phase-4-1-icloud-sync-design.md`. Signing and the iCloud entitlements live in the gitignored `app/Config/Signing.xcconfig`, so builds without it (CI) have the setting disabled. The production CloudKit schema is deployed and only allows adding fields, so a model change must be a new field that older app versions can sync without. [History](docs/history/phase-04-settings-icloud-sync.md#41)

- [ ] **4.2 Sync status in Settings** — while storage is iCloud, Settings → Storage says when recipes last synced, or why sync isn't working, instead of failing silently (#208, after #207 in 12.4 Stage 1).
  Acceptance: a failed export shows an error within a few seconds, both in a test that posts a failed event and in the app; healthy sync shows the time of the last successful sync; nothing changes while storage is Local; all new text is in the five languages.
  Status: built 2026-10-24 (#245). Left: the in-app check on a TestFlight build in iCloud mode. "Last synced" should show within seconds of launch, airplane mode should show the grey waiting row and signing out of iCloud the red one, and switching to On This Device should hide the row, which still updates after switching back. The new strings need the native-speaker check. [History](docs/history/phase-04-settings-icloud-sync.md#42)

**Checkpoint:** sync verified across two devices/simulators.

### Phase 5: AI-powered capture — typed text
- [x] **5.1 "Type it" entry point** — text field for pasting/typing a raw recipe, feeds Apple Intelligence to structure it into title/ingredients/steps, lands on the Phase 2 review screen pre-filled.
  Acceptance: typing a real recipe produces a correctly structured, editable result; saving stores it like any manual recipe.
  Status: done 2026-10-02 (#76), checked against the samples in `app/docs/capture-samples/`. The mapping parses amounts as written (fractions, "100g", thousands separators, #216), reads compound amounts from the line (`CompoundAmount`, #216), keeps equipment in its own list (#82), drops invented ingredients and repeated lines, and the review screen shows a line under its fields when they don't match it (#215). Known limits:
  - A German three-decimal amount of a small unit ("2,500 g" meaning 2.5 g) reads as 2500, and "1.000 g" reads as 1.
  - An amount restated within one system is added up ("1 cup 8 fl oz milk" reads as 2 cups).
  - A sentence listing the ingredients can come through as the first step; the user removes it on the review screen.
  - If the model rephrases both the line and the name, a real ingredient is dropped without a sign on the review screen.
  - A step that equals the end of the step before it is dropped.

  [History](docs/history/phase-05-typed-capture.md#51)
- [x] **5.2 No-Apple-Intelligence fallback** — detect unsupported devices, skip straight to the blank Phase 2 form.
  Acceptance: on a simulator/device without Apple Intelligence, the "Type it" flow opens the blank form instead of erroring.

**Checkpoint:** typed capture works on supported and unsupported hardware.

### Phase 6: AI-powered capture — URL
- [x] **6.1 "Paste a link" entry point** — fetch page content, hand to Apple Intelligence to extract just the recipe, land on the same review screen pre-filled.
  Acceptance: pasting a real recipe URL produces a correctly structured, editable result with ads/backstory/comments excluded.
  Status: done 2026-09-27 (#74, #75). A page's schema.org `Recipe` JSON-LD goes to the model when there is one, otherwise its plain text, cut to 6,000 characters. Since 1.0.3, a site behind a bot check is retried in a hidden web view (#225). Since 1.1, capture suggests up to three of the user's tags (#230). Known limits: a range such as "2 to 3 bananas" gets no amount, and no extraction has been run on plain-text fallback input yet. [History](docs/history/phase-06-url-capture.md#61)
- [x] **6.2 Add-recipe screen shows both options clearly** — "Type it" / "Paste a link" presented side by side, not hidden.
  Acceptance: both entry points are visible without extra taps from the main add-recipe screen.

**Checkpoint:** both capture paths (typed, URL) confirmed working; full v1 recipe-capture experience done.

### Phase 7: Localization
- [x] **7.1 String Catalog + automatic UI string resolution** — `Localizable.xcstrings` covering every user-facing UI string (screen chrome, alerts and error messages, and the preset tag names), translated to Spanish, French, German, and Dutch alongside the English base.
  Acceptance: switching the device/simulator language to any of the four translated locales shows translated UI chrome with no raw fallback keys or obviously broken layout.
  Status: done 2026-10-13. Native speakers reviewed the later strings (PRs #164 and #165); the owner accepted the 56 core strings as they are. New strings are drafts until a native-speaker check before they go beyond internal testing. [History](docs/history/phase-07-localization.md#71)
- [x] **7.2 Preset tag names localized, user tags untouched** — the 5 shipped preset tags (Breakfast, Lunch, Dinner, Dessert, Snack) display in the device's language via a stable English matching key; any tag a user creates or renames displays exactly as typed, never translated.
  Acceptance: a preset tag's display name changes with device language; a custom or renamed tag's name does not.
  Status: done. [History](docs/history/phase-07-localization.md#72)
- [x] **7.3 View-model error messages localized** — the 5 capture-failure messages in `RecipeCaptureViewModel`/`RecipeURLCaptureViewModel` resolve via the same String Catalog.
  Acceptance: triggering a capture failure while the device language is set to a translated locale shows the translated message, not English.
  Status: done, covered by `LocalizedCaptureErrorMessagesTests` and checked on device in German (2026-09-25). [History](docs/history/phase-07-localization.md#73)

**Checkpoint:** app fully navigable in English, Spanish, French, German, and Dutch; mechanism verified manually, translation quality flagged for human review before ship.

### Phase 8: Density API (.NET)
- [x] **8.1 API scaffold + `DensityEntry` model** — new .NET project (ingredient name → grams per millilitre; originally per cup, changed in #70), basic persistence. PostgreSQL chosen (via Podman), not SQLite.
  Acceptance: API runs locally, entries can be created/read directly against the database.
  Status: done. [History](docs/history/phase-08-density-api.md#81)
- [x] **8.2 Read endpoint + low-privilege key** — public-ish read endpoint gated by a read-only API key.
  Acceptance: requests with a valid read key succeed; requests without one, or with a write key used as read, still succeed only for reads — a request with no key fails.
  Status: done, covered by `WebApplicationFactory` integration tests. [History](docs/history/phase-08-density-api.md#82)
- [x] **8.3 Write endpoints + high-privilege key** — add/edit density entries, gated by a separate write key.
  Acceptance: write endpoints reject the read key; only the write key can create/edit entries.
  Status: done, covered by integration tests (including Testcontainers inserts and updates). [History](docs/history/phase-08-density-api.md#83)

**Checkpoint:** API works locally end-to-end with both key tiers enforced.

### Phase 9: Seed & deploy
- [x] **9.1 Seed data import** — one-off script loading existing public ingredient-density data into the database.
  Acceptance: common ingredients (flour, sugar, butter, etc.) return sensible density values from the read endpoint; every seed entry records its source (see below).
  Source: [USDA FoodData Central](https://fdc.nal.usda.gov/) SR Legacy household portions (public domain, CC0 1.0), divided down to grams per millilitre, with each row's FDC ID and portion kept for re-checking. Don't seed from cooking sites' weight charts or the FAO/INFOODS database (issue #50). Seed rows go through the `DensityEntry` constructor so names are canonical (issue #55).
  Status: done 2026-09-28: 72 rows (`UsdaSeedData`), loaded by `src/RecipeRaccoon.DensityApi.Seed`, which only inserts missing names. Translated names were added 2026-10-16 (11.2). [History](docs/history/phase-09-seed-deploy.md#91)
- [x] **9.2 Deploy to Ubuntu VPS** — API running as a service on the existing 26.04 VPS, reachable over HTTPS.
  Acceptance: read endpoint reachable from outside the VPS over HTTPS with the read key; write endpoints not reachable without the write key.
  Status: done 2026-09-29. Runbook: `api/docs/deploy.md`. Deploys run by hand (`.github/workflows/deploy-api.yml`), after any migration is applied from a Mac through an SSH tunnel. The read endpoint is rate limited, because the read key ships in the app. [History](docs/history/phase-09-seed-deploy.md#92)

**Checkpoint:** API live and seeded; ready for the client to consume.

### Phase 10: Client density integration
- [x] **10.1 Local density cache** — client fetches entries from the read endpoint and caches them on-device (SwiftData or a lightweight store).
  Acceptance: after one fetch, density lookups work with network off.
  Status: done 2026-10-01 (design: `app/docs/plans/2026-10-01-phase-10-1-density-cache-design.md`). Name lookups normalize like the API's `IngredientNames.Canonicalize` (NFC, trim, case-insensitive; issue #55). The host and read key come from the gitignored `app/Config/DensityAPI.xcconfig`. [History](docs/history/phase-10-client-density.md#101)
- [x] **10.2 Periodic + manual refresh** — background periodic check for new/changed entries, plus a manual "refresh now" action in Settings.
  Acceptance: adding a new entry via the write API and triggering manual refresh brings it into the app's cache without reinstalling.
  Status: done 2026-10-01 (design: `app/docs/plans/2026-10-01-phase-10-2-density-refresh-design.md`). The app refreshes when it becomes active and the last refresh is over a day old, and Settings → Ingredient Densities has Refresh Now. Changes are found by `lastModifiedUtc`; add a `?since=` endpoint only if the full `GET` stops being cheap. [History](docs/history/phase-10-client-density.md#102)

**Checkpoint:** density data flows from API to client cache reliably.

### Phase 11: Unit conversion
- [x] **11.1 Volume/weight toggle on recipe view** — converts each ingredient line using its cached density entry.
  Note: density entries are grams per millilitre, so the conversion first turns the line's volume into millilitres. Which cup that means (US 236.6 ml vs metric 250 ml) is a client-side decision (e.g. defaulting from the device locale), not baked into the stored data.
  Acceptance: toggling shows correct gram values for ingredients with density data.
  Status: done 2026-10-01 (design: `app/docs/plans/2026-10-01-phase-11-1-weight-toggle-design.md`). The toggle is As Written / Weight, one way (volume to grams). Cup and spoon sizes are a setting in Settings → Measurements, defaulting from the device's region. Name matching is strict: it never substitutes a related ingredient. [History](docs/history/phase-11-unit-conversion.md#111)
- [x] **11.2 Missing-density fallback** — ingredients without a cached density entry show their original measurement plus a "conversion not available" note instead of a guess.
  Acceptance: an ingredient known to be absent from the density table shows the fallback note, not a fabricated number.
  Status: done 2026-10-02. Since 2026-10-16, Dutch, German, French and Spanish ingredient names are seeded (`TranslatedSeedNames`, machine-drafted and due a native-speaker check), and a lookup retries without words that don't change a cup's weight (`WeightNeutralWords`). [History](docs/history/phase-11-unit-conversion.md#112)

**Checkpoint:** full v1 feature set complete — capture, tag, store/sync, convert.

### Phase 13: Recipe photos
Added 2026-10-07, before the first release, and done before Phase 12 despite its number (Phase 12's numbering is referenced elsewhere, so it isn't renumbered). Photos add a CloudKit record type, so they must land before 12.4 deploys the schema to production, after which it can only grow. Design: `app/docs/plans/2026-10-07-recipe-photos-design.md`.
- [x] **13.1 Photo storage** — `RecipePhotoModel` (position, image and thumbnail in external storage) linked to `RecipeModel` with cascade delete, sorted by `(position, id)` so concurrent reorders from two devices give the same order everywhere; domain `RecipePhoto` references without image bytes; `RecipePhotoRepository` loading bytes on demand; `ImageIOPhotoProcessor` (scales to 2048 px, 300 px thumbnail, JPEG without metadata); the Local ↔ iCloud copier carries photos.
  Acceptance: unit tests cover mapping, ordering (including the `id` tie-break and position normalization on save), cascade delete, the copier and the processor (orientation applied, no EXIF/GPS left, junk input rejected).
  Status: done 2026-10-07. [History](docs/history/phase-13-recipe-photos.md#131)
- [x] **13.2 Adding and arranging photos** — a Photos section in the recipe form: add from the photo library (all platforms) or the camera (iPhone/iPad with a camera), Make Cover, Move Left/Right, Delete; changes save or cancel with the recipe.
  Acceptance: photos added in the form are saved with the recipe in the chosen order, Cancel discards them, and the camera permission prompt is localized.
  Status: done 2026-10-08. [History](docs/history/phase-13-recipe-photos.md#132)
- [x] **13.3 Showing photos** — the cover as a list thumbnail, a gallery at the top of the recipe detail, and a full-screen viewer.
  Acceptance: UI tests cover the thumbnail, gallery and cover reordering; on a Mac and an iPhone in iCloud mode, photos and their deletion and reordering sync both ways.
  Status: done 2026-10-08 (PR #150). A photo takes about 1 MB, kept for sharp zoom (user, 2026-10-08). [History](docs/history/phase-13-recipe-photos.md#133)

**Checkpoint:** recipes carry photos on all three platforms, synced like the rest of the recipe.

### Phase 14: Welcome guide and About
Added 2026-10-08, before the first release, and done before Phase 12 like Phase 13, so it sits next to it. Design: `app/docs/plans/2026-10-08-welcome-guide-and-about-design.md`.
- [x] **14.1 Welcome guide** — shown once per device on first launch (existing installs see it once after updating): what Recipe Raccoon is, the ways to add a recipe (adapted to Apple Intelligence availability), cooking from a recipe, and what can be changed in Settings. Skip on every page; reopened from Settings → Show Welcome Guide, and on the Mac from the Help menu.
  Acceptance: the guide shows on a first launch and not after it's closed, reopens from Settings (and the Mac Help menu), page 2 matches capture availability, and all its text is in the five languages; UI tests never see it unless their scenario opens it.
  Status: done 2026-10-08. On the Mac it opens in its own window, not a sheet. [History](docs/history/phase-14-welcome-guide-about.md#141)
- [x] **14.2 About** — the idea behind the app, that it's open source (MIT) and doesn't track anyone, the version, and links to the GitHub repository and to reporting an issue. Settings → About Recipe Raccoon on iPhone and iPad; Recipe Raccoon → About Recipe Raccoon on the Mac.
  Acceptance: both links open the right GitHub pages, the version matches the build, the privacy text matches what the app does (and what 12.1's privacy labels will say), and all text is in the five languages.
  Status: done 2026-10-09. [History](docs/history/phase-14-welcome-guide-about.md#142)

**Checkpoint:** a new user is introduced to the app once, and anyone can find out why it exists, check its code and report a problem.

### Phase 15: Servings and scaling
Added 2026-10-16, after the 1.0.1 release. Design: `app/docs/plans/2026-10-16-servings-scaling-design.md`.
- [x] **15.1 Servings on a recipe** — an optional number of servings (1–99) on the recipe, stored and synced, set in the form.
  Acceptance: servings can be set, changed and cleared in the form, survive a relaunch and sync to another device; recipes from before have none. The `servings` field is deployed to the production CloudKit schema before the build that ships it.
  Status: done 2026-10-24 on `v1.1.0` (Stage 1). `CD_servings` is in the production schema. [History](docs/history/phase-15-servings-scaling.md#151)
- [x] **15.2 Servings from capture** — Apple Intelligence reads the number of servings (or a yield like "12 muffins") from typed text and web pages, kept only when it appears in the source.
  Acceptance: "Serves 4", "4–6 personen" and "Makes 12 muffins" give 4, 4 and 12; a number the source doesn't state as servings ("bake for 4 minutes", "4 eggs"), or doesn't contain at all, is dropped; web pages pass their `recipeYield` to the model.
  Status: done 2026-10-24 on `v1.1.0` (Stage 1). [History](docs/history/phase-15-servings-scaling.md#152)
- [x] **15.3 Scaling on the recipe screen** — a +/− servings control that scales the ingredient amounts for the moment (not saved), with kitchen-friendly rounding, the original line underneath, and the Weight view following; a "Set servings" prompt when the recipe has none.
  Acceptance: a recipe for 2 shown for 4 doubles every amount (rounded as the design says), lines without an amount stay as written, grams double in the Weight view, reopening shows the recipe's own number, and all new text is in the five languages.
  Status: done 2026-10-24 on `v1.1.0` (Stage 1). Known limit: a line captured with an amount of 1 for a vague unit ("snufje zout") scales to "1½ snufje zout". [History](docs/history/phase-15-servings-scaling.md#153)

**Checkpoint:** a recipe can be cooked for any number of servings without doing the arithmetic.

### Phase 12: Release & distribution
- [x] **12.1 App Store Connect setup + App Privacy labels** — register the app in App Store Connect and complete the mandatory App Privacy labels. The labels must be truthful: this app collects no user data (see the plan's privacy stance above), so the declaration is "data not collected".
  Acceptance: privacy labels submitted and passing review with a truthful no-data-collection declaration for all three platforms.
  Status: done 2026-10-09 (PR #162), redone 2026-10-14 for the Recipe Raccoon record. `app/docs/app-store-connect.md` lists every answer; the app ships a privacy manifest. App Review checks the label with the first submission (12.4). [History](docs/history/phase-12-release.md#121)
- [x] **12.2 Store assets** — app icon plus per-platform screenshot sets at every required size (macOS, iPadOS, iOS), built from real app captures, not mockups.
  Acceptance: every required screenshot slot for each platform is filled and renders correctly in a TestFlight build.
  Status: done 2026-10-14. The icon is generated from `app/Design/AppIcon`, and `app/Scripts/take-screenshots.sh` takes the screenshots (`app/docs/screenshots.md`). [History](docs/history/phase-12-release.md#122)
- [x] **12.3 Versioning and signing** — version/scheme management and signing wired into a single CI job, so producing a distributable build is one step. The Mac app ships through the Mac App Store only (decided 2026-10-07), so there's no Developer ID signing or notarization: pushing a `vX.Y.Z` tag starts an Xcode Cloud Release workflow that archives iOS and macOS with cloud-managed signing and uploads both to App Store Connect (`app/docs/release.md`).
  Acceptance: one tag push produces signed App Store builds for macOS and iOS/iPadOS that reach TestFlight.
  Status: done 2026-10-07, redone 2026-10-14 for the new bundle ID `com.neonpixel.reciperaccoon`. [History](docs/history/phase-12-release.md#123)
- [ ] **12.4 TestFlight → production rollout** — internal testing, then beta, then public release, with a short runbook for what to verify at each stage.
  Acceptance: v1 live in the public App Store on all three platforms.
  Status: the runbook is `app/docs/rollout.md` (Stage 0 before tagging, Stage 1 internal TestFlight, Stage 2 external beta, Stage 3 App Review, Stage 4 release). The CloudKit schema is in production (2026-10-15). Stage 1 passed on `v1.1.0` (2026-10-24), including the native-speaker check of its strings, and it was submitted for external testing the same day (Stage 2). Left: Stage 2, then App Review and release, and the real-iPad checks (#219: camera, iCloud sync, a narrow window). [History](docs/history/phase-12-release.md#124)

**Checkpoint:** Recipe Raccoon is publicly available on the App Store (macOS, iPadOS, iOS).

## Risks and open questions

| Risk | Impact | Mitigation |
|---|---|---|
| Apple Intelligence extraction quality on messy recipe sites | Medium — bad parses land in review screen, so nothing saves silently wrong, but frequent bad parses hurt the "no fluff" promise | Review screen is mandatory by design (Phase 2); revisit prompt/approach if quality is poor in testing |
| CloudKit sync edge cases (conflicts, migration) | Medium — sync bugs are hard to debug later | Schema made CloudKit-compatible ahead of Phase 4 (issue #48), while no real user data exists, avoiding a later local-store migration; test the Local↔iCloud switch explicitly in Phase 4 checkpoint across two devices before moving on |
| Density data coverage gaps | Low — explicitly handled by the fallback note (Phase 11.2) rather than silent wrong answers | None needed beyond the fallback already designed |
| Density Postgres data loss on the VPS (disk failure, accidental drop) | Low — the density table is small, hand-curated data, not user data; re-seeding from Phase 9.1's source is a viable fallback | Nightly `pg_dump` backup documented in `api/docs/deploy.md` (issue #47) |
| VPS/API becomes a single point of failure for conversion | Low — client caches locally, so downtime only blocks *new* density data, not existing conversions | Local cache (Phase 10.1) already covers this |
| No telemetry by design — failures are invisible until users report them | Medium — no field signal for Apple Intelligence extraction failure rates (Phases 5.1 / 6.1), density API outages or misbehavior as real users see them, or CloudKit sync failures (Phase 4); user complaints are the only feedback channel | Accepted trade-off to keep the app completely anonymous. Compensate with manual/semi-automated on-device verification before each release (Phase 12.4 runbook) and accept a slow feedback loop. If that loop proves too slow, revisiting the anonymity promise is a product decision, not a technical one |

## Open items / not yet decided

- Recipe search/browse UX (by tag, by ingredient) — not discussed yet, reasonable default (search + tag filter) assumed but not specced.
- Admin tooling for the density API beyond a basic script.
- If Swift Package Manager dependencies are ever added (a `Package.swift` shows up), add a `swift` ecosystem entry to `.github/dependabot.yml` — not there yet since there's nothing for it to check.
