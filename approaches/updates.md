---
title: PLX-Updates – propagation and the update bot
short_title: PLX-Updates
description: An encoded decision that does not propagate rots in place — shared things cross repo boundaries as versioned artifacts, an update bot watches every pin, and how unattended a merge is follows the blast radius.
code: PLX-Updates
maturity: standard
binds: repo
changed: 0.67.0
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

A repo has one access boundary and one release cycle, so nothing can be shared across repos by reference without dissolving one or the other; that single fact generates the rule.
Within a repo: pnpm workspaces, instant edits, atomic cross-package commits, no publish overhead, safe because it is one access boundary.
Across repos: published, versioned packages, the only mechanism that crosses a boundary, buying decoupled upgrade timing (a consumer pins `^2` and upgrades when *it* chooses) and update-bot propagation (the bot needs a version to detect).
Two repos of one tenant are no exception: a private package in the tenant's own registry crosses their boundary the same way, and a shared thing that hurts to publish is a signal the repo split was wrong, never a reason to reach across.
Across tenants, only upstream methodology travels.

Anything that can live behind a stable interface propagates as a versioned dependency: the `@plexus-ms/*` packages (extended in one line), the reusable workflows and the verbs they mount (`primitives`' train tag and the `plx` published from it), the `plexus.platform` Ansible collection (installed from `primitives`' train tag), the shared update-bot preset.
Fix once → bump version → a PR in every consumer repo.
Every pin has exactly one writer: the train writes the pins that name the train (the workflow refs, the collection pin, the `plx` pin, the exact `@plexus-ms/config` pin), all in one pull request per consumer, and the update bot proposes every other pin and never those; a template holds only the value a repo is born with.
Two writers on one line is how the template birth values rotted and the three-way merges conflicted before.
Consumers customize by overriding at the edges, inheritance with a local override slot: a consumer's `biome.json` extends the shared one and adds local rules, so base updates never clobber local changes, because they live in different files.
Take the dependency, override at the edge, never fork the base.


## § 2 The update bot

> - Every tenant repo MUST run an automated update bot that watches its pins and opens update PRs.
> - The update bot SHOULD be Renovate, extending the shared preset `github>plexus-ms/primitives//renovate/default`.
> - Tenants MUST pin the `plexus.platform` collection by tag in the platform repo's `requirements.yml`.
> - For `@plexus-ms/*` packages on their own semver, CI-green patch/minor auto-merge MAY be enabled and is the recommended default.
> - The pins the train writes (the workflow refs, the collection pin, the `plx` pin, the `@plexus-ms/config` pin) MUST NOT be proposed by the update bot; they arrive as the train's pull request, which a human reads before anything new runs in CI or as root.
> - For third-party dev tools that check or orchestrate but never become a runtime dependency of an app (turbo, typescript, `@types/*`), CI-green patch/minor auto-merge MAY be enabled.
> - A third-party npm release MUST NOT be installed or proposed before it is three days old; the package manager enforces the age at install time and the bot before it opens a PR, and `@plexus-ms/*` packages are exempt.

A pin no machinery watches is invisible staleness, hence the bot itself is required while the concrete bot is only suggested; this section is written against Renovate, which extends the shared preset in one line.
The repo presets ship that line as `renovate.json`, so a generated repo runs the recommended stratification from its first bot run: `@plexus-ms/*` patch and minor updates merge on green CI, as do the dev tools', while the train's pins are the train's own pull request, opened by `plx ship` (§ 3), never the bot's and never auto-merged.

The three-day release age is one decision enforced on both sides of the install: the preset sets `minimumReleaseAge` for everything it watches, and the repo preset's `pnpm-workspace.yaml` sets the same 4320 minutes with `@plexus-ms/*` excluded, so pnpm refuses a younger version whether it arrives through the bot, a hand edit, or a transitive resolution.
A bot that proposed a release the package manager rejects would only open red PRs, which is what happened when pnpm 11 turned its own one-day default on; the two numbers are kept equal so that neither side ever hides the other's verdict, and the initiative's own packages and train skip the wait because they are published by the maintainers under § 1.6 PLX.

How unattended the merge is, is stratified by blast radius, because one policy does not fit four risk classes: packages run inside an app with immutable, provenance-attested versions; third-party dev tools run in CI and the image build but never inside the running app; the workflows and `plx` run in tenant CI next to its secrets; the Ansible collection runs with root on tenant hosts.
The default posture is deliberately not trust-maximal: unattended propagation is granted per risk class, each tenant's bot config records the stratification it chose, and the risk appetite behind that choice is the tenant's own.
A tenant choosing differently overrides the shared rules in its own `renovate.json`, which is where the deviation is recorded.

