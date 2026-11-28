---
title: PLX-Updates – propagation and the update bot
short_title: PLX-Updates
description: An encoded decision that does not propagate rots in place — shared things cross repo boundaries as versioned artifacts, an update bot watches every pin, and how unattended a merge is follows the blast radius.
code: PLX-Updates
maturity: standard
binds: repo
depends: [PLX-Repo]
order: 27
---

Autopilot has a precise mechanism: decide once, encode the decision in a primitive, and propagate it to every project automatically.
Most efforts get the first two steps and skip the third, and the propagation step is the whole game.
This module is the third step: how a change made once upstream reaches every tenant repo, and how far it travels without a human.


## § 1 Versioned dependency

> - `PLX-Updates/VersionedDependency`: A shared thing that crosses a repo boundary MUST be consumed as a published, versioned artifact.
> - `PLX-Updates/LocalConfig`: A consumer config SHOULD extend the shared `@plexus-ms/*` config and keep local additions in its own file.

A shared thing inside one repo is a workspace dependency, and within a tenant a shared artifact may be published to the tenant's private registry.
A repo has one access boundary and one release cycle, so nothing can be shared across repos by reference without dissolving one or the other; that single fact generates the rule.
Within a repo: pnpm workspaces, instant edits, atomic cross-package commits, no publish overhead, safe because it is one access boundary.
Across repos: published, versioned packages, the only mechanism that crosses a boundary, buying decoupled upgrade timing (a consumer pins `^2` and upgrades when *it* chooses) and update-bot propagation (the bot needs a version to detect).
Two repos of one tenant are no exception: a private package in the tenant's own registry crosses their boundary the same way.
A shared thing that hurts to publish is a signal the repo split was wrong, never a reason to reach across.
Across tenants, only upstream methodology travels.

Anything that can live behind a stable interface propagates as a versioned dependency:

- the `@plexus-ms/*` packages, extended in one line;
- the reusable workflows and the verbs they mount, by the version tag of `tooling` and the `plx` published from it;
- the `plexus.*` Ansible collections, installed from the version tag of `tooling`;
- the shared update-bot preset.

Fix once → bump version → a PR in every consumer repo.
Every pin has exactly one writer.
The pins that name the Plexus version (the workflow refs, the collection pin, the `plx` pin) are written with each version, all in one pull request per consumer.
The update bot proposes every other pin and never those, and a template states no other version at all, only the majors its own files rely on (§ 3).
A pin written with a version lives in a file the template owns.
The initiative's libraries are not such pins: they carry versions of their own (§ 1.5 PLX), and the bot moves them like any dependency (§ 2).
Two writers on one line make it rot: the one nobody updates falls behind, and the three-way merge conflicts.
Consumers customize by overriding at the edges, inheritance with a local override slot: a consumer's `biome.json` extends the shared one and adds local rules, so base updates never clobber local changes, because they live in different files.
Take the dependency, override at the edge, never fork the base.


## § 2 The update bot

> - `PLX-Updates/UpdateBot`: Every tenant repo MUST have an automated update bot watch its pins and open update pull requests.

A pin no machinery watches is invisible staleness, hence the bot itself is required; the template makes it Renovate, which extends the shared preset `github>plexus-ms/tooling//renovate/default` in one line, and this section is written against it.
The preset and the repo templates do the rest of this section, and a tenant reads it as what it gets:

- An operations repo pins the four `plexus.*` collections by tag in its `requirements.yml`.
- `@plexus-ms/*` packages on their own semver merge their patch and minor updates once CI is green.
- The pins that name the Plexus version are never proposed by the update bot.
  They arrive in the pull request by which the repo takes a version (§ 3), which a human reads before anything new runs in CI or as root.
- Third-party patch, minor and digest updates reach a repo together, in one pull request a week, which merges unattended once CI is green, except in an operations repo, where it waits for a human.
- Third-party majors, minors of a `0.x` dependency, and the updates of a dependency on a prerelease never merge unattended, and come in pull requests of their own.
- Lock file maintenance runs weekly, in a pull request of its own, and merges unattended once CI is green.
- A security fix is proposed at once, in a pull request of its own, and merges unattended once CI is green.
- A repo that publishes packages keeps their ranges wide: a range in `dependencies` or `optionalDependencies` moves only when a release falls outside it, and a range in `peerDependencies` is widened, not moved.
- A third-party npm release is neither installed nor proposed before it is three days old, a security fix included.
  The package manager enforces the age at install time and the bot before it opens a pull request; `@plexus-ms/*` packages are exempt, and so is the pnpm a repo is born with (§ 3).

