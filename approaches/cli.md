---
title: The Plexus CLI
short_title: CLI
description: The plx family of command-line tools — the published plx with the tenant's and the operator's verbs and plx-ci with the CI verbs, and the unpublished plx-dev that cuts the train — why it replaced the shell scripts, where it lives, what it must not become, and how a repo takes it.
code: PLX-CLI
maturity: candidate
binds: repo
depends: [PLX-Repo]
order: 29
---

This module is the `plx` family: `plx`, published as `@plexus-ms/cli`, the base in every tenant repo, which carries the ops verbs a tenant's CI runs and the helpers an operator of many repos runs, `plx-dev`, which cuts the train and is never published, and `plx-ci`, published as `@plexus-ms/cli-ci`, the CI verbs on top of it, both on `@plexus-ms/lib` and in place of the shell scripts that carried them before.
A repo takes each as one line in its `mise.toml` tools table, written by the repo presets and moved by the train, and its workflows call the pins.
The page keeps the case that was made for the tool and the rules that keep it a bag of verbs rather than a system; it is a candidate, so it states no requirements yet.


## § 1 What exists

The maintainers' helpers have moved: `plx`, published as `@plexus-ms/cli` from `primitives` with `@plexus-ms/lib` as its core, carries the workspace map (`overview`), the staleness check (`doctor`, § 13.4 PLX), the train pull a repo makes for itself and the loop that runs it over many repos (`update`, `propagate`, [§ 3 PLX-Updates](updates.md)), the standard's requirements check (`requirements`, § 1.8 PLX) and the changeset a dependency bump owes (`changeset`, [§ 5 PLX-Delivery](delivery.md)).
The maintainers run the workspace verbs as plain `plx` commands from the root of their workspace, whose `mise.toml` takes the newest release; the compendium pins it in its own `mise.toml` for `requirements`.
The cutting of a train (`ship`, § 1.5 PLX) is in none of the published tools: it is `plx-dev`, the unpublished package `@plexus-ms/dev` in `primitives`, which the maintainers run from their checkout of it (§ 3).
The ops verbs have followed: `deploy-targets` and `deploy` are commands of the tool ([§ 6 PLX-Delivery](delivery.md)), mounted on the forge by the thin reusable workflows next to it in `primitives`, which call the `plx` the tenant repo pins in its `mise.toml`, and run by hand from a checkout otherwise.
The workflows carry no logic, only the mounts.
The CI verbs ([§ 8 PLX-Delivery](delivery.md)) are a second tool on top of it, `plx-ci`, published as `@plexus-ms/cli-ci` at the train number from the same repo on the same `@plexus-ms/lib`: `registry`, `plan`, `build`, `test`, `publish` and `report`, which every strategy runs and which read the strategy, the registry and the overlay from `CI_STRATEGY`, `CI_REGISTRY` and `CI_OVERLAY`, and under `hybrid` the instances' own, `hybrid create-instances`, `destroy-instances` and `sweep-instances`; each is one line of a reusable workflow and each runnable by hand with the same keys in the environment.
It is a package of its own so that the CI of one tenant can change without moving every tenant's `plx`, and so that an operations repo, which builds nothing, carries only the base.
`changed-apps` was a verb of `plx` from train 0.71.0 to 0.110.0 and went with the diff-based changed set: `plx-ci plan` decides by content hash, and the operations repo's deploy fans over every app and relies on the deploy verb's no-op.
The verbs serve three roles: the upstream, which cuts a train (`plx-dev ship`); a tenant repo, which lives on one (`update`, `deploy`, `deploy-targets`, `changeset`); and an operator of many repos, the maintainers or a tenant's own (`overview`, `doctor`, `propagate`).
Two tests draw the line between the first and the other two: the upstream's verbs work with no knowledge of any consumer, and the tenant's and the operator's work with published artifacts and the tenant's own repos alone ([PLX-Updates](updates.md), Maintaining).
The upstream's verbs are therefore not in `plx`, and `@plexus-ms/lib` holds nothing that cuts a train, so that a tenant repo pins nothing it cannot run.
The compendium's requirements check stays in `plx`: the compendium runs it from its pin in `mise check` like any repo's check, it knows no consumer, and `plx-dev ship` stamps `changed` with the same extractor, from `@plexus-ms/lib`.
The platform preset ships a playbook wrapper that prefixes the vault's CLI, and both repo presets ship the contract verbs and `sync` as mise tasks; those are the shell that remains.

