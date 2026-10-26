# Phase 13: Recipe photos — history

The dated notes for Phase 13, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 13.1

**Photo storage**

Acceptance: unit tests cover mapping, ordering (including the `id` tie-break and position normalization on save), cascade delete, the copier and the processor (orientation applied, no EXIF/GPS left, junk input rejected).

Done 2026-10-07: the photo model, mapping, `SwiftDataRecipePhotoRepository`, `ImageIOPhotoProcessor` and the copier, with no UI yet. The create and update use cases take the new photos' bytes (`newPhotos`). Tests cover everything in the acceptance criteria, plus a store saved before photos existed (as by the v0.1.0 TestFlight build), which opens with the photo schema, keeps its recipes and then takes photos. The processor tests draw their fixtures in code (camera-style JPEG with GPS, camera and date metadata and EXIF orientation 6, PNG, HEIC) and need no image files.

## 13.2

**Adding and arranging photos**

Acceptance: photos added in the form are saved with the recipe in the chosen order, Cancel discards them, and the camera permission prompt is localized.

Done 2026-10-08: the form's Photos section (`RecipeFormPhotosSection`) with `PhotosPicker` and a camera wrapper (`CameraPicker`). Picked photos are scaled down right away and kept in memory until Save, which passes them to the create and update use cases as `newPhotos`; Save is disabled while any photo is processing. `NSCameraUsageDescription` is localized in the new `InfoPlist.xcstrings`. Unit tests cover saving in the chosen order, leaving out deleted photos, not storing anything without a Save, failed photos, the arrangement actions (as accessibility actions; ViewInspector can't open context menus), and the translated strings, including the compiled camera prompt. The picker and the camera are system UI, so they get the manual device check in 13.3. `CameraPicker.swift` is excluded from coverage, because no simulator or test can open the system camera.

## 13.3

**Showing photos**

Acceptance: UI tests cover the thumbnail, gallery and cover reordering; on a Mac and an iPhone in iCloud mode, photos and their deletion and reordering sync both ways.

Done 2026-10-08 (PR #150): the list row's cover (`RecipeCoverThumbnail`), the detail gallery (`RecipePhotoGallery`) and the viewer (`PhotoViewer`), with `FetchPhotoImageUseCase` for the full images. The UI tests (`RecipePhotosUITests`) run on the `recipeWithPhotos` and `recipeWithPhotosDetail` scenarios, which seed red, green and blue photos and check screenshot colors: the row's cover and the gallery's first page on both platforms, and on iOS turning a gallery page and Make Cover through the form (a long press, which GitHub's macOS runner can't deliver). Device check passed 2026-10-08 on the Mac and the iPhone 12 in iCloud mode. Photos were added from the library on both devices and with the camera on the iPhone. The rest was read from the iPhone's store and its change history: photos added and deleted on the iPhone showed on the Mac; a photo added, a Make Cover and a delete on the Mac arrived on the iPhone (the same cover on both); every photo kept its bytes, and a deleted photo's file was removed. Switching the iPhone to Local copied the photos with their files, and switching back to iCloud kept them without duplicates. Measured size: about 1 MB per photo (764 KB–1.2 MB for real food photos at 2048 px), so a 10-photo recipe takes about 10 MB, twice the design's estimate. Kept as is (user, 2026-10-08): sharp gallery and zoom over half the storage.