The repo templates ship that line as `renovate.json`, so a generated repo runs this stratification from its first bot run.
The pins that name the Plexus version move in one pull request per version the repo takes, not one per version that is cut.

Third-party updates are batched because their stream is steady and each one's risk is small: one pull request per dependency and release became a daily queue of hand merges, and a queue like that teaches merging without reading.
Once a week, on Monday morning, every third-party patch, minor and digest update from every manager moves in one pull request, and lock file maintenance moves in a second, because Renovate never groups it with other updates.
Both merge themselves once CI is green, and a red one waits for a human, which is the fallback.
The bot merges on its own next run, so the merge needs no native auto-merge on the forge and works in a private repo on any plan.
What stays outside the group is what semver itself says may break: majors, minors of a `0.x` dependency, and every update of a dependency that is on a prerelease.
Each comes alone and waits for a human, and a node or TypeScript major also waits for approval on the dependency dashboard.
A security fix comes alone and at once, but still after the three-day release age: the bot's own default for alerts is no age at all, which the package manager would reject.
In an emergency a human excludes the one version in `pnpm-workspace.yaml`.

Two sub-presets sharpen the shared one, and the repo templates extend them.
An operations repo extends `operations`, under which the weekly group waits for a human: there a merge to `main` deploys a third-party image to production, and the only check before it is the playbooks' syntax.
A package repo extends `library`, which keeps published ranges wide.
An upstream release inside a range reaches only the lock file, which owes no changeset and forces no release, and a peer range is widened so that consumers on the older major keep working.

The three-day release age is one decision enforced on both sides of the install.
The preset sets `minimumReleaseAge` for everything it watches, and the repo template's `pnpm-workspace.yaml` sets the same 4320 minutes with `@plexus-ms/*` excluded.
A repo that installs the tenant's own private packages ([§ 5 PLX-Delivery](delivery.md)) excludes their scope on both sides as well, from its template answer: they are the tenant's own releases, and their updates wait for a human rather than for an age.
pnpm therefore refuses a younger version whether it arrives through the bot, a hand edit, or a transitive resolution.
A bot that proposed a release the package manager rejects would only open red PRs; the two numbers are kept equal so that neither side ever hides the other's verdict.
The initiative's own packages skip the wait because they are published by the maintainers under § 1.6 PLX.

How unattended the merge is, is stratified by blast radius, because one policy does not fit four risk classes:

- the initiative's own packages run inside an app with immutable, provenance-attested versions;
- third-party dependencies run in CI, in the image build and inside the app, and are judged per update by what semver promises;
- the workflows and `plx` run in tenant CI next to its secrets;
- the Ansible collections run with root on tenant hosts.

The default posture is deliberately not trust-maximal: unattended propagation is granted per risk class.
Each tenant's bot config records the stratification it chose, and the risk appetite behind that choice is the tenant's own.
A tenant choosing differently overrides the shared rules in its own `renovate.json`, which is where the deviation is recorded.

In a package repo the bot's bump is given the changeset it owes by `plx changeset` ([§ 5 PLX-Delivery](delivery.md)), committed to the bot's branch.
The preset lists that commit's author in `gitIgnoredAuthors`, so a branch the verb committed to is still the bot's to rebase, and the verb adds the file back after every rebase.


## § 3 Templates

> - `PLX-Updates/FromTemplates`: A tenant's repos SHOULD be generated from the templates: app repos from `repo-turbo`, apps within them from `app-nextjs`, the operations repo from `repo-operations`.
> - `PLX-Updates/Interval`: The interval a tenant sets SHOULD NOT exceed 30 days.

Scaffolding is the last resort, chosen per artifact in three tiers, and a generated repo is where the tiers meet.
Most of a repo's arrangement arrives as a dependency (tier one).
What cannot arrives through the template and is re-synced by a three-way merge against local edits, surfacing conflicts explicitly: the template as a living dependency rather than `cp` (tier two).
The genuine remainder is kept visibly versioned by the root marker's `version` and the `plx` pin (tier three), never invisibly stale.
Re-rendering the templates is the structural counterpart of a dependency bump: the hosted bot cannot do it, so a verb of the pinned tool does, `plx update`.
The result is a pull request on a `plexus/<version>` branch, conflicts committed with their markers so that they are resolved where they are reviewed; the tenant reviews and merges.
Cutting a version (§ 1.5 PLX) and a repo taking it are separate events.
Modules do not drive updates: what a version changed in a module's text is not what makes a repo take it.
The step by which a version's number moves says how urgent it is (§ 1.5 PLX), and the rule is this:

- A repo takes a version by the step of its number.
- A patch is a hotfix: the newest one within the repo's major is taken at once, and with it every version before it.
- A minor is routine: the newest version of the major is taken once the oldest version the repo has not taken is as old as its interval (`update_max_age`, seven days unless set; zero takes every version).
- A major changes a contract: it is named, and taken only when asked, with the migration steps in its release notes.
- Asking (`plx update --now`, a manual run of the workflow) takes the newest version whatever its step.

The interval is the repo's answer `update_max_age`, in days, in its root marker; a tenant sets it there, and `PLX-Updates/Interval` bounds it.

Between the versions it takes, the repo rests on the version it has.
That is safe because every pin it holds is immutable (§ 1.6 PLX): a repo on an old version keeps working.
A repo that takes a version takes every version in between in one jump; it is merged the same way, the merge is only larger, and the interval bounds how large.

A repo's markers are its configuration (§ 1.4 PLX): the root marker's `version` is the version the repo is on, and each marker lists its unit's templates and holds its answers.
`plx update` renders every unit whose marker lists a template twice, from the markers as the branch the version lands on has them: once with the templates of the version the repo is on, once with those of the version it takes.
Each side is rendered by its own version's `plx-template`, the running `plx`'s own or one fetched from the npm registry, so that an engine change never passes for a template change, and a version that cannot be fetched or rendered fails the run before anything is pushed.
The change between the two renders is merged into the unit's files: a local edit merges, a conflict stays in the file between markers, a file the version drops is deleted where the repo never edited it and kept where it did, and a file the repo deleted stays deleted.
The new `version`, and the defaults of questions the version makes applicable, are written into the markers.
An update runs no birth command and no `mise install`: the tools serve a developer's checkout, not a pull request.
The `plx` pin is a line of the template's `mise.toml` and moves with the merge; where it does not (the line conflicts or is gone, or the root marker lists no template), the pull request is not ready, and its body says to pin `plx` at the version by hand.
A kept file the version drops is named in the commit message and in the pull request, since nothing in the file shows it.

One mount opens the pull request: the repo's own `plx-update.yml`, generated by the repo templates, runs the verb once a day in the tenant's CI.
A run that takes nothing says in one line that the repo rests and why, and opens nothing, so the daily schedule costs nothing and a hotfix is met on the day it is cut.
The maintainers open no pull request in anybody's repo.
A pull request that needs a hand is opened as a draft where the forge offers drafts, and as an ordinary one where it does not: a unit that conflicted, a `plx` pin that did not move, or a lockfile that did not refresh.
Its body opens with what needs the hand and names the files that hold conflict markers; when the lockfile did not refresh, it says to run `pnpm install` after resolving.
A pull request that needs none is opened ready for review.
A conflict marker is a line that opens (`<<<<<<<`) or closes (`>>>>>>>`) a conflict; the separator line alone is none, since Markdown uses it for headings.
`plx doctor` reports every tracked file of a repo that holds one, whatever the repo's marker says.
The review is asked once, when the pull request is opened, draft or not, of the users the root marker's answer `pr_reviewers` names, a comma-separated list of GitHub logins; `plx update --reviewer` names others instead, and teams are not asked.

A `plexus/<version>` branch already on origin is never moved, and the verb never pushes to it again, so a scheduled run cannot overwrite a conflict somebody is resolving; deleting the branch is how a pull is redone.
A later run, scheduled or by hand, that finds the branch with its pull request open reads the branch as origin has it and looks for conflict markers in its tracked files; no checkout is touched.
It rewrites the body to what still needs a hand, marks the pull request ready once no conflict marker remains, the root marker names the version and the root `mise.toml` pins `plx` at it, and makes it a draft again while any of the three fails.
It leaves the lockfile to the human and to the repo's CI.
Whether a pull request is ready is read from its draft state and the branch, never from its body, so an edited body changes nothing a later run does.
While any of them fails, the run's summary says so and the run fails.
A later run that finds the branch with no pull request opens it.
The pull is made by the `plx` the repo pins, the one of the version it rests on, so a change to the pull itself reaches a repo one pull late.
The verb decides before it touches anything, from the compendium's releases: their numbers give each version's step, and their dates are what the interval is measured against.
It works in a worktree of the branch the version lands on (`develop` in an app repo, `main` in an operations or package repo), so a checkout run by hand stays as it was; its header in `tooling` states the steps.
A run that takes a version names its reason in the pull request, so a reviewer knows why this one arrived.
`plx update --recursive` runs the same verb, under the same rule, in every generated repo under a directory, for an operator with many repos checked out side by side; it reads the versions and checks the login once for all of them.