In a package repo the bot's bump is given the changeset it owes by `plx changeset` ([§ 5 PLX-Delivery](delivery.md)), committed to the bot's branch; the preset lists that commit's author in `gitIgnoredAuthors`, so a branch the verb committed to is still the bot's to rebase, and the verb adds the file back after every rebase.


## § 3 Templates

> - A tenant's repos SHOULD be generated from the presets: app repos from `plexus-ms/preset-repo-web`, apps within them from `plexus-ms/preset-app-nextjs`, the platform repo from `plexus-ms/preset-repo-platform`.
> - A repo generated from a preset SHOULD stay current with it through `copier update`, taken on the train like a dependency bump.

Scaffolding is the last resort, chosen per artifact in three tiers, and a generated repo is where the tiers meet.
Most of a repo's arrangement arrives as a dependency (tier one); what cannot arrives through the template and is re-synced by copier's three-way merge against local edits, surfacing conflicts explicitly, template as living dependency rather than `cp` (tier two); and the genuine remainder is kept visibly versioned by the marker's `plexus` field (tier three), never invisibly stale.
`copier update` is the structural counterpart of a dependency bump: the hosted bot cannot run it, so the train's `ship` step owns template propagation, running it in a clone of the consumer and opening the result as a pull request on a `train/<version>` branch, conflicts committed with their markers so that they are resolved where they are reviewed; the tenant reviews and merges.


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

The shared Renovate preset lives in `primitives` under `renovate/` and is read from the default branch, as Renovate presets conventionally are, so a change to it reaches every tenant's next bot run without a train.
That makes every edit a change to every tenant's merge policy at once, and it is reviewed as one: widening automerge there widens it everywhere.
It is one preset for every Plexus repo, the upstream ones included: every pin the train writes is written by the train in every repo that carries it, so there is no repo left in which the bot should bump them.
The galaxy manager needs a `packageName` override because it hands a github.com URL to the tags datasource verbatim; the preset carries that fix so no tenant repeats it.
`gitIgnoredAuthors` names the one author that commits to the bot's branches, `plx changeset`'s; a second such author is added here, never in a tenant's own config, because a branch the bot stops rebasing is stale in every repo at once.

Propagation runs from the root of the maintainers' workspace: `plx -n -y ship` previews the train in scratch clones of the consumers, `plx -y ship` tags and releases it and opens one pull request per consumer (app repos against `develop`, platform and package repos against `main`); the pull requests are reviewed and merged by hand.
The consumers are found in the workspace, but updated in clones of their origins: a dirty or detoured checkout no longer blocks a train.
`libraries` is a consumer of `preset-repo-web` like a tenant's web repo (answer `publishes_packages`), so the package-repo arrangement is propagated and no longer hand-maintained.
Birth values in the templates (a pin's value as a repo is generated) are the one residual two-writer line: the train rewrites them on every train, so they never rot further than one train; should the three-way merge still conflict on one, the rule to add is newest-wins in `propagate` for a single-line semver conflict.

Deferred: self-hosting the update bot.
The hosted bot runs each repo every few hours, and it merges a green pull request only on its own run, unless the forge's native auto-merge takes over; that needs a required check on the default branch, which blocks the direct pushes the train makes, and on a free plan a private repo has no auto-merge at all.
Requiring checks and listing bypasses is rejected as machinery out of proportion to the wait; the interim lever is the dashboard's "run again" checkbox, which starts a run within minutes.
Self-hosting is the sketch on file: a reusable `_renovate.yml` in `ci-cd` running Renovate for the calling repo only, mounted by every repo on three occasions: `workflow_run` when `verify` finishes on a bot branch, so a green bump merges at once, `workflow_dispatch` for a run on demand, and a schedule as the fallback.
Renovate's `postUpgradeTasks` would then write the changeset a bump owes inside the bot's own commit, retiring `_changeset.yml` and the ignored author.
Its costs are named up front: one GitHub App per tenant, since a token that writes to every repo it serves cannot cross a trust boundary; no release-triggered runs in tenants, because the upstream never reaches into a tenant's repos; Actions minutes on private repos unless the tenant's own runner takes the job; the hosted app uninstalled wherever the workflow runs; and a bot that is the tenant's to operate.
Reopened when waiting on the hosted bot still costs time after the checkbox has been tried, piloted first in `plexus-ms`, whose repos are public and run on the forge's runners.