The discipline of the scripts was uniform: a header stating what the script did and how to run it by hand, strict mode, shellcheck clean, a `check` verb that enforced both.
Each passed the second-reader and degradation tests of the [manifesto](../essentials/manifesto.md), and volume alone was no reason to replace them.
What tipped the decision was the maintainers' own fog: dense bash with its quoting and its heredocs is harder for a human to maintain than TypeScript of the same portability, and the verbs moved for that reason, with the tighter supply chain of § 2 as a benefit that came along.


## § 2 What justified a CLI

Three things in the shell-script surface were debts a script could not pay, and all three are answered by the same tool.

**One parser instead of five.**
The declaration marker (§ 1.4 PLX), a module's frontmatter (§ 1.3 PLX), copier's answers file, the app record in a tenant's inventory ([§ 3 PLX-Platform](platform.md)) and the labels in `compose.yaml` ([PLX-App](../contracts/app.md)) were each read by whichever awk or sed last touched them: `ship` edited markers and frontmatter, `staleness` read frontmatter, `deploy-targets` reads inventory records, `requirements.sh` read module pages, `overview` read answers files.
Each was honest about its limits, and together they were an unwritten contract: a quoted value, an indented list or a reordered key broke one of them silently.
`@plexus-ms/lib` now holds one reader of the marker, the module frontmatter, the answers file and the inventory record, and one line-based editor of frontmatter; the compose labels are not parsed at all, the deploy verb reads `plexus.healthz` from the running container, which is reality rather than a parse.

**Rung one of the ladder for the verbs themselves.**
The deploy verb reached a tenant's CI as a checkout of the workflow repo at a train tag, a movable tag; the train tag now pins only the workflows, and every train tag is locked by an immutable release (§ 1.6 PLX).
The playbook wrapper and the `promote` and `sync` tasks still reach a tenant by copier, the second rung of § 4.3 PLX.
A published `@plexus-ms/cli` is immutable and provenance-attested ([§ 5 PLX-Delivery](delivery.md)), pinned in a repo's `mise.toml` at the train number, and moved by the pull request in which the repo takes a train ([§ 1 PLX-Updates](updates.md)).
For the verbs that is a tighter supply chain, not only better ergonomics.

**The verbs not written yet.**
`new tenant`, `new repo`, `new app`, and a `doctor` that runs the staleness check inside one tenant.
§ 13.4 PLX defers the tenant-side staleness check to a tenant that is not also the maintainer, because a toolbox script cannot travel; a subcommand of a pinned tool can.
Those are the primitives that move the marginal tenant's cost toward zero.


## § 3 Where it lives and what runs it

TypeScript in `primitives`, as `@plexus-ms/cli` with `@plexus-ms/lib`, published through trusted publishing at the train number (§ 1.5 PLX): the tool is arrangement, like the workflows and the collection it sits beside, and one number names the train, the tool and the config a repo runs.
Its release is the train's: `plx-dev ship` writes the version, the train's immutable GitHub release triggers the publish, and the second phase of the train waits until the registry has it.
`plx-dev` and the requirements check are the maintainers' and are public all the same: they are methodology, and they carry no tenant's substance.

The runtime is no objection.
mise installs npm tools directly, and every repo and every CI runner already goes through mise ([§ 2 PLX-Repo](../contracts/repo.md)).
An operations repo has no Node toolchain, only the runtime the two tools run on, and it pins that runtime in its tools table like any tool, since train 0.113.0; the bot keeps both lines current.
A few hundred lines of TypeScript with a YAML dependency read in half an hour at least as well as the awk they replaced, and they take unit tests in the ordinary way; the bash harnesses that faked copier, mise, docker and curl live on as integration tests in `primitives`, joined by fakes for `gh` and `npm`.

