# Phase 12: Release & distribution — history

The dated notes for Phase 12, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 12.1

**App Store Connect setup + App Privacy labels**

Acceptance: privacy labels submitted and passing review with a truthful no-data-collection declaration for all three platforms.

Done 2026-10-09 (PR #162). `PRIVACY.md` is the privacy policy URL; `app/docs/app-store-connect.md` lists every App Store Connect answer and why "Data Not Collected" is true; the app ships a privacy manifest (`PrivacyInfo.xcprivacy`: no tracking, no collected data, `UserDefaults` reason CA92.1); nginx in front of the density API keeps no access log (`api/docs/deploy.md` §6). `access_log off` is applied on the VPS, and the answers are entered and the App Privacy section published in App Store Connect ("Data Not Collected"). App Review checks the label with the first submission (12.4).

Redone 2026-10-14 in the new App Store Connect record (bundle ID `com.neonpixel.reciperaccoon`, renamed Recipe Raccoon because Pocket Chef was taken): the App Privacy answers are entered and published ("Data Not Collected"), with the privacy policy URL set, per language, to `PRIVACY.md` or its Spanish, French, German or Dutch translation (PR #199), and the age rating and app information are entered again. The translations are drafts until the native-speaker check before submission (12.4, `app/docs/rollout.md` Stage 0). App Review checks the label with the first submission (12.4).

## 12.2

**Store assets**

Acceptance: every required screenshot slot for each platform is filled and renders correctly in a TestFlight build.

App icon done (2026-10-12): a raccoon in a chef's hat, as an Icon Composer file (`AppIcon.icon`) with light, dark, tinted and clear looks on iOS, iPadOS and macOS; generated from `app/Design/AppIcon` (README there).

Screenshots (2026-10-12): `app/Scripts/take-screenshots.sh` takes them from the real app with a UI test in a fixed scenario (`UITestScenario.screenshots`: six recipes with CC0 stock photos, in each language), for iPhone (1206 × 2622), iPad 13" (2064 × 2752) and Mac (16:10) in all five languages; `app/docs/screenshots.md` covers running, uploading and the photo credits. The weight view is in the English set only, since density lookups need English ingredient names. Done 2026-10-14: the screenshots are uploaded to every slot of the new Recipe Raccoon record in all five languages (iPhone, iPad and Mac) and show as finished thumbnails in App Store Connect, French included (the earlier uploads to the old record stuck on "processing"), and the `v0.1.0` TestFlight builds show the icon on iOS and macOS. The TestFlight app doesn't show App Store screenshots, so for them "renders correctly" is checked in App Store Connect. The listing text and the content rights answer are entered too (`app/docs/rollout.md` Stage 0).

## 12.3

**Versioning and signing**

Verified 2026-10-07: the `v0.1.0` build reached TestFlight on iOS and macOS.

Acceptance: one tag push produces signed App Store builds for macOS and iOS/iPadOS that reach TestFlight.

Redone 2026-10-14 for the new bundle ID and App Store Connect record (Recipe Raccoon): the App ID `com.neonpixel.reciperaccoon` and container `iCloud.com.neonpixel.reciperaccoon` were registered through a signed Xcode build, Xcode Cloud got a new product, RecipeRaccoon (named after the iOS target's product name, PR #182), with its TestFlight and Release workflows, and the `v0.1.0` tag on `ab50295` produced iOS and macOS builds that reached TestFlight in the new record.

## 12.4

**TestFlight → production rollout**

Acceptance: v1 live in the public App Store on all three platforms.

Runbook: `app/docs/rollout.md` (2026-10-13): Stage 0 before tagging (including the one-time CloudKit production schema deploy, with every synced field filled in once first), Stage 1 internal TestFlight checks on iPhone, iPad and Mac (including the 4.1 push check below), Stage 2 external beta, Stage 3 App Review, Stage 4 release.

Order: deploy the CloudKit schema to production only after Phase 13 (recipe photos) has merged, because the production schema can't drop or rename what's deployed.

Progress (2026-10-15): the CloudKit schema is deployed to production. Every field in the rollout.md table was checked in the development schema first, from one recipe that filled every synced field in a development build on the Mac, and after the deploy the same record types are in production. The density API's `/health` returned 200 the same day. The owner confirmed the rest of Stage 0 the same day: native speakers checked the listing text and the privacy policy translations, Xcode Cloud's Release workflow has the production density host and read key, and the App Store Connect items are done for both platforms (App Privacy, content rights answered No, age rating, screenshots). Only the version (1.0.0, #206) and the tag are left.

Stage 1 (2026-10-15): `v1.0.0` reached TestFlight. iPhone-to-Mac sync stopped after the first recipe: production was missing `CD_imageData` and `CD_thumbnailData_ckAsset`, because a photo syncs inline or as an asset depending on its size and the Stage 0 recipe only created the asset variant for the image. Both fields were added and deployed, and sync works again; rollout.md's table now lists all four photo fields.

The 4.1 push check failed on `v1.0.0`: an iPhone edit only reached the Mac after a click, because the Mac app wasn't registered for remote notifications. `v1.0.1` (#209) fixes it, and the check passed on its TestFlight builds the same day (about a minute, no click), so 4.1 is checked off. The 1.0.0 build never leaves internal testing, and the draft GitHub release now points at `v1.0.1`.

Stage 1 on `v1.0.1` (2026-10-15): the owner ran the rollout.md checks on the iPhone and the Mac, and every one passed: first launch, adding recipes, Weight in grams, photos (camera, cover, reorder, delete), tags, iCloud sync both ways with photos, the 4.1 check, delete syncing, switching back to Local, and the four other languages. Left: the iPad checks (including the two-column detail screen), before Stage 2.

`v1.0.2` (2026-10-19) replaces 1.0.1 before the iPad checks, so Stage 1 tests what goes to the beta: the long-title fix (#212), translated ingredient names matched (#213, through the API) and weight-neutral words (#221), and error logging to the unified log (#223). No CloudKit schema change. Stage 1 runs again on the iPhone and the Mac (a short pass, including #212's long title) and in full on the iPad (#219); the draft GitHub release moves to `v1.0.2`, like it moved from 1.0.0.

`v1.0.3` (2026-10-20) replaces 1.0.2 so Stage 1 also tests Paste a Link on sites behind a bot check (#225): a 403, 429 or 503 is retried in a hidden web view, and if that's blocked too the app points to Type It. No CloudKit schema change. Same Stage 1 run as for 1.0.2, plus pasting a link from such a site (https://miljuschka.nl/het-beste-bananenbrood-recept-ooit/) on the iPhone and the Mac; the draft GitHub release moves to `v1.0.3`.

`v1.1.0` (2026-10-21) is the first build with the 1.1 work on `main`: unused custom tags deleted and Delete Tag on a chip (#211, #229), tag suggestions on capture review (#230, #231), and servings with scaling (Phase 15, #232–#234). The CloudKit schema gains `CD_servings`, already deployed to production the same day (15.1). Stage 1 runs on it in internal TestFlight while 1.0.3 waits in Beta App Review: the short iPhone and Mac pass, the full iPad run (#219), and the 1.1 checks: servings set in the form and syncing between the iPhone and the Mac both ways, scaling in As Written and Weight on the iPhone, Delete Tag, and tag suggestions on the Mac (the iPhone 12 has no Apple Intelligence). The new strings in Spanish, French, German and Dutch are drafts until the native-speaker check, which has to happen before this build goes beyond internal testing.

Stage 1 on `v1.1.0` passed (2026-10-24), the 1.1 checks included, and native speakers checked the new strings in the four languages. The build was submitted for external testing the same day and is in Beta App Review (Stage 2).
