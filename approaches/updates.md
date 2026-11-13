---
title: PLX-Updates – propagation and the update bot
short_title: PLX-Updates
description: An encoded decision that does not propagate rots in place — shared things cross repo boundaries as versioned artifacts, an update bot watches every pin, and how unattended a merge is follows the blast radius.
code: PLX-Updates
maturity: standard
binds: repo
changed: 0.119.0
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

Anything that can live behind a stable interface propagates as a versioned dependency: the `@plexus-ms/*` packages (extended in one line), the reusable workflows and the verbs they mount (the version tag of `tooling` and the `plx` published from it), the `plexus.platform` Ansible collection (installed from the version tag of `tooling`), the shared update-bot preset.
Fix once → bump version → a PR in every consumer repo.
Every pin has exactly one writer: the pins that name the Plexus version (the workflow refs, the collection pin, the `plx` pin) are written with each version, all in one pull request per consumer, and the update bot proposes every other pin and never those; a template states no other version at all, only the majors its own files rely on (§ 3).
A pin written with a version lives in a file the template owns.
The initiative's libraries are not such pins: they carry versions of their own (§ 1.5 PLX), and the bot moves them like any dependency (§ 2).
Two writers on one line is how the template birth values rotted and the three-way merges conflicted before.
Consumers customize by overriding at the edges, inheritance with a local override slot: a consumer's `biome.json` extends the shared one and adds local rules, so base updates never clobber local changes, because they live in different files.
Take the dependency, override at the edge, never fork the base.


## § 2 The update bot

> - Every tenant repo MUST run an automated update bot that watches its pins and opens update PRs.
> - The update bot SHOULD be Renovate, extending the shared preset `github>plexus-ms/tooling//renovate/default`.
> - Tenants MUST pin the `plexus.platform` collection by tag in the operations repo's `requirements.yml`.
> - For `@plexus-ms/*` packages on their own semver, CI-green patch/minor auto-merge MAY be enabled and is the recommended default.
> - The pins that name the Plexus version (the workflow refs, the collection pin, the `plx` pin) MUST NOT be proposed by the update bot; they arrive in the pull request by which the repo takes a version (§ 3), which a human reads before anything new runs in CI or as root.
> - Third-party patch, minor and digest updates SHOULD reach a repo together, in one pull request a week; that pull request MAY merge unattended once CI is green, and in an operations repo it SHOULD wait for a human.
> - Third-party majors, minors below 1.0.0, and the updates of a dependency on a prerelease MUST NOT merge unattended, and SHOULD come in pull requests of their own.
> - Lock file maintenance SHOULD run weekly, in a pull request of its own, and MAY merge unattended once CI is green.
> - A security fix SHOULD be proposed at once, in a pull request of its own, and MAY merge unattended once CI is green.
> - A repo that publishes packages SHOULD keep their ranges wide: a range in `dependencies` or `optionalDependencies` moves only when a release falls outside it, and a range in `peerDependencies` is widened, not moved.
> - A third-party npm release MUST NOT be installed or proposed before it is three days old, a security fix included; the package manager enforces the age at install time and the bot before it opens a PR; `@plexus-ms/*` packages are exempt, and so is the pnpm a repo is born with (§ 3).

A pin no machinery watches is invisible staleness, hence the bot itself is required while the concrete bot is only suggested; this section is written against Renovate, which extends the shared preset in one line.
The repo templates ship that line as `renovate.json`, so a generated repo runs the recommended stratification from its first bot run: `@plexus-ms/*` patch and minor updates merge on green CI, and so does the weekly pull request of everything else, while the pins that name the Plexus version move only in the pull request by which the repo takes a version (§ 3), never the bot's and never auto-merged.
That is one pull request per version the repo takes, not one per version that is cut.

