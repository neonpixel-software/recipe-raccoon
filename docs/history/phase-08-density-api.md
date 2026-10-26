# Phase 8: Density API (.NET) — history

The dated notes for Phase 8, moved out of [PLAN.md](../../PLAN.md) word for word (#217): checks on devices, issue fixes and TestFlight stages, in the order they were written. Older notes can describe a state a later note replaced; PLAN.md has the current status.

## 8.1

**API scaffold + `DensityEntry` model**

Acceptance: API runs locally, entries can be created/read directly against the database. Verified end-to-end: real migration applied to a locally running Postgres (via Podman), entry inserted and read back via `psql`, the `/health` endpoint responds, and the Dockerfile image builds and runs correctly against the same Postgres.

`nuget` ecosystem entry added to `.github/dependabot.yml`.

## 8.2

**Read endpoint + low-privilege key**

Acceptance: requests with a valid read key succeed; requests without one, or with a write key used as read, still succeed only for reads — a request with no key fails. Verified via automated tests (unit + `WebApplicationFactory` integration tests covering all four cases) and manually end-to-end against the real running app and a real local Postgres.

## 8.3

**Write endpoints + high-privilege key**

Acceptance: write endpoints reject the read key; only the write key can create/edit entries. Verified via automated tests (`WebApplicationFactory` integration tests covering no key/read key/valid write key/invalid body, plus Testcontainers-backed insert and update-in-place cases) and manually end-to-end against the real running app and a real local Postgres via Podman — confirmed via `psql` that an upsert to an existing ingredient name updates the row in place rather than duplicating it.