The train pins the workflows and the tool alike, in one pull request per consumer, so the verbs a workflow asks for are the ones the pinned `plx` has; a workflow that asks for a verb the pinned `plx` lacks still fails as a usage error, loudly.

The maintainers' workspace takes no pin: its `mise.toml` asks for the newest release, for the operator's verbs, since `propagate` runs whatever `plx` the operator has, like the `update` it loops over, and `propagate --now` is how a hotfix reaches the repos that need it.
The workspace exempts the tool from mise's minimum release age (`minimum_release_age_excludes`), as pnpm and the update bot already exempt `@plexus-ms`, so that a fresh release is not held back for a day; mise also caches a tool's version list, so an update right after a train is `mise cache clear npm:@plexus-ms/cli && mise up npm:@plexus-ms/cli`.
The tool that cuts the train takes neither a pin nor a release: `mise ship` in `primitives` builds `plx-dev` from that checkout and runs it over the workspace the checkout sits in, so the release tool is the code at `main` and cannot be older than what it releases.
Until train 0.118.0, `ship` was a verb of the published `plx` and refused to run behind the registry's newest release, which meant updating the workspace's `plx` before every train and building `plx` locally to ship a change to the bookkeeping; the split by role (§ 6) ended both.
The copier an update runs is pinned inside `plx` and run as `mise exec copier@<version> -- copier`, which the dry run prints like every other step: the copier a repo is updated with travels with the tool, and the operator's `PATH` has no say in it.


## § 4 What it must not become

The manifesto's objection to control planes applies to a tool of one's own.
Three rules keep a CLI a bag of verbs rather than a system:

- Every subcommand is stateless and hand-runnable, and `--dry-run` prints the exact shell and ssh it would run.
  A stranded operator copies the printed commands; that is the degradation test, kept.
- The tool has no configuration file of its own.
  It reads the artifacts that already exist: markers, inventory, answers files, `compose.yaml`, module pages.
- The host side needs bash, docker and curl, and nothing else; that stays true.
  Every command the deploy verb sends over ssh is a one-liner the dry run prints verbatim, so what reaches a host is readable in the plan, not in a script shipped alongside.


## § 5 What it does not solve

The command tasks in the infrastructure roles stay Ansible and still need an offline test of their own ([PLX-Infrastructure](infrastructure.md), Maintaining).
The hook and task stanzas repeated across the upstream repos stay manual sync, because the upstream repos are not consumers of any preset.
A tenant's restore drill scripts and per-app backup hooks are the prototypes of [backups per service](backup.md) and move upstream with that module, not with this one.


## § 6 Order of migration

The verbs move in order of risk, each replacing one script and leaving the rest as they are:

1. Done: the parser library, with `overview` and `doctor` (the staleness check) on top of it.
2. Done, pulled ahead of the ops verbs because it is maintainer-only and had the best harness to diff against: `ship`, with `propagate` as a verb of its own and the compendium's requirements check as `requirements`, so that the `changed` comparator and `mise check` share one extractor.
   The ten scenarios of the toolbox's harness run as an integration test against real git in `packages`.
   The dry run keeps its honest preview in scratch clones; that scratch work is the one documented exception to "a dry run performs no effect", performed in every mode because nothing the operator owns changes.
   Done, and the first verb a repo's CI runs rather than the maintainers' workspace: `changeset`, mounted on the update bot's pull requests by the reusable `_changeset.yml`, with the runner taking `plx` as one line in the repo's tools table.
3. Done: `changed-apps` and `deploy-targets`.
   Read-only, run in CI: each reusable workflow calls `plx` after `mise install`, and the tenant repo takes `plx` as one line in its tools table, written by the repo presets and moved by the train.
   `changed-apps` was retired by train 0.111.0 in favour of the content hashes of `plx-ci plan`, which Turbo computes over the same workspace graph.