Third-party updates are batched because their stream is steady and each one's risk is small: one pull request per dependency and release became a daily queue of hand merges, and a queue like that teaches merging without reading.
Once a week, on Monday morning, every third-party patch, minor and digest update from every manager moves in one pull request, and lock file maintenance moves in a second, because Renovate never groups it with other updates.
Both merge themselves once CI is green, and a red one waits for a human, which is the fallback.
The bot merges on its own next run, so the merge needs no native auto-merge on the forge and works in a private repo on any plan.
What stays outside the group is what semver itself says may break: majors, minors below 1.0.0, and every update of a dependency that is on a prerelease; each comes alone and waits for a human, and a node or TypeScript major also waits for approval on the dependency dashboard.
A security fix comes alone and at once, but still after the three-day release age: the bot's own default for alerts is no age at all, which the package manager would reject; in an emergency a human excludes the one version in `pnpm-workspace.yaml`.

Two sub-presets sharpen the shared one, and the repo templates extend them.
An operations repo extends `operations`, under which the weekly group waits for a human: there a merge to `main` deploys a third-party image to production, and the only check before it is the playbooks' syntax.
A package repo extends `library`, which keeps published ranges wide: an upstream release inside a range reaches only the lock file, which owes no changeset and forces no release, and a peer range is widened so that consumers on the older major keep working.

The three-day release age is one decision enforced on both sides of the install: the preset sets `minimumReleaseAge` for everything it watches, and the repo template's `pnpm-workspace.yaml` sets the same 4320 minutes with `@plexus-ms/*` excluded, so pnpm refuses a younger version whether it arrives through the bot, a hand edit, or a transitive resolution.
A bot that proposed a release the package manager rejects would only open red PRs, which is what happened when pnpm 11 turned its own one-day default on; the two numbers are kept equal so that neither side ever hides the other's verdict, and the initiative's own packages skip the wait because they are published by the maintainers under § 1.6 PLX.

How unattended the merge is, is stratified by blast radius, because one policy does not fit four risk classes: the initiative's own packages run inside an app with immutable, provenance-attested versions; third-party dependencies run in CI, in the image build and inside the app, and are judged per update by what semver promises; the workflows and `plx` run in tenant CI next to its secrets; the Ansible collection runs with root on tenant hosts.
The default posture is deliberately not trust-maximal: unattended propagation is granted per risk class, each tenant's bot config records the stratification it chose, and the risk appetite behind that choice is the tenant's own.
A tenant choosing differently overrides the shared rules in its own `renovate.json`, which is where the deviation is recorded.

In a package repo the bot's bump is given the changeset it owes by `plx changeset` ([§ 5 PLX-Delivery](delivery.md)), committed to the bot's branch; the preset lists that commit's author in `gitIgnoredAuthors`, so a branch the verb committed to is still the bot's to rebase, and the verb adds the file back after every rebase.


## § 3 Templates

> - A tenant's repos SHOULD be generated from the templates: app repos from `plexus-ms/template-repo-turbo`, apps within them from `plexus-ms/template-app-nextjs`, the operations repo from `plexus-ms/template-repo-operations`.
> - A repo generated from a template SHOULD stay current with it through `copier update`, taking the newest version when it needs one and not whenever one is cut.
> - A repo needs a version, and SHOULD then take the newest, when a module it declares has a `changed` newer than its marker's `plexus`, when somebody asks, or when the oldest version it has not taken is older than the backstop age.
> - The backstop age is the tenant's to set and SHOULD NOT exceed 30 days.
> - While none of these holds, a repo MAY rest on the version it has.

Scaffolding is the last resort, chosen per artifact in three tiers, and a generated repo is where the tiers meet.
Most of a repo's arrangement arrives as a dependency (tier one); what cannot arrives through the template and is re-synced by copier's three-way merge against local edits, surfacing conflicts explicitly, template as living dependency rather than `cp` (tier two); and the genuine remainder is kept visibly versioned by the marker's `plexus` field (tier three), never invisibly stale.
`copier update` is the structural counterpart of a dependency bump: the hosted bot cannot run it, so a verb of the pinned tool does, `plx update`, and the result is a pull request on a `plexus/<version>` branch, conflicts committed with their markers so that they are resolved where they are reviewed; the tenant reviews and merges.
Cutting a version and a repo taking it are separate events.
The maintainers cut a version when the methodology has moved; a repo takes one when it needs it, and that a newer version exists is not a need.
Three triggers are the need:

1. **A declared module changed.**
   A module in one of the repo's markers has a `changed` newer than that marker's `plexus`: the staleness of § 1.4 PLX, per module, and the only one of the three that says the version has something for this repo.
   The repo learns it from the version itself: every version publishes its module catalogue as data on its release (Maintaining), so no checkout of the compendium is needed.
   The markers that count are those of the repo's sites, its root and its apps, which a pull brings up to the version; a marker kept by hand anywhere else is not cured by a pull and is the staleness check's to report (§ 13.4 PLX).
2. **Somebody asks.**
   The verb told by hand to take the version now, or the workflow's manual trigger; it is also how a hotfix reaches the repos that need it, asked for by whoever operates them.
3. **The backstop age is exceeded.**
   The oldest version the repo has not taken was cut longer ago than the tenant's maximum, 30 days unless it says otherwise.
   The backstop carries everything no `changed` announces, a template change without a requirement behind it or a module below standard maturity, and it keeps a jump small enough to review.

While none holds the repo rests on the version it has.
That is safe because every pin it holds is immutable (§ 1.6 PLX): a repo on an old version keeps working, and a quiet repo sees no pull request until it needs one.
A repo that takes a version takes the newest, over every version in between in one jump; copier merges it the same way, the merge is only larger, and the backstop bounds how large.
An age of zero is the eager repo, which takes every version as it is cut; a tenant that wants to meet a version first sets that.

One mount opens the pull request: the repo's own `update.yml`, generated by the repo templates, runs the verb once a day in the tenant's CI with an identity of the tenant's own (a GitHub App, Maintaining).
A run that finds no trigger says in one line that the repo rests and why, and opens nothing, so the daily schedule costs nothing and a need is met on the day it arises.
The maintainers open no pull request in anybody's repo: `plx-dev ship` cuts the version and ends there.
A `plexus/<version>` branch already on origin is never moved, so a scheduled run cannot overwrite a conflict somebody is resolving; deleting the branch is how a pull is redone.
The pull is made by the `plx` the repo pins, the one of the version it rests on, so a change to the pull itself reaches a repo one pull late.

A template states a third-party dependency by the major its own files rely on (`"next": "^16"`), never by a version.
The repo's first install resolves the newest release the three-day age allows, the repo's update bot is the only writer from then on, and the template line stays as it is until the template moves to a new major, which is a decision and the one occasion its three-way merge is meant to conflict.
An exact version in a template would have two writers, the template's author and the tenant's bot, and nobody updates the first: it falls behind until it conflicts.
Two pins the toolchain needs exact are not in the template at all: pnpm's `packageManager`, because corepack accepts no range, and Biome ([§ 1 PLX-JS](js.md)).
The repo template's copy-only tasks write both when the repo is generated, at the newest release, with two accepted limits.
Corepack ignores the release age, so a repo can be born on a pnpm younger than three days.
pnpm saves an exact version only when it is given no range, so Biome is born at its newest release whatever the major, and a Biome major the shared config does not support yet fails the new repo's first lint.


## Maintaining

The templates, `plexus-ms/template-repo-turbo`, `template-app-nextjs`, and `template-repo-operations`, are arrangement authorities, not conveniences: the standard defers the concrete toolchain arrangement to them, so they need real versioning discipline and carry the Plexus version like the tooling.
The three tiers decide where a new artifact goes:

1. **Convert to a dependency if at all possible.**
   Most "boilerplate" is secretly extractable; a `mise.toml` can `include` a shared, version-pinned task file, keeping only project-specific tasks local.
   This is the highest-value work; every bit extracted moves from the rotting pile to the auto-propagating pile, and the version pin lets the update bot carry the updates.
