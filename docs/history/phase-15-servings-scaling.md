# Phase 15: Servings and scaling — history

The dated notes for Phase 15, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 15.1

**Servings on a recipe**

Acceptance: servings can be set, changed and cleared in the form, survive a relaunch and sync to another device; recipes from before have none. The `servings` field is deployed to the production CloudKit schema before the build that ships it.

Built 2026-10-20: `Recipe.servings` / `RecipeModel.servings` (optional, 1–99; a number outside that from another app version reads as unknown), and a Servings row under the title in the form ("Set Servings" starts at 4, a stepper, and a clear button). Strings in four languages are drafts for the native-speaker check. Left: the sync check between two devices, and `CD_servings` in the production schema (`app/docs/rollout.md` Stage 0 table) before the build that ships it.

2026-10-21: `CD_servings` (Int(64)) is in the production CloudKit schema. The owner added it by hand to `CD_RecipeModel` in the development schema and deployed it; a development build would have migrated and synced the owner's own store. Left: the two-device sync check, on the next TestFlight build.

Done 2026-10-24: servings set in the form synced between the iPhone and the Mac both ways on the `v1.1.0` TestFlight build (Stage 1, 12.4), and the native speakers checked the new strings.

## 15.2

**Servings from capture**

Acceptance: "Serves 4", "4–6 personen" and "Makes 12 muffins" give 4, 4 and 12; a number the source doesn't state as servings ("bake for 4 minutes", "4 eggs"), or doesn't contain at all, is dropped; web pages pass their `recipeYield` to the model.

Built 2026-10-21: the capture schema asks for the servings, and `CapturedServings` keeps the number only when the source states it next to a servings word (in the five languages), right after a yield word, or after "for" at the start of a line (not before a time unit); a range gives its lower number. JSON-LD's `recipeYield` goes to the model as a "Yield: …" line. On the dev Mac's model the six samples that state servings came back right ("4-6 personen" → 4, "12 muffins" → 12, "1 loaf" → 1), and the model's invented numbers for two recipes that don't were dropped. Left: an in-app check on a real web page.

Checked in the Mac app 2026-10-21 (main `1574d16`, the dev Mac's Apple Intelligence, an in-memory store): Paste a Link on the miljuschka.nl banana bread captured 10 servings. Left: nothing on iOS, since the iPhone 12 has no Apple Intelligence.

Done 2026-10-24 with the `v1.1.0` Stage 1 pass (12.4).

## 15.3

**Scaling on the recipe screen**

Acceptance: a recipe for 2 shown for 4 doubles every amount (rounded as the design says), lines without an amount stay as written, grams double in the Weight view, reopening shows the recipe's own number, and all new text is in the five languages.

Built 2026-10-21: `IngredientLine.scaled(by:)` and `IngredientAmountRounding` (Domain; the amount formatter and parser moved there too), with the rounding groups from `MeasurementUnits.scalingRounding(of:)`. The recipe screen has a Servings −/+ row above the As Written/Weight picker, "(recipe: N)" and a reset button once the number changes, the original line under each scaled one, and "Set Servings" (opens Edit) for a recipe without a number; the Weight view weighs the exact scaled amounts. New strings in four languages are drafts for the native-speaker check. Left: the on-device check (capture a recipe, scale it in As Written and Weight).

Checked in the Mac app 2026-10-21, on that banana bread scaled from 10 to 15 servings: As Written showed 190 gr boter, 370 gr bloem (375 is a tie), 90 ml melk, 1½ tl vanille-extract and 4½ rijpe bananen, each with the original under it, "handvol gehakte chocola of noten" unchanged, and "(recipe: 10)" with a reset button; Weight showed 188 g boter and 375 g bloem (from the exact amounts); reset went back to 10. One capture quirk: "snufje zout" came with an amount of 1, so it scales to "1½ snufje zout". Left: the iPhone check, on the next TestFlight build (a development build installed over the TestFlight app replaced the app's data container).

The snufje quirk is fixed in #252 (#251): a vague unit (pinch, snufje, Prise…) on a line without a written number gets no amount on capture, and scaling leaves such a line as written, which also covers recipes saved before the fix. A number written as a word ("two pinches") counts as no number.

Done 2026-10-24: scaling in As Written and Weight passed on the iPhone on the `v1.1.0` TestFlight build (Stage 1, 12.4), and the native speakers checked the new strings.
