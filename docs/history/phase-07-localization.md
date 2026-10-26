# Phase 7: Localization — history

The dated notes for Phase 7, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 7.1

**String Catalog + automatic UI string resolution**

Acceptance: switching the device/simulator language to any of the four translated locales shows translated UI chrome with no raw fallback keys or obviously broken layout. Manually verified on this Mac in Spanish and German (list, add-recipe chooser, recipe form) — no missing entries, no layout breakage, umlauts render fine. Left unchecked because translations are machine-generated in this environment and need a fluent-speaker quality pass before shipping — mechanism is verified here, not translation quality.

Done 2026-10-13. Native speakers reviewed the later strings and their fixes are applied: the capture errors, ingredient densities, measurements and photos (#65, PR #164), and the welcome guide and About (#156, PR #165). The 56 core strings from this phase (the recipe list, the recipe form, tags, the common buttons and the "AI capture unavailable" alert) weren't in either review; the owner accepted them as they are, since they're short, common UI words and the reviews found few problems elsewhere.

## 7.2

**Preset tag names localized, user tags untouched**

Acceptance: a preset tag's display name changes with device language; a custom or renamed tag's name does not. Verified manually in Spanish and German: presets translated (e.g. "Frühstück"), the custom "Refreshing" sample tag stayed in English in both.

## 7.3

**View-model error messages localized**

Acceptance: triggering a capture failure while the device language is set to a translated locale shows the translated message, not English. Catalog entries are unit-tested directly (`LocalizedCaptureErrorMessagesTests`), and verified on device (2026-09-25) with the app running in German: the typed-capture failure and all four URL-capture messages (too large, insecure connection, couldn't load, no recipe found) showed translated.