2. **Use a re-appliable scaffolder, not `cp`.**
   copier records the template version a project was generated from and merges updates like a rebase.
3. **For the genuine remainder, make staleness visible:** the marker's frontmatter is mechanically checkable, and the staleness check (§ 13.4 PLX) flags repos that have drifted behind the current version.
   These are never auto-fixed, but they are never invisibly stale; invisible staleness, not staleness itself, is the failure mode.

One bootstrap shortcut is permitted and bounded: static config (tsconfig, biome) can be pulled by git-dep or `degit` into a template on day one, replaced by proper publishing once stable, but never for `@plexus-ms/std`.

The shared Renovate preset lives in `tooling` under `renovate/` and is read from the default branch, as Renovate presets conventionally are, so a change to it reaches every tenant's next bot run without a version.
That makes every edit a change to every tenant's merge policy at once, and it is reviewed as one: widening automerge there widens it everywhere.
It is one preset for every Plexus repo, the upstream ones included: every pin that names the Plexus version is written with it in every repo that carries it, so there is no repo left in which the bot should bump them.
An operations repo pins each collection as `https://github.com/plexus-ms/tooling.git#/ansible/<layer>/`; the galaxy manager drops the subdirectory, so the version-pin rule matches these pins by the bare URL and the bot never proposes them.
The sub-presets `library` and `operations` are read from the default branch like the shared preset, but a repo extends them through its template, so a new sub-preset reaches a repo with the version that adds its line.
`gitIgnoredAuthors` names the one author that commits to the bot's branches, `plx changeset`'s; a second such author is added here, never in a tenant's own config, because a branch the bot stops rebasing is stale in every repo at once.

Cutting and taking are separate tools as they are separate events (§ 3), and two tests keep them apart: the upstream tooling works with no knowledge of any consumer, and the tenant tooling works with published artifacts and the tenant's own repos alone.
The upstream tooling is `plx-dev` in `tooling`, never published and run from the maintainers' checkout ([PLX-CLI](cli.md)); the tenant tooling is the published `plx`.
From that checkout, `mise ship -- -y` writes the bookkeeping, tags and releases the version, and ends there: it looks for no consumer and opens no pull request.
Every repo generated from the templates pulls the version itself, the maintainers' own like any tenant's: the templates' `update.yml` mounts `plx update` on a daily schedule and on demand, through the reusable `_update.yml` in `tooling`, and the verb works in a worktree of the branch the version lands on (`develop` in an app repo, `main` in an operations or package repo), so a developer running it by hand keeps their checkout as it was.
The verb asks the forge for the compendium's releases: the newest is the newest version because every version tag has one (§ 1.6 PLX), and their dates are what the backstop age is measured against.
The compendium is asked because it is released last, so a version shows to a repo only once it is cut everywhere, and because its release carries the module manifest: `modules.json`, the version's number and date and the module catalogue with every module's `changed`, written by `ship` from the pages it has just stamped.
An immutable release locks its assets, so `ship` creates that one release as a draft, uploads the manifest and only then publishes it; a draft is no version yet, and a run that stops there is finished by the re-run.
The verb reads the manifest of the newest version alone, since `changed` is cumulative, and compares it with the markers of the repo's sites as origin has them; a version without a manifest, as every version before the first that carried one, is said in one line and leaves the repo to its backstop.
It decides before it makes a worktree: a resting run prints its one line and exits zero, and a run that takes the version names its trigger in the pull request, so a reviewer knows why this one arrived.
The schedule stays daily for that reason, and the maximum age is an answer of the repo template (`update_max_age`, in days), read by the verb from the repo's answers file, so that the schedule, a run by hand and `propagate` agree on it and a tenant's deviation from 30 days is one line in a file it owns; a repo whose answers do not say is held to 30.
`plx propagate` is the operator's convenience over the same verb: it runs `plx update` in every generated repo under a directory, from the published tags, under the same triggers and with the same way to override them, and ends with one summary of what rests, what is clean, conflicted or failed, and the pull requests.
It needs no `plexus-ms` checkout, and a tenant's operator runs it as the maintainers do.
The rule reaches a repo with the version that ships it, because a repo runs the `plx` it pins: that version is the last one every repo takes merely because it exists.