4. Done: `deploy`, as a sequence of fine-grained ssh steps over one multiplexed connection, each a one-liner the dry run prints verbatim, the readiness poll the one remote loop, cleanup and the connection's close in a `finally`.
   Tested with the fake Io and with a fake `ssh` on `PATH` that runs each step locally against a scratch app dir with fake `docker` and `curl`, the old offline harness reborn; the dogfood tenant's deploys are the proof in production.
   With it the workflow repo lost its last script, and the workflows' one check is actionlint.
5. Done: `update`, the tenant side of the train: the pull request by which a repo takes a train, made from inside the repo in a worktree of its branch, mounted by the presets' `update.yml` on a schedule in the tenant's own CI and run by hand otherwise.
   It decides first whether the repo needs the train ([§ 3 PLX-Updates](updates.md)), and it is the only thing that opens that pull request: `ship` ends at the release, and `propagate` is `update` run in every generated repo under a directory.
   It is tested in the harness `ship` came with, against real git and the fake forge.
6. Done, as `plx-ci` (trains 0.106.0 to 0.111.0): the CI verbs, written in TypeScript from the start rather than ported, with the cloud's API and the registry's S3 spoken through `curl` so that the jobs need no provider's CLI; tested against fakes of the cloud, the registry and the forge.
7. Done: the split by role (§ 1).
   The upstream's verb, `ship` with its bookkeeping and the dry run's preview of the consumers, left `plx` for `plx-dev`, an unpublished package in `primitives` that `mise ship` runs from the maintainers' checkout, which ended the release tool being a release of what it releases (§ 3); a published `plx-dev` pinned by the maintainers' workspace was the alternative, and was not taken because it would have kept that problem.
   `@plexus-ms/lib` was split along the same line, and the train's offline harness moved with `ship`, since it exercises cutting and taking end to end.
   The operator's verbs and `requirements` stayed in the base with the tenant's; the pre-cut canary, once it leaves `ship`, joins `plx-dev`.
8. `new`, new ground, and `doctor` without a compendium checkout, so that a tenant runs its own staleness check.
   The data is there since `ship` attaches the train manifest to the compendium's release ([PLX-Updates](updates.md), Maintaining), and `update` already reads it; `doctor` reading it too is what remains.


## Maintaining

`plexus-ms/primitives` ships the tools as `@plexus-ms/cli` and `@plexus-ms/cli-ci` with `@plexus-ms/lib` as their core, versioned by the train and published with provenance from the train's release (§ 1.6 PLX); the repo presets write the pins into every tenant repo and the train moves them.
`plx-dev` is the workspace package `packages/dev` beside them, private and never published: `mise ship` builds it and runs it, and nothing outside the maintainers' checkout depends on it.
Inside `primitives` the tools are workspace packages: `pnpm plx` runs the checkout's own build, which `pnpm install` produces, and the reusable workflows' `primitives-ref` input builds `plx-ci` from a checkout for a trial ([PLX-Delivery](delivery.md), Maintaining).
The page became a candidate with the train that moved the deploy verb, once the tool described was one a tenant's CI runs and not only the maintainers' helpers; it becomes standard, with the rules of § 4 as its requirements, when two tenants' repos that are not the maintainers' pin it.

Debts: the preset's playbook wrapper is still shell outside the tool and is brought under a check or dissolved into its mise tasks; `new` and a `doctor` without a compendium checkout (§ 6) are not written; `plx-ci --version` reports the train number only once the train writes it, so a build from a branch names the previous train.
The copier version `plx` pins (`COPIER_VERSION` in `packages/lib/src/copier.ts`) carries a `// renovate:` annotation that a regex manager in `primitives`' `renovate.json` reads; the bump is never automerged, because it changes how every consumer is propagated, and the next train ships it.
The tool is a primitive of [PLX-Delivery](delivery.md), [PLX-Updates](updates.md) and § 13.4 PLX, and each of their Maintaining sections points here.
