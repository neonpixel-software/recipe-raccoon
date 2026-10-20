# Rollout: TestFlight to the App Store

PLAN 12.4. What to do and check at each stage of a release, after `release.md` has produced the
builds. Stages 0 and 4 also apply to later releases; the one-time steps are marked.

Each stage has a gate: don't move on until every check passes. If one fails, fix it on `main`, bump
the version (`release.md`) and start the stage again with the new build.

## Stage 0: before tagging

**CloudKit production schema (one-time, before the first release).** Release builds sync through
the production CloudKit environment, which starts empty, so the app can't save to iCloud until the
schema is deployed there. Once it's deployed, fields can only be added, never renamed or removed
(PLAN 4.1), so deploy it with everything the first release needs.

CloudKit adds a field to the development schema only when a record with that field filled in
syncs. So first fill in every field once:

1. Run a development build with iCloud on (README: copy `Signing.xcconfig.example` to
   `Signing.xcconfig`) on a real device: PLAN 4.1 explains why the simulator can't sync while the
   Apple Account has Advanced Data Protection. Add one recipe that sets every synced field:
   - from **Paste a Link**, so it has a `sourceURL`
   - with an ingredient that has an amount, a unit and a name (e.g. "2 cups flour")
   - with equipment, steps, a preset tag and a custom tag
   - with two photos, so the image and thumbnail data and positions sync