The verb needs an identity of the tenant's own, because a push with the workflow token starts no checks, and the pull request should be opened by something the tenant controls.
That identity is the tenant's one GitHub App, the App its CI already uses ([§ 8 PLX-Delivery](delivery.md)), installed on its repos with contents, pull requests and workflows write, the last because every version moves the workflow refs.
The mount takes the App's client ID and key from the variable `GH_CLIENT_ID` and the secret `GH_PRIVATE_KEY` where a repo or its organisation holds them, and from the item `github-app` of the CI vault otherwise.
On GitHub Free, organisation secrets and variables reach public repositories only.
A repo that has neither fails the run with one line naming both: a repo that takes no version is to be seen, not skipped.
The key never leaves the tenant: an app token is scoped to its installation, but the key mints tokens for every installation of the app, which is why the app is the tenant's and not the upstream's.

A template states a third-party dependency by the major its own files rely on (`"next": "^16"`), never by a version.
The repo's first install resolves the newest release the three-day age allows, and the repo's update bot is the only writer from then on.
The template line stays as it is until the template moves to a new major, which is a decision and the one occasion its three-way merge is meant to conflict.
An exact version in a template would have two writers, the template's author and the tenant's bot, and nobody updates the first: it falls behind until it conflicts.
Two pins the toolchain needs exact are not in the template at all: pnpm's `packageManager`, because corepack accepts no range, and Biome ([§ 1 PLX-JS](js.md)).
The repo template's birth commands write both when `plx new` creates the repo, at the newest release, with two accepted limits.
Corepack ignores the release age, so a repo can be born on a pnpm younger than three days.
pnpm saves an exact version only when it is given no range, so Biome is born at its newest release whatever the major, and a Biome major the shared config does not support yet fails the new repo's first lint.

A template line adjacent to a line the update bot moves conflicts on every version that changes it, whatever its own value, since git refuses touching hunks.
A line rewritten with every version (the `plx` pin) is therefore kept between comment lines the bot never touches, and a manifest's dependency map is never such a place.
A line a consumer edits is the same as one the bot moves, and the answer is hygiene in the files consumers edit: `mise.toml`, `pnpm-workspace.yaml`, the manifests, the Dockerfile and the operations repo's inventory.
There the templates keep comments and rationale, prose without semantic consequence, away from the lines a consumer or its update bot changes: the versions, digests, catalog ranges, app records, and lists such as the admins and the hosts.
A version moves no blank line beside those lines either.
Such prose changes with no change in behaviour, yet every consumer that edited next to it meets the change as a conflict.
The reason for a line lives in the module that asks for it, where rewording it costs no consumer anything.
A generated file keeps its one or two header lines, and the comment lines that fence the `plx` pin stay, since keeping the bot's lines apart is their purpose.

A few files are born once: written where the unit lacks them and the render it was last brought to does not hold them, and never touched again.
A born-once file a version of a template adds is therefore written into every unit that lacks it, one the unit deleted stays deleted, and one the template drops is kept.
Every template's marker is one of them.
Its body is the repo's or the app's own prose (§ 1.4 PLX), so an update that rendered it again would conflict with what was written there, and its frontmatter is `plx`'s to write, key by key.
The app template's source, the root layout, the page and the `/healthz` route, is the other.
The author rewrites it at once, and an update that rendered it again would fight the author's app, or add a root layout or page to an app whose route groups hold their own.

A marker's answers and its `templates` are edited by hand, and the procedure is edit, `plx apply`, commit.
`plx apply` renders each unit whose marker changed since `HEAD`, the old side from the marker as `HEAD` has it and the new side from the working tree, both with the templates of the version the repo is on, and merges the difference into the working tree; it writes the defaults of questions that became applicable into the markers, and commits nothing.
It is how a unit adopts or drops a template: an added template's files are written, and a dropped template's files are deleted where the unit never edited them and kept, reported as conflicts, where it did.
It runs only with the `plx` of the version the root marker names.
The one gap: an answer edited and committed without `plx apply` is caught by nothing, since `HEAD` then holds the new marker and nothing records what the files were rendered from.
`version` is never edited by hand, only `plx update` writes it, and `deviations` and the body are the human's alone.

