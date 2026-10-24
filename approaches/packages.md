---
title: PLX-Packages – releasing packages
short_title: PLX-Packages
description: How a package monorepo publishes — trunk-based on main, versioned by changesets, published token-less through OIDC trusted publishing with provenance, and designed to carry methodology and never substance.
code: PLX-Packages
maturity: candidate
binds: repo
depends: [PLX-Repo, PLX-JS]
order: 28
---

Apps release by deploy, keyed by SHA ([PLX-Train](train.md)).
Packages release into a registry, keyed by semver, and that different physics wants a different model.
This module is the one `plexus-ms/packages` uses; a tenant publishing packages of its own to a private registry ([§ 1 PLX-Updates](updates.md)) takes the same shape.
It is an approach at candidate maturity: one package monorepo runs it.


## § 1 Trunk-based, versioned by changesets

The packages repo is trunk-based on a single `main`, versioned and published by **changesets**.
Why trunk-based: changesets accumulates changeset files on one branch, bumps them in one PR on that branch, and publishes from it.
A second long-lived branch (GitFlow `develop`) forces reconciling version numbers between branches on every release, a perpetual back-merge tax; changesets is a trunk-based tool, and pairing it with GitFlow fights it.
Concurrency is not a reason to avoid this: changeset files have random names and the bump is deferred to one central step, so simultaneous feature branches never conflict and never double-publish.
The apps' environment-branch model is the counterpart, and the two models are never mixed.

How a release runs:

- **Two phases.** Changesets accumulate on `main`; `changesets/action` opens a "version packages" PR that bumps versions and writes changelogs; merging it publishes.
  The only manual step is recording a changeset with each publishable change; versioning and publishing run in CI, never locally.
  PRs run the contract verbs (the same names and arrangement the preset ships: mise bootstraps, turbo owns the graph) plus a `changeset status` guard that fails when a publishable change ships without a changeset; an empty changeset records a no-release change.
- **Token-less via OIDC.** Publishing authenticates through GitHub OIDC *trusted publishing* (`id-token: write`), not a stored npm token, which also makes provenance automatic.
  *Bootstrap caveat:* a package cannot be registered as a trusted publisher until it exists, so each package's **first** publish is a one-time manual `npm publish`, token-authenticated and therefore *without* provenance; the attestation chain starts at the second release, and CI takes over after.
- **Tags and GitHub Releases are automatic:** `changeset publish` tags each `@plexus-ms/<pkg>@x.y.z`, the action pushes them and cuts a Release from the changelog.
  The release branch (`main`) is protected by a ruleset requiring those CI checks; keep it that way, since this is what stands behind the upstream guarantees (§ 1.6 PLX).


## § 2 Package design

A `@plexus-ms/*` package is tenant-neutral methodology, never substance; this is the standard's guardrail and it binds every publish.
Code utilities start in `@plexus-ms/std`, the standard *library* ("the standard" alone always names PLX itself, never this package), the default home for any small shared concern, and a concern graduates to its own package once it has its own audience or its own release cadence: a consumer should not take updates because an unrelated helper changed.
Tool configs are the one deliberate exception to per-concern packages: they bundle into `@plexus-ms/config` as subpath exports (`@plexus-ms/config/biome`, `/tsconfig`, …), each still a one-line `extends` target, but sharing one package because they share one audience and one release cadence (and each separate package costs a manual bootstrap publish).
A config splits out only if it ever grows its own cadence.
Packages follow semver, enforced by changesets: a breaking change is a major bump, and its changeset carries a migration note so the changelog doubles as the upgrade guide.

Application plumbing, the "standardize boundaries" edges (framework glue, common auth concerns, repeatable non-domain features), is extracted into a package when a second app needs the same plumbing, never speculatively from the first; until then it lives in the app that needs it (§ 4.6 PLX).


## Maintaining

`plexus-ms/packages` rides outside the release train: npm semver via changesets is its versioning, and the train number says nothing about it.
The repo hand-maintains the monorepo arrangement the presets ship to tenants; a library-monorepo template is extracted when a second package monorepo appears, never speculatively from the first.
The module is promoted when that second monorepo runs it.
