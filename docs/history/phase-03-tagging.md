# Phase 3: Tagging — history

The dated notes for Phase 3, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 3.2

**Filter recipe list by tag**

Acceptance: selecting a tag narrows the list to matching recipes; clearing it restores the full list.

Unused tags (#211, for 1.1): a custom tag no recipe uses is deleted after every save or delete of a recipe, so a typo or a deleted recipe's tag leaves the filter row; the five presets always stay. It doesn't run after a CloudKit import, where a recipe can arrive before its tag. If two devices edit before syncing (one drops a tag's last use, the other adds it), the recipe can lose that tag; typing it again brings it back. A form whose tag was deleted meanwhile saves it again by name. Long-pressing a custom tag in the filter row (right-click on the Mac) offers Delete Tag, which after a confirmation takes it off every recipe; the recipes stay, and presets have no menu. No schema change. Rename and a Manage Tags screen stay open.