A version that moves files from one template to another says so in its release notes.
Whoever takes it adds the template to `templates` on the update's branch and runs `plx apply` there before the pull request is merged.

An update can be done by hand with the engine alone, since `plx-template` knows nothing of Plexus.
Render the templates of the version the unit is on with its answers as JSON (its marker's keys but the three reserved ones, and for a nested unit the root marker's beside them) into one empty directory, render those of the version it takes into another, and merge the two into the unit: `plx-template render` twice and `plx-template merge` once.
The header of `plx-template`'s source shows the three commands.
What `plx update` adds is reading the markers, fetching each version's templates and engine, writing the version and the defaults into the markers, and the pull request.


## Maintaining

The templates, `repo-turbo`, `app-nextjs` and `repo-operations` under `templates/` of `tooling`, carry the Plexus version like the rest of the tooling and ship inside `@plexus-ms/cli`: the standard defers the concrete toolchain arrangement to them, so they are arrangement authorities, not conveniences.
Each is a directory: a manifest, `template.yml`, declaring its questions, the answers it reads from another template, its born-once files and its birth commands, and below `files/` the files it renders.
They ship `plx-update.yml` and `renovate.json`; `plexus-ms/libraries` is generated from `repo-turbo` (answer `publishes_packages`) and takes its arrangement like a tenant's web repo.
`tooling` ships `plx new`, `plx apply`, `plx update` and `plx changeset`, the engine `plx-template`, the reusable `_plx-update.yml` and `_changeset.yml`, and the shared Renovate preset under `renovate/`.

`tooling`'s `verify` creates each template as a newborn with `plx new`, birth commands included, and runs the newborn's own `verify`.
The app template is created as an app inside a newborn of the Turborepo template of the same checkout.

The three tiers decide where a new artifact goes:

1. **Convert to a dependency if at all possible.**
   Most "boilerplate" is secretly extractable; a `mise.toml` can `include` a shared, version-pinned task file, keeping only project-specific tasks local.
   This is the highest-value work: every bit extracted moves from the rotting pile to the auto-propagating pile, and the version pin lets the update bot carry the updates.
2. **Use a re-appliable scaffolder, not `cp`.**
   A repo's markers record the version it was rendered at and the answers it was rendered with, and `plx update` merges the change between two renders like a rebase.
3. **For the genuine remainder, make staleness visible:** the root marker's `version`, and the `plx` pin in a repo's `mise.toml` with it, name the version the repo is on, mechanically readable, so a repo that has drifted behind the current version shows it.
   These are never auto-fixed, but they are never invisibly stale; invisible staleness, not staleness itself, is the failure mode.

One bootstrap shortcut is permitted and bounded: static config (tsconfig, biome) can be pulled by git-dep or `degit` into a template on day one, replaced by proper publishing once stable, but never for `@plexus-ms/std`.

The shared preset is read from the default branch, as Renovate presets conventionally are, so a change to it reaches every tenant's next bot run without a version.
Every edit is therefore a change to every tenant's merge policy at once, and it is reviewed as one: widening automerge there widens it everywhere.
It is one preset for every Plexus repo, the upstream ones included, since every pin that names the Plexus version is written with the version wherever it is carried.
An operations repo pins each collection as `https://github.com/plexus-ms/tooling.git#/ansible/<layer>/`; the galaxy manager drops the subdirectory, so the version-pin rule matches these pins by the bare URL.
The sub-presets `library` and `operations` are read from the default branch too, but a repo extends them through its template, so a new sub-preset reaches a repo with the version that adds its line.
`gitIgnoredAuthors` names the one author that commits to the bot's branches, `plx changeset`'s.
A second such author is added in the preset, never in a tenant's own config, because a branch the bot stops rebasing is stale in every repo at once.

Cutting and taking are separate tools as they are separate events, and two tests keep them apart.
The upstream tooling, `plx-dev` (§ 1.5 PLX), works with no knowledge of any consumer; the tenant tooling, the published `plx`, works with published artifacts and the tenant's own repos alone.
The compendium's releases are what `plx update` reads because the compendium is released last, so a version shows to a repo only once it is cut everywhere.

`plx doctor` (§ 13.4 PLX) is the repo's own verb, run in the repo against the `plx` it pins ([§ 6 PLX-CLI](cli.md)).
