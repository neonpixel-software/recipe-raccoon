# Security Policy

## Supported versions

| Component | Supported |
|---|---|
| Recipe Raccoon app (`app/`) | The latest App Store or TestFlight release, and the branch being prepared for the next one |
| Density API (`api/`) | `main` |

No App Store release is public yet, so for the app that means the latest TestFlight build.
Security fixes ship in the next regular release, or in a patch release when the severity
warrants it.

## Reporting a vulnerability

Use **Report a vulnerability** on this repository's
[Security tab](https://github.com/neonpixel-software/recipe-raccoon/security), or open a
[private report](https://github.com/neonpixel-software/recipe-raccoon/security/advisories/new) directly. The
report opens a private advisory that only you and the maintainers can see — nothing is
disclosed publicly until an agreed fix ships.

- Expect an acknowledgment within 3 business days, with updates as work progresses.
- The goal is to confirm or dismiss a report within 14 days, and to fix confirmed issues as
  quickly as is responsible.
- If the vulnerability is fixed, we will publish the advisory with the release that fixes it;
  if you prefer not to be credited, say so in the report.

## Scope

The app is local-first: recipes live in the user's own device storage and (optionally) their
private iCloud database, and recipe capture runs on-device with Apple Intelligence. The only
server component is the density API, which serves public ingredient density data.

Its read and write endpoints both require an API key, but the two keys play different roles:

- **Reads** use a read key built into the app, so it isn't a secret: it identifies the app and
  lets the API rate-limit reads. A report that the read key can be extracted from the app is
  expected and out of scope.
- **Writes** need a separate write key that only the server operator has.

In scope:

- The app (`app/`), including how it handles web content fetched from user-pasted URLs
- The density API (`api/`): writing without the write key (for example by escalating the
  read key), getting past the read rate limit, and input handling

Out of scope:

- iCloud and the Apple Intelligence pipeline — Apple-managed, under Apple's own policies
- Third-party websites the user pastes links to — the app fetches them directly and on-device,
  so their security posture is their own

## What we do not do

No telemetry, analytics, ads or accounts: there is no NeonPixel service holding user data to
breach. The density API's own logging policy is described in the [privacy policy](PRIVACY.md).
