# Phase 11: Unit conversion — history

The dated notes for Phase 11, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 11.1

**Volume/weight toggle on recipe view**

Acceptance: toggling shows correct gram values for ingredients with density data.

Note: density entries are grams per millilitre, so the conversion first turns the line's volume into millilitres. Which cup that means (US 236.6 ml vs metric 250 ml) is a client-side decision (e.g. defaulting from the device locale), not baked into the stored data.

Done 2026-10-01 (design: `app/docs/plans/2026-10-01-phase-11-1-weight-toggle-design.md`): an As Written / Weight toggle (user's choice: one-way, volume → grams; oz/lb/kg also shown in grams), cup and spoon sizes as a user setting in Settings → Measurements (US customary or metric; it defaults from the device's region, never the language — user decision 2026-10-02), strict name matching (case, hyphen/space and plural only; never a related ingredient). Verified in the iOS simulator (metric region, English UI, so metric 250 ml cups — the region default the setting now uses; recorded before the setting existed, when the standard came from the device's measurement system) against the cached seed densities: 2 cups all-purpose flour → 264 g, ½ cup sugar → 106 g, 1 cup milk → 258 g, 4 oz chocolate → 113 g; unweighable lines stay as written. Unit test: 1 US cup flour = 125 g.

## 11.2

**Missing-density fallback**

Acceptance: an ingredient known to be absent from the density table shows the fallback note, not a fabricated number.

Done 2026-10-02: in the Weight view, a volume line without a cached density keeps its measurement as written with a small "Conversion not available" note under it. Lines with nothing to convert ("2 eggs", "salt to taste") stay as written without a note. Covered by `IngredientLineTextTests` (the note and no gram value for a missing density; no note when there's nothing to convert) and checked in the iOS simulator: "1 tsp saffron threads" and "3 tbsp unsalted butter" (strict matching: not "butter") show the note.

Translated names (2026-10-16): a Dutch recipe (miljuschka.nl banana bread) showed the note on every spoon line, because the seed names are English only and the matching is strict. `TranslatedSeedNames` (api) adds the Dutch, German, French and Spanish names recipes use for the USDA rows, 360 names in all, each a seed row with the English row's FDC source and density (like "flour" repeating "all-purpose flour"). No app change: the app picks up new entries on its daily refresh or Refresh Now. Names whose usual product differs from the US one are left out (European mustard, instant "Trockenhefe"/"gedroogde gist", half-and-half, "sucre en poudre", which is powdered sugar in Belgium, Canada and Switzerland). Production needs the seed tool re-run (`api/docs/deploy.md` §8; it only inserts missing names). The names are machine-drafted and need a native-speaker check like the UI strings.

Weight-neutral words (2026-10-16): when a name finds nothing, the lookup tries again without words that don't change what a cup weighs (`WeightNeutralWords`, five languages): temperature (cold, lauwe, tiède…), "unsalted" (the butter entry is unsalted butter, so "unsalted butter" now converts), grades (extra virgin, virgen, pure), commas and brackets ("butter, softened", "boter (zacht)"), and, for fats and honey only, softening and melting (softened, melted, zachte, fondu, derretida…): a cup of melted chocolate chips weighs far more than a cup of chips, and "soft breadcrumbs" or "harina blanda" are other products. The words match with or without accents ("a temperature ambiante"). Words that change a cup's weight or name another ingredient still block a match: sifted, packed, chopped, fresh, whole, salted. Covered by `DensityNameIndexTests`.
