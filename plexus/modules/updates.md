---
title: PLX-Updates – propagation and the update bot
short_title: PLX-Updates
description: An encoded decision that does not propagate rots in place — shared things cross repo boundaries as versioned artifacts, an update bot watches every pin, and how unattended a merge is follows the blast radius.
code: PLX-Updates
kind: approach
maturity: standard
binds: repo
depends: [PLX-Repo]
order: 27
---

Autopilot has a precise mechanism: decide once, encode the decision in a primitive, and propagate it to every project automatically.
Most efforts get the first two steps and skip the third, and the propagation step is the whole game.
This module is the third step: how a change made once upstream reaches every tenant repo, and how far it travels without a human.


## § 1 Versioned dependency

> - A shared thing that crosses a repo boundary MUST be consumed as a published, versioned artifact; a shared thing inside one repo is a workspace dependency.
> - Within a tenant, such an artifact MAY be published to the tenant's private registry.
> - A consumer config SHOULD extend the shared `@plexus-ms/*` config and keep local additions in its own file.

A repo has one access boundary and one release train, so nothing can be shared across repos by reference without dissolving one or the other; that single fact generates the rule.
Within a repo: pnpm workspaces, instant edits, atomic cross-package commits, no publish overhead, safe because it is one access boundary.
Across repos: published, versioned packages, the only mechanism that crosses a boundary, buying decoupled upgrade timing (a consumer pins `^2` and upgrades when *it* chooses) and update-bot propagation (the bot needs a version to detect).
Two repos of one tenant are no exception: a private package in the tenant's own registry crosses their boundary the same way, and a shared thing that hurts to publish is a signal the repo split was wrong, never a reason to reach across.
Across tenants, only upstream methodology travels.

Anything that can live behind a stable interface propagates as a versioned dependency: the `@plexus-ms/*` packages (extended in one line), the reusable CI workflow and deploy verb (referenced by the `ci-cd` repo's train tag), the `plexus.platform` Ansible collection (installed from the `platform` repo's train tag), the shared update-bot preset.
Fix once → bump version → the update bot opens a PR in every consumer repo.
Consumers customize by overriding at the edges, inheritance with a local override slot: a consumer's `biome.json` extends the shared one and adds local rules, so base updates never clobber local changes, because they live in different files.
Take the dependency, override at the edge, never fork the base.


## § 2 The update bot

> - Every tenant repo MUST run an automated update bot that watches its pins and opens update PRs.
> - The update bot SHOULD be Renovate, extending the shared preset `plexus-ms/renovate-config`.
> - Tenants MUST pin the `plexus.platform` collection by tag in the platform repo's `requirements.yml`.
> - For `@plexus-ms/*` packages, CI-green patch/minor auto-merge MAY be enabled and is the recommended default.
> - For CI-workflow and verb tag bumps, auto-merge MAY be enabled; a tenant whose CI holds sensitive credentials SHOULD review these PRs instead.
> - Update PRs for the `plexus.platform` Ansible collection SHOULD NOT be auto-merged; a human reads the diff before anything new runs as root.
> - For third-party dev tools that check or orchestrate but never become a runtime dependency of an app (turbo, typescript, `@types/*`), CI-green patch/minor auto-merge MAY be enabled, held back until a release has been public for a few days.

A pin no machinery watches is invisible staleness, hence the bot itself is required while the concrete bot is only suggested; this section is written against Renovate, which extends the shared preset in one line.
The repo presets ship that line as `renovate.json`, so a generated repo runs the recommended stratification from its first bot run: `@plexus-ms/*` patch and minor updates merge on green CI, as do the dev tools' once a release is three days old, while the `ci-cd` workflow refs and the collection travel together as one "plexus release train" PR that is never auto-merged.

How unattended the merge is, is stratified by blast radius, because one policy does not fit four risk classes: packages run inside an app with immutable, provenance-attested versions; third-party dev tools run in CI and the image build but never inside the running app, and the release-age wait gives the ecosystem time to pull a compromised version before the bot proposes it; workflow and verb tags run in tenant CI next to its secrets and reference a movable tag (§ 1.6 PLX); the Ansible collection runs with root on tenant hosts.
The default posture is deliberately not trust-maximal: unattended propagation is granted per risk class, each tenant's bot config records the stratification it chose, and the risk appetite behind that choice is the tenant's own.
A tenant choosing differently overrides the shared rules in its own `renovate.json`, which is where the deviation is recorded.


## § 3 Templates

> - A repo generated from a preset SHOULD stay current with it through `copier update`, taken on the train like a dependency bump.

Scaffolding is the last resort, chosen per artifact in three tiers, and a generated repo is where the tiers meet.
Most of a repo's arrangement arrives as a dependency (tier one); what cannot arrives through the template and is re-synced by copier's three-way merge against local edits, surfacing conflicts explicitly, template as living dependency rather than `cp` (tier two); and the genuine remainder is kept visibly versioned by the marker's `plexus` field (tier three), never invisibly stale.
`copier update` is the structural counterpart of a dependency bump: the hosted bot cannot run it, so the train's `ship` step owns template propagation and the tenant commits the resulting diff.


## Maintaining

The presets, `plexus-ms/preset-repo-web`, `preset-app-nextjs`, and `preset-repo-platform`, are arrangement authorities, not conveniences: the standard defers the concrete toolchain arrangement to them, so they need real versioning discipline and ship on the train like the other ops artifacts.
The three tiers decide where a new artifact goes:

1. **Convert to a dependency if at all possible.**
   Most "boilerplate" is secretly extractable; a `mise.toml` can `include` a shared, version-pinned task file, keeping only project-specific tasks local.
   This is the highest-value work; every bit extracted moves from the rotting pile to the auto-propagating pile, and the version pin lets the update bot carry the updates.
2. **Use a re-appliable scaffolder, not `cp`.**
   copier records the template version a project was generated from and merges updates like a rebase.
3. **For the genuine remainder, make staleness visible:** the marker's frontmatter is mechanically checkable, and the staleness check (§ 13.4 PLX) flags repos that have drifted behind the current train.
   These are never auto-fixed, but they are never invisibly stale; invisible staleness, not staleness itself, is the failure mode.

One bootstrap shortcut is permitted and bounded: static config (tsconfig, biome) can be pulled by git-dep or `degit` into a template on day one, replaced by proper publishing once stable, but never for `@plexus-ms/std`.

`renovate-config` rides outside the train and is read from its default branch, as Renovate presets conventionally are, so a change to it reaches every tenant's next bot run without a train.
That makes every edit a change to every tenant's merge policy at once, and it is reviewed as one: widening automerge there widens it everywhere.
The galaxy manager needs a `packageName` override because it hands a github.com URL to the tags datasource verbatim; the preset carries that fix so no tenant repeats it.

Propagation runs from the `toolbox` repo: `mise run ship -- -n -y` previews the train in scratch clones of the consumers, `mise run ship -- -y` tags it and copier-updates every consumer; the consumer diffs are reviewed and committed by hand (app repos on `develop`, platform repos on `main`).
