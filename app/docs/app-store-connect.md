# App Store Connect

What to enter in App Store Connect for Recipe Raccoon (PLAN 12.1), and why each answer is true.
The app record has bundle ID `com.neonpixel.reciperaccoon`. iOS and macOS share it, so the record
must list both platforms (App Information → add macOS if it's missing); iPadOS comes with iOS.

The app was first set up as Pocket Chef, bundle ID `com.neonpixel.pocketchef`. That name was
taken on the App Store, and a record's bundle ID can't change, so on 2026-10-13 the app moved to a
new record. Before that, register the App ID `com.neonpixel.reciperaccoon` with iCloud (container
`iCloud.com.neonpixel.reciperaccoon`) and Push Notifications in the developer portal, and set up
Xcode Cloud's product and Release workflow for the new record again (`release.md`). The old record
stays unused; it can't be deleted once a build was uploaded.

## App Privacy

Under **App Privacy**:

| Field | Value |
|---|---|
| Privacy Policy URL | `https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.md` |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Then **Publish**. The label then reads "Data Not Collected", which covers every platform of the
record. Apple checks it during App Review, so it's verified with the first submission (12.4).

The privacy policy URL is also required for the macOS platform: set it once under App Privacy,
not per platform. It is set per language, though: for each of the record's localizations, point
it at that language's translation of the policy, so a Spanish, French, German or Dutch user gets
it in their own language (the English version is the original and applies if they differ):

| Localization | Privacy Policy URL |
|---|---|
| English | `https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.md` |
| Spanish | `https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.es.md` |
| French | `https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.fr.md` |
| German | `https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.de.md` |
| Dutch | `https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.nl.md` |

Native speakers checked the translations before the first submission (2026-11-03), like the
store listing (`app-store-listing.md`).

### Why "Data Not Collected" is true

Apple counts data as collected when it leaves the device and the developer (or a partner) can
read it for longer than it takes to answer the request. Recipe Raccoon sends nothing of that kind:

| What leaves the device | Where it goes | Why it isn't collected |
|---|---|---|
| Recipes, tags, photos (only with iCloud sync on) | The user's private CloudKit database | Only the user can read it; NeonPixel can't. |
| A request for a pasted recipe link | The recipe's own website | Goes straight to that site, never through NeonPixel. |
| `GET /density-entries` with the read key | Recipe Raccoon's density API | Carries nothing about the user. nginx keeps no access log (`api/docs/deploy.md` §6), the API logs no requests, and the rate limiter holds the address in memory for one 60-second window. |

There are no third-party SDKs in the app: its only package, ViewInspector, is linked into the
unit tests and not shipped. Recipe capture runs on the device with Apple Intelligence.

The app's privacy manifest (`Sources/RecipeRaccoon/Resources/PrivacyInfo.xcprivacy`) says the same:
no tracking, no collected data types. It also declares the one required-reason API the app's own
code uses, `UserDefaults`, with reason `CA92.1` (read and written by the app itself only).

Before each release, check the About page's "No Tracking" list, `PRIVACY.md` and its four
translations (`PRIVACY.es.md`, `.fr.md`, `.de.md`, `.nl.md`), the label and the manifest against
the code (see "No tracking" in
`docs/plans/2026-10-08-welcome-guide-and-about-design.md`). Anything that changes what leaves
the device, such as a new SDK, crash reporting, or logging on the server, changes them all.

## App Information

| Field | Value |
|---|---|
| Name | Recipe Raccoon |
| Primary category | Food & Drink (matches `LSApplicationCategoryType` in `project.yml`) |
| Content rights | **No** (answered 2026-10-14): the app ships no third-party content. It fetches only recipe websites the user links to and keeps the recipe text they review, so the user, not the app, brings the content. |
| Age rating | Answer **None** or **No** to every question, which gives 4+. "Unrestricted web access" is **No**: the app only fetches a page to turn it into a recipe and never shows it. |

## Version information (per platform)

| Field | Value |
|---|---|
| Support URL | `https://github.com/neonpixel-software/recipe-raccoon/issues` |
| Marketing URL | `https://github.com/neonpixel-software/recipe-raccoon` (optional) |
| Copyright | `2026 NeonPixel` |

The subtitle, promotional text, description and keywords for each language are in
`app-store-listing.md`; the screenshots and where they go are in `screenshots.md`.

## Export compliance

Nothing to answer: `project.yml` sets `ITSAppUsesNonExemptEncryption = NO`, since the app only
uses HTTPS (`docs/release.md`).
