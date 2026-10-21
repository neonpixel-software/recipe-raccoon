# Phase 15: Servings and scaling — design

Source: `PLAN.md` Phase 15 (added 2026-10-16, after the 1.0.1 release).

Goal: a recipe knows how many servings it makes, and the recipe screen can
show it for more or fewer servings, with the ingredient amounts changed to
match.

## Scope decisions (user, 2026-10-16)

- **Scaling is temporary.** The +/− control changes only what the recipe
  screen shows. Reopening the recipe shows it at its own number of servings
  again. The saved recipe never changes, so rounding can't add up and nothing
  extra syncs.
- **Kitchen-friendly amounts.** Scaled amounts are rounded to what you can
  measure, and the original line stays visible under each scaled one.
- **No servings set: prompt.** A recipe without a number shows a "Set
  servings" button that opens Edit. The +/− control appears once it has one.
- **A yield counts as servings.** "12 muffins" or "1 loaf" is 12 or 1
  servings: scaling works by a factor either way. The label is "Servings" in
  every language; no separate "Makes".

Settled with them: scaling applies in the Weight view too, and steps and
equipment aren't scaled (rewriting free text is risky).

## Data

- `Recipe.servings: Int?`, nil when unknown, 1–99.
- `RecipeModel.servings: Int?`, an optional field, so it syncs through
  CloudKit and recipes saved before it existed (or by an older app version)
  read as nil.
- The new field must be deployed to the production CloudKit schema before the
  build that ships it reaches TestFlight (`app/docs/rollout.md`).

## Form

A "Servings" row of its own directly under the title field, above Photos.
Unset, it shows a "Set Servings" button that starts the number at 4; set, a
stepper from 1 to 99 and a clear button that goes back to unset. New recipes
start unset unless capture found a number.

## Capture

- `CapturedRecipeSchema` gets a `servings` field: "How many people or servings
  the recipe makes, as a whole number, if stated, else empty."
- The number is kept only when the source states it as servings, so the model
  can't invent one. The ingredient check (`IngredientDescriptors.appears`) is
  too weak here: a bare "4" occurs in almost any recipe ("bake for 4 minutes",
  step 4, "4 eggs"). The number has to appear as a whole number (also inside
  a range, "4–6" or "4-6") in one of these places, ignoring case and accents:
  - next to a servings word, before or after it, at most one word between:
    serves, serving(s), portion(s), people, persons; personen, porties;
    Portion(en), Personen; personne(s), part(s); persona(s), ración/raciones,
    porción/porciones, comensales ("Serves 4", "4–6 personen", "4 Portionen",
    "pour 6 personnes");
  - right after a yield word: makes, yield(s), ergibt, rinde ("Makes 12
    muffins", "Yield: 1 loaf");
  - right after "for", "voor", "für", "pour" or "para" at the start of a line,
    unless a time unit follows ("Voor 12 muffins", but not "For 4 minutes").
- A range takes the lower number. Anything that isn't a whole number from 1
  to 99 is dropped.
- URL capture: `RecipeStructuredData` passes the JSON-LD `recipeYield` into
  the text the model reads as a "Yield: …" line, so the rule above grounds it.

## Scaling

- The recipe screen keeps the shown number in its view model, starting at
  the recipe's number on every open. Factor = shown ÷ recipe's number.
- `IngredientLine.scaled(by:)` returns a copy with the amount multiplied and
  the text rewritten:
  - When the amount as written is at the start of `rawText` ("⅔ cup flour",
    "1 1/2 tbsp", "2.5 dl"), only that part is replaced.
  - Otherwise the line is built from amount, unit and name.
  - A line without an amount ("salt to taste", "a pinch") is unchanged.
- Rounding (shown amount only). The unit's group comes from the
  `MeasurementUnits` table, which already knows the units' spellings in all
  five languages. 15.3 adds which system each of its units belongs to rather
  than starting a second table:
  - A tie goes to the smaller amount in every group (375 g shows 370 g).
  - Cups and spoons: a whole number plus the nearest of 0, ¼, ⅓, ½, ⅔ or ¾.
    Spoons below 1 can also be ⅛. An amount already on a step stays exact
    (⅔ × 2 = 1⅓). A tie goes to the smaller amount (5/12 is as close to ⅓ as
    to ½, and shows ⅓).
  - Metric units (ml, cl, dl, l, g, kg, mg): whole numbers, tens above 100.
  - Other imperial and US units (fl oz, pints, quarts, gallons, ounces,
    pounds): one decimal.
  - Counted: no unit, or a unit `MeasurementUnits` doesn't know ("clove",
    "can"): nearest ½.
  - A non-zero amount never rounds to 0; it shows the smallest step instead.
  - The text shows the amount the way the form's Amount field does, with
    `IngredientAmountFormatter` ("1⅓", "⅛", "2.5"). It moves from
    Presentation to Domain so `scaled(by:)` can use it, and what it writes
    still reads back through `IngredientAmountParser`, which moves from Data
    to Domain as well (`scaled(by:)` reads the amount at the start of the
    text with it).
- The Weight view converts the scaled lines, so grams follow. Grams come from
  the exact scaled amount, not the rounded one.
- Known limit: units keep their singular or plural form as written ("1 cup"
  → "2 cup"). Plurals in five languages can come later if it bothers.

## Recipe screen

- Above the ingredients: `Servings  [−] 4 [+]`. When the shown number differs
  from the recipe's, "(recipe: 2)" and a reset button appear.
- Scaled lines show the scaled text, with the original line under it in the
  small grey style the Weight view uses. At the recipe's own number nothing
  extra shows.
- No number: a "Set servings" button that opens Edit.

## Testing

- Unit:
  - `IngredientLine.scaled(by:)`: replacing the amount in the text (whole,
    decimal, "½", "1 1/2"), building the line when the amount isn't in the
    text, unchanged lines without an amount, each rounding group
    (also with a unit in another language and an unknown unit), exact steps,
    the tie rule, never 0.
  - Capture: "Serves 4", "4–6 personen", "4-6 Portionen", "Makes 12
    muffins", "Voor 12 muffins" and a "Yield: 1 loaf" line from JSON-LD are
    kept. A number found only in "Bake for 4 minutes", "For 4 minutes, stir",
    a step "4." or "4 eggs" is dropped, as is one not in the source at all.
    Empty stays nil.
  - Storage: servings round-trips; a recipe without the field loads as nil.
  - Detail view model and view: +/− within 1–99, reset, "(recipe: N)" only
    when changed, the "Set servings" prompt, scaled grams in the Weight view.
  - Form: setting, changing and clearing servings.
- UI: a new `servingsDetail` scenario opens on the detail screen of a recipe
  for 2 with "⅔ cup flour" and "salt to taste". On iOS the test taps + twice
  and reads "1⅓ cup flour", the original line under it, "(recipe: 2)" and an
  unchanged "salt to taste". Clicks don't reach the app on GitHub's macOS
  runner (PLAN.md testing rules), so on the Mac the test checks only the
  start state ("Servings", 2, no "(recipe: …)"). The unit tests above cover
  the arithmetic, as with Make Cover in the photos tests (#150).
- Strings: "Servings", "Set servings", "(recipe: %lld)" and the reset label in
  the five languages, with a native-speaker check.
- On device: capture the miljuschka.nl banana bread and a French recipe,
  check the servings, scale in As Written and Weight, check iCloud sync
  between the iPhone and the Mac.

## Delivery

Three PRs:

1. Model, storage and form (15.1).
2. Capture (15.2).
3. Scaling and the recipe screen (15.3).
