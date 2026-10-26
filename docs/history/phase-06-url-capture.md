# Phase 6: AI-powered capture — URL — history

The dated notes for Phase 6, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 6.1

**"Paste a link" entry point**

Acceptance: pasting a real recipe URL produces a correctly structured, editable result with ads/backstory/comments excluded.

On-device check (2026-09-25, same Mac as 5.1): left unchecked — 3 of 4 real recipe sites tried (Allrecipes, Simply Recipes, Serious Eats) fail with `exceededContextWindowSize`: the 12,000-character plain-text cap is larger than the model's 4,096-token context, and most of that text is site navigation rather than the recipe (issue #74). BBC Good Food extracted correctly. HTTP error pages are also not rejected — a 404 page was captured as a recipe titled "ERROR 404" (issue #75). Check off once #74 and #75 are fixed and re-verified on device. Done 2026-09-27 (see below).

Fetch-layer limits (#49) verified on device: a >2 MB page (the WHATWG HTML spec) shows the "too large" message; a windows-1252 page (served locally) decodes with accents intact; a plain-HTTP-only site (`http://neverssl.com`) shows the "secure connection" message in the running app.

HTTP status since #75: non-2xx responses are rejected before the body is read and show the "Couldn't load that page" message. Verified on 2026-09-25 against the real fetcher: the budgetbytes.com 404 page and an HTTP 500 now throw `httpStatus`; BBC Good Food still fetches.

Model input since #74: pages embedding a schema.org `Recipe` JSON-LD block feed that to the model instead, reformatted as title/ingredients/steps; otherwise the page's plain text, with scripts, navigation and other site chrome stripped, is the fallback. Either input is truncated to 6,000 characters before the model call so it fits the on-device context window.

Re-verified on device (2026-09-27, same Mac, after #74 and #75): all four sites now extract correctly. Allrecipes (Good Old-Fashioned Pancakes), Simply Recipes (Banana Bread) and Serious Eats (Food Lab chocolate chip cookies) no longer hit the context limit, and BBC Good Food still works. All four pages have JSON-LD, so the model saw only the recipe (731–3,083 characters); no ads, backstory or comments got through. Ingredients, equipment and steps match the source, with two gaps the user fixes on the review screen: a range such as "2 to 3 bananas" gets no amount, and Serious Eats' title dropped "The Food Lab's". None of the four pages needs the plain-text fallback. #79 checked that path by stripping the JSON-LD from the same pages: the text then starts at the recipe title and fits the context window. No extraction has been run on fallback text yet.

Bot checks since #225: a site behind a bot check (miljuschka.nl, on Kinsta and Cloudflare) answers URLSession with a 403 "Just a moment…" page that needs JavaScript. After a 403, 429 or 503 the page is loaded once more in a hidden web view, which passes the check by itself in 4–7 s (17.6 s for the first load after the iOS simulator started). The view keeps no data between loads and blocks images, media, fonts and everything from other sites except Cloudflare's challenge (its script and `blob:` worker; the check fails without either). If the view ends on an error page that nothing follows within 5 s (a plain 403 or 429; a bot check starts within 0.4 s), or the check hasn't passed after 30 s, the user is told the site doesn't let apps read its pages and to paste the recipe into Type It.

Tag suggestions since #230 (for 1.1): after a capture from a link or from Type It, a second on-device model call picks the user's tags that fit the recipe from its title and ingredient lines, and the review screen starts with them selected. The answer is limited to the existing tag names (presets and custom), at most three, so it never makes a tag up; a failure leaves the recipe without tags. On the dev Mac (2026-10-20) with the presets it takes about 0.3 s and picked Breakfast for pancakes and crêpes, Dinner for tomato soup, Lunch for a vinaigrette and Dessert for banana bread.
