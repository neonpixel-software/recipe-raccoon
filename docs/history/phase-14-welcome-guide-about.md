# Phase 14: Welcome guide and About — history

The dated notes for Phase 14, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 14.1

**Welcome guide**

Acceptance: the guide shows on a first launch and not after it's closed, reopens from Settings (and the Mac Help menu), page 2 matches capture availability, and all its text is in the five languages; UI tests never see it unless their scenario opens it.

Done 2026-10-08: `WelcomeGuideView` with four pages (`WelcomeGuidePage`, plain data), driven by `WelcomeGuideViewModel`; the seen flag is `UserDefaultsWelcomeGuideStatus` (`hasSeenWelcomeGuide`), set however the guide closes. Full screen on an iPhone, a sheet on an iPad, and on the Mac its own window (a change from the design: Settings is a separate window there, so a sheet on the recipe window would open behind it). Reopened from Settings → Show Welcome Guide on all platforms and Help → Welcome Guide on the Mac. UI test runs and the unit tests' host app keep the flag in memory; only the `welcomeGuide` scenario shows the guide. VoiceOver reads each page as one element ending with its position, in the label, because the Mac doesn't read a group's value. Unit tests cover the flag, the pages with and without capture, the view's buttons and labels, the Settings entry and the translations; UI tests cover Next, swipe, Skip, Get Started and Settings → Show Welcome Guide on iOS, and the window layout on the Mac. Checked by hand on the Mac: the window at launch, Help → Welcome Guide, Settings → Show Welcome Guide and Skip; on an iPhone and an iPad simulator, in light and dark mode and in German. The de, es, fr and nl texts are drafts, under native-speaker review in #156.

## 14.2

**About**

Acceptance: both links open the right GitHub pages, the version matches the build, the privacy text matches what the app does (and what 12.1's privacy labels will say), and all text is in the five languages.

Done 2026-10-09: `AboutView`, with the links and version in `AboutInfo` (plain data; the URLs are in code, not the strings catalog). On iPhone and iPad it's pushed from Settings → About Recipe Raccoon; on the Mac, Recipe Raccoon → About Recipe Raccoon opens it in its own 540 × 760 pt window in place of the standard About panel. The links are pink buttons with ink text: pink text on cream is too faint. The privacy text was checked against the code again on 2026-10-09: the only ways online are still `URLSessionWebPageFetcher`, `URLSessionDensityEntryRemoteSource` (which sends only the app's read key) and CloudKit, and no Info.plist has an App Transport Security exception. Unit tests cover the URLs, the version, the link destinations, the Settings row and the translations. Checked by hand on the Mac (English and German) and on an iPhone simulator (light and dark). The de, es, fr and nl texts are drafts, under native-speaker review in #156.
