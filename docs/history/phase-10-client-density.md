# Phase 10: Client density integration — history

The dated notes for Phase 10, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 10.1

**Local density cache**

Acceptance: after one fetch, density lookups work with network off.

Note: matching recipe ingredient names against the cache must apply the same normalization as the API's `IngredientNames.Canonicalize` (NFC + trim, `api/src/RecipeRaccoon.DensityApi.Domain/`) — the database's citext index only folds case, so whitespace and Unicode canonical form are significant in name matching (issue #55).

Done 2026-10-01 (design: `app/docs/plans/2026-10-01-phase-10-1-density-cache-design.md`): a separate local-only SwiftData store (`density.store`, no CloudKit) filled at launch when empty; lookups normalize names like the API (NFC, trim, case-insensitive) and never touch the network. The API host and read key come from a gitignored `app/Config/DensityAPI.xcconfig` (Xcode Cloud: secret workflow variables), so builds without it skip the fetch. Verified against production in the iOS simulator: the first launch cached all 72 entries; a relaunch made no request and kept the same rows. The offline lookup is covered by `RefreshDensityCacheUseCaseTests.testLookupsWorkOfflineAfterOneFetch`.

## 10.2

**Periodic + manual refresh**

Acceptance: adding a new entry via the write API and triggering manual refresh brings it into the app's cache without reinstalling.

Note: `DensityEntryResponse` already includes `lastModifiedUtc` on every entry (added ahead of this phase, after review flagged that adding it later would mean a schema migration plus an API contract change at the same time a client already depends on the shape). "New/changed" can be detected by diffing against the client's cached `lastModifiedUtc` per ingredient without needing a dedicated `?since=` endpoint — revisit only if the full-table `GET` stops being cheap enough at real seeded-data scale.

Done 2026-10-01 (design: `app/docs/plans/2026-10-01-phase-10-2-density-refresh-design.md`): "periodic" is a check whenever the app becomes active, refreshing when the last successful refresh is over a day old (no OS background task: `BGAppRefreshTask` is iOS-only and runs at the system's discretion). Settings → Ingredient Densities shows the last update and a Refresh Now button. A refresh applies the diff (insert new, update changed by `lastModifiedUtc`/density, delete removed) and overlapping refreshes share one download. Verified against the API running locally (user's choice, so production wasn't written to): the iOS simulator cached the 72 seeds, an entry added with the local write key didn't arrive on a relaunch within the day, and Refresh Now brought it in (73 rows, "Ingredient densities updated.").
