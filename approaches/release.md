---
title: PLX-Release – the release model
short_title: PLX-Release
description: Releases keyed by git SHA — main to prod, develop to staging, the app as unit of deployment and the repo as unit of promotion, and what happens when a deploy is red.
code: PLX-Release
maturity: standard
binds: repo
changed: 0.60.0
depends: [PLX-App]
order: 17
---

An app release has no version number to reconcile: a release *is* a deploy keyed by git SHA.
This module is the branch model built on that fact and the release model that scales it to a multi-app monorepo.
It binds an app repo; the deploy and CI machinery it composes with are [PLX-Deploy](deploy.md) and [PLX-CI](ci.md).
The `plexus-ms` packages version by different physics, semver in a registry, and their trunk-based model is [PLX-Packages](packages.md); the two models are never mixed.


## § 1 Environment branches

> - App repos MUST use environment branches: `main`→prod, `develop`→staging.
> - The platform repo SHOULD have a single `main`; environments are inventory groups, never branches.
> - Apps MUST NOT use changesets.
> - A hotfix branches from `main` and merges to `main`; it MUST be back-merged `main → develop` immediately.
> - Staging and prod MAY share a VM or take one each; both sit inside one tenant's trust domain, and [PLX-Tenancy](../contracts/tenancy.md) partitions tenants, not environments.

Branches map to deploy targets; "promote staging to prod" is merging `develop → main`.
Since a release is a deploy keyed by SHA, there are no version numbers to reconcile between branches and therefore no back-merge tax; the reason environment branches are wrong for published packages does not apply here.
Release tooling built for registries (changesets) has nothing to version in an app repo, which is why it is excluded outright.
The hotfix back-merge keeps the branches converging.

Which host an environment *is*, is inventory, not convention: `main`→prod and `develop`→staging name deploy targets, and the binding, which VM, which inventory record, which domain, lives in the platform repo's inventory ([§ 3 PLX-Platform](platform.md)), where the CI mount reads it.
The platform repo itself needs no environment branches because it has no release cycle of its own to promote: staging and prod are two inventory groups in one file, and a playbook run targets one of them.


## § 2 Deployment and promotion

> - CI MUST be path-scoped per app: an app's own directory plus every workspace package it depends on.
> - `develop` MUST stay promotable; unfinished or still-soaking work lives on feature branches, never parked on `develop`.
> - Selective promotion (cherry-picks, path-restricted merges) MUST NOT be used.

The model: **the unit of deployment is the app; the unit of promotion is the repo.**
A merge to an environment branch releases into that environment exactly the apps whose sources changed in the merge: a docs-only merge deploys nothing, a `packages/ui` change redeploys its dependents, unchanged apps are neither rebuilt nor redeployed.
The changed set is derived from the push event's `before..after` diff, one definition that covers merge commits, squash merges, and multi-commit direct pushes identically; stateless, no bookkeeping.
The deploy verb needs no change for this: it was per-app all along, and CI simply fans it out over the changed set.

Promotion is the whole repo: `develop → main` asserts *everything on `develop` is prod-ready*, and selective promotion would put on prod a repo state that never existed on staging, destroying the one guarantee environment branches exist to give.

Two boundaries of the model.
The platform repo has no release cycle: its ops side is not an app and the deploy verb never touches it; applying it is a playbook run, its own mount, on its own occasions.
Third-party apps hosted in the platform repo are the exception that proves it: they *are* apps, so the deploy verb does touch them, mounted on the platform repo's `main` and fanned out by the same `changed-apps` verb over its `apps/`, which without a workspace graph reduces to a plain path diff.
And the escape valve is a repo split, not a process patch: if two products in one tenant *persistently* need independent release cadences, move one into its own repo (still inside the tenant's org and access boundary, still on the same contract).
Granularity problems are solved by moving a product into a release cycle of its own, never by making promotion partial.


## § 3 Failed deploys and recovery

> - While a staging deploy is red, `develop → main` MUST NOT be merged.

A failed deploy parks promotion, and recovery is named, not improvised.
The changed set carries no memory, so CI never *rediscovers* a failed deploy: after the rollback and alert ([PLX-Deploy](deploy.md)), the environment branch is ahead of what actually runs, and the next unrelated merge will not close the gap.
Closing it is the operator's move, using mechanisms that already exist: re-run the failed CI job (same SHA, same derivation) once the cause is fixed, or invoke the hand-runnable deploy verb directly; never an empty commit.
A red staging deploy directly falsifies `develop`'s prod-readiness, hence the promotion freeze.


## Maintaining

Preview environments per PR are deliberately absent: a single staging per app covers most of the value, and the decision is revisited when a product has real customers (§ 6.8 PLX).
The `changed-apps` verb (`plexus-ms/ci-cd`, `scripts/changed-apps.sh`) is the one encoding of the changed set; the definition in § 2 and the verb change together.
