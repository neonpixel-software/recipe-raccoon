# Capture samples

Recipe texts for checking typed capture (PLAN.md 5.1, issue #76) against the on-device model.
They were written for this purpose and cover the cases that have gone wrong:

- `banana-bread-chatty.txt`: prose with ingredients in a sentence, steps in a paragraph, and
  chatter ("Enjoy!!"). The original report of steps leaking into ingredients.
- `crepes-fr.txt`: French. Its first step leaked into the ingredients with greedy sampling.
- `tomato-soup.txt`: a clean list with descriptors ("1 large yellow onion") and a step that
  names ingredients with amounts.
- `pancakes.txt`: a list followed by prose steps.
- `vinaigrette-de.txt`: German, terse; a control that should come out clean.

Output depends on the model version, so results are recorded with the date and OS in `docs/history/phase-05-typed-capture.md`.