One debt.
`mise ship -- -n` in `tooling` still previews the unreleased templates against scratch clones of the workspace's consumers; that is a maintainer's test of a version before it is cut, not propagation, and it leaves `ship` for a canary of its own.

Deferred: an urgent version, one that every repo takes at once whatever its triggers say.
Reading urgency off the patch number was rejected: a hotfix repairs what one version broke, and a repo resting on an older version would be pulled to it for a fault it never had.
While the maintainers operate every consumer, asking covers it: the hotfix is cut and `plx propagate` is told to take it now where it matters.
Reopened with the first tenant the maintainers do not operate, because a signal on the release is then the only way to say "take this one" across the tenant line, and decided together with the data a version publishes about itself, which can say which repos it is urgent for.

The verb needs an identity of the tenant's own, because a push with the workflow token starts no checks and the pull request should be opened by something the tenant controls: one GitHub App per tenant, installed on its repos with contents and pull requests write, its ID in the variable `PLX_APP_ID` and its key in the secret `PLX_APP_PRIVATE_KEY`, set once at the organisation where the plan allows it (on GitHub Free, organisation secrets and variables reach public repositories only, so a tenant with private repos sets both on each repo); a package repo's changeset job pushes with the same app.
Until the variable is set the job is skipped, so a repo generated before the app exists stays green and takes no version until the app exists or somebody runs the verb by hand.
The key never leaves the tenant: an app token is scoped to its installation, but the key mints tokens for every installation of the app, which is why the app is the tenant's and not the upstream's.
`libraries` is a consumer of `template-repo-turbo` like a tenant's web repo (answer `publishes_packages`), so the package-repo arrangement is propagated and no longer hand-maintained.
The templates hold no version the update bot moves (§ 3), so propagation never meets a line with two writers, and no newest-wins rule is needed in the verb.
What remains was learnt on the first versions of the consolidated layout: git refuses touching hunks, so any template line adjacent to a line the update bot moves conflicts on the version that changes it, whatever its own value.
A line rewritten with every version (the `plx` pin) is therefore kept between comment lines the bot never touches, and a manifest's dependency map is never such a place.

The staleness check itself (§ 13.4 PLX) still runs only from the maintainers' workspace, because it reads a compendium checkout; the module manifest carries everything it reads, so a tenant's own `doctor` is the next verb and a small one ([§ 6 PLX-CLI](cli.md)).

Deferred: self-hosting the update bot.
The hosted bot runs each repo every few hours, and it merges a green pull request only on its own run, unless the forge's native auto-merge takes over; that needs a required check on the default branch, which blocks the direct pushes `ship` makes, and on a free plan a private repo has no auto-merge at all.
Requiring checks and listing bypasses is rejected as machinery out of proportion to the wait; the interim lever is the dashboard's "run again" checkbox, which starts a run within minutes.
Self-hosting is the sketch on file: a reusable `_renovate.yml` in `ci-cd` running Renovate for the calling repo only, mounted by every repo on three occasions: `workflow_run` when `verify` finishes on a bot branch, so a green bump merges at once, `workflow_dispatch` for a run on demand, and a schedule as the fallback.
Renovate's `postUpgradeTasks` would then write the changeset a bump owes inside the bot's own commit, retiring `_changeset.yml` and the ignored author.
Its costs are named up front: one GitHub App per tenant, since a token that writes to every repo it serves cannot cross a trust boundary (taking a version already pays this one); no release-triggered runs in tenants, because the upstream never reaches into a tenant's repos; Actions minutes on private repos unless the tenant's own runner takes the job; the hosted app uninstalled wherever the workflow runs; and a bot that is the tenant's to operate.
Reopened when waiting on the hosted bot still costs time after the checkbox has been tried, piloted first in `plexus-ms`, whose repos are public and run on the forge's runners.