2. In the [CloudKit console](https://icloud.developer.apple.com), container
   `iCloud.com.neonpixel.reciperaccoon`, Development → Schema → Record Types, check that these exist
   with all their fields. Core Data's CloudKit mirroring, which SwiftData uses, prefixes both the
   record types and the fields with `CD_`:

   | Record type | Fields |
   |---|---|
   | `CD_RecipeModel` | `CD_id`, `CD_title`, `CD_steps`, `CD_equipment`, `CD_isTypedSource`, `CD_sourceURL` |
   | `CD_IngredientLineModel` | `CD_id`, `CD_rawText`, `CD_amount`, `CD_unit`, `CD_ingredientName`, `CD_position`, `CD_recipe` |
   | `CD_TagModel` | `CD_id`, `CD_name`, `CD_isPreset` |
   | `CD_RecipePhotoModel` | `CD_id`, `CD_position`, `CD_imageData`, `CD_imageData_ckAsset`, `CD_thumbnailData`, `CD_thumbnailData_ckAsset`, `CD_recipe` |
   | `CDMR` | `CD_entityNames`, `CD_recordNames`, `CD_relationships` |

   A relationship is a field only on its to-one side (`CD_recipe`), so the recipe has no
   ingredients, tags or photos fields. The recipe–tag links are many-to-many, and those sync as
   `CDMR` records, which is why a tagged recipe is part of step 1. The photo's image and
   thumbnail each need two fields: Core Data's mirroring puts large data in a CloudKit asset
   (`_ckAsset`) and small data inline (Bytes), so which one a recipe creates depends on the
   photo's size. If one of the four is missing, add it by hand in the development schema
   (`CD_imageData` and `CD_thumbnailData` as Bytes, the `_ckAsset` ones as Asset) before
   deploying. A missing one stops a device's sync completely (see below). Other fields can be
   there too; what matters is that every field in the table is there. A `Users` record type is
   there too: CloudKit creates it in every container, and the app doesn't use it.
3. **Deploy Schema Changes…** to production, and check that the production record types match.

Done 2026-10-15 for the first release. The recipe was added in a development build on the Mac,
because Paste a Link needs Apple Intelligence and the iPhone 12 doesn't have it. Its photos
were large, so only `CD_imageData_ckAsset` and `CD_thumbnailData` were created and deployed. In
Stage 1 the iPhone added a smaller photo and CloudKit rejected the upload: "Cannot create or modify
field 'CD_imageData' in record 'CD_RecipePhotoModel' in production schema". The whole batch failed
and the iPhone's mirroring stopped until the app was relaunched, so nothing more from it synced.
`CD_imageData` and `CD_thumbnailData_ckAsset` were added in development and deployed the same day,
and after a relaunch the iPhone synced again.

`DensityEntryModel` isn't listed: it's a local cache and never syncs.

**Density API.** `https://<api-hostname>/health` returns 200 (`api/docs/deploy.md`), and the host
and read key in Xcode Cloud's Release workflow are the production ones.

**App Store Connect.** For both iOS and macOS:
- App Privacy published ("Data Not Collected", `app-store-connect.md`); check it, `PRIVACY.md` and
  the privacy manifest against the code, as that doc asks before each release.
- The content rights answer given (`app-store-connect.md`) and the age rating done.
- Screenshots in every language (`screenshots.md`), and the listing text from
  `app-store-listing.md`, after the native-speaker check.
- The privacy policy translations (`PRIVACY.es.md`, `.fr.md`, `.de.md`, `.nl.md`) checked by
  native speakers too: App Store Connect already links each language to its translation.

**Version.** `MARKETING_VERSION` set to the release version, then tag (`release.md`).

## Stage 1: internal testing

The Release workflow puts both builds in TestFlight for the internal group. Install them from the
TestFlight app on an iPhone, an iPad and a Mac, signed in to the same Apple Account. Run every check
on each device unless it names one.

**First launch**
- The launch screen shows without a flash of another colour, then the welcome guide.
- The guide's pages read correctly; Settings → Show Welcome Guide opens it again.

**Adding recipes**
- **Type It** and **Paste a Link** on a device with Apple Intelligence: each fills the review
  screen, and nothing saves before Save. Try a link from a large recipe site.
- On a device without Apple Intelligence (or with it off): both explain that AI capture isn't
  available, and the form still works.
- **Enter Manually**: a recipe with ingredients, equipment, steps and tags saves and reopens
  unchanged, with the ingredient order kept.

**Cooking from a recipe**
- **Weight** shows grams for an English recipe ("2 cups flour"). This proves the build reaches the
  production density API; Settings → Ingredient Densities shows a recent update.
- Photos: add from the library on all three, take one with the camera on iPhone and iPad, set a
  cover, reorder, delete.
- Tags: preset and custom tags, filtering the list by tag.
- On iPad and Mac, the detail screen shows two columns in a wide window and one in a narrow one.

**iCloud (production)**
- Turn on iCloud in Settings on the iPhone and the Mac. Existing local recipes merge up, and each
  device shows the other's recipes, photos included.
- **The 4.1 check:** with the Mac app open and in front, edit a recipe on the iPhone. The edit must
  appear on the Mac within about a minute, without clicking the window. When it does, tick 4.1 in
  PLAN.md. If it doesn't, the push isn't arriving: compare with the development behaviour in the
  4.1 note before blaming the app.
- Delete a recipe on one device; it disappears on the other.
- Switch one device back to Local: its recipes stay, and later edits there don't sync.

**Languages.** Set a device to Spanish, French, German and Dutch in turn: the UI, preset tags and
guide are translated, with no English left over and nothing cut off.

**Gate:** every check passes on the build that will be submitted.

## Stage 2: external beta

1. TestFlight → External Testing: add a group and the build. The first build needs Beta App
   Review, so fill in Test Information: what to test (the capture paths, Weight, iCloud), a
   feedback email, and that no sign-in is needed. iOS and macOS are reviewed separately. The
   texts are below, under Test Information.
2. Invite testers, ideally with different devices, including some without Apple Intelligence and
   some writing recipes in Spanish, French, German or Dutch.
3. Run the beta for about a week. Each day, check TestFlight feedback and crashes (App Store
   Connect → TestFlight → Crashes, or Xcode → Organizer → Crashes).

**Gate:** no crash or data loss left open, and the feedback has nothing that blocks release.

### Test Information

The texts used for 1.0.3, ready to paste. They're in English; TestFlight can take localized
versions too. Update What to Test when a build has something new to try.

**Beta App Description**

> Recipe Raccoon is a recipe box without the fluff: no ads, no life stories, just the recipe. Paste
> a link to a recipe site or type a recipe in, and Apple Intelligence sorts it into ingredients,
> equipment and steps on your device. Add photos and tags, switch ingredients to grams, and sync
> your recipes through your own iCloud if you like. Available in English, Spanish, French, German
> and Dutch.

**What to Test**

> Thanks for testing! Please try:
> - **Paste a Link:** recipes from sites you actually use, especially big recipe sites and blogs.
>   Tell us if one fails or comes out wrong (missing ingredients, mixed-up steps).
> - **Type It:** paste or type a recipe as plain text, for example from a message or a note.
> - **Enter Manually,** editing a recipe, photos (library and camera) and tags.
> - **Weight:** switch an ingredient list from cups and spoons to grams. Tell us about ingredients
>   it doesn't know.
> - **iCloud:** turn it on in Settings with two devices on the same Apple Account. Recipes, edits,
>   photos and deletes should show up on the other device.
> - **Your language:** if your device is set to Spanish, French, German or Dutch, look out for
>   wrong or awkward translations.
>
> Paste a Link and Type It need a device with Apple Intelligence turned on; without it, you can
> still enter recipes by hand. Send feedback with a screenshot from TestFlight (take a screenshot
> in the app and tap Share Beta Feedback), or open an issue at
> https://github.com/neonpixel-software/recipe-raccoon/issues.

**Privacy Policy URL:** https://github.com/neonpixel-software/recipe-raccoon/blob/main/PRIVACY.md

**Beta App Review Information:** sign-in not required, the owner's contact details, and these
notes (also the App Review notes in Stage 3):

> No account or sign-in. Paste a Link and Type It use Apple Intelligence on the device (Foundation
> Models), so on a device without Apple Intelligence the app explains that these aren't available
> and offers Enter Manually instead. iCloud sync is optional and off by default (Settings →
> Storage); recipes are stored on the device otherwise. To try Paste a Link, use any recipe page,
> for example https://www.allrecipes.com/recipe/21014/good-old-fashioned-pancakes/.

## Stage 3: App Review

For each platform (iOS covers iPadOS), in the version's page:
1. Select the tested build.
2. **App Review Information:** no sign-in. In the notes, explain that Type It and Paste a Link use
   Apple Intelligence on the device, so a device without it only offers Enter Manually, and that
   iCloud sync is optional and off by default. The Beta App Review notes in Stage 2 say this.
3. **Version Release:** *Manually release this version*, so all three platforms can go live
   together.
4. Submit for Review.

If App Review rejects a build, answer in Resolution Center. A metadata fix needs no new build; a code
fix goes through `release.md` and Stage 1 again.

**Gate:** both versions approved ("Pending Developer Release").

## Stage 4: release

1. Release both versions in App Store Connect on the same day.
2. Once they're live (this can take a few hours), install from the App Store on an iPhone, an iPad
   and a Mac (not over the TestFlight build), and run a short check: launch, add a recipe, Weight,
   iCloud sync between two devices.
3. Check the store pages in each language: name, subtitle, screenshots, description.
4. Publish the draft GitHub release for the tag (`release.md`, Cutting a release, step 4).
5. For the next few days, check crashes and ratings daily.

Tick 12.4 in PLAN.md once v1 is live on all three platforms.

For later releases, the CloudKit schema is already deployed: only a model change needs Stage 0's
schema steps again, and then only new fields (PLAN 4.1).
