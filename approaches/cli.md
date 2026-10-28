---
title: The Plexus CLI
short_title: CLI
description: plx, the one published command-line tool that carries the ops verbs and the maintainers' helpers — why it replaced the shell scripts, where it lives, what it must not become, and how a repo takes it.
code: PLX-CLI
maturity: candidate
binds: repo
depends: [PLX-Repo]
order: 29
---

This module is `plx`, published as `@plexus-ms/cli`: one command-line tool that carries the ops verbs a tenant's CI runs and the helpers the maintainers run, in place of the shell scripts that carried them before.
A repo takes it as one line in its `mise.toml` tools table, written by the repo presets and bumped by the update bot, and its workflows call the pin.
The page keeps the case that was made for the tool and the rules that keep it a bag of verbs rather than a system; it is a candidate, so it states no requirements yet.


## § 1 What exists

The maintainers' helpers have moved: `plx`, published as `@plexus-ms/cli` from `packages` with `@plexus-ms/lib` as its core, carries the workspace map (`overview`), the staleness check (`doctor`, § 13.4 PLX), the release train (`ship`, `propagate`), the standard's requirements check (`requirements`, § 1.8 PLX) and the changeset a dependency bump owes (`changeset`, [§ 5 PLX-Delivery](delivery.md)).
The maintainers run the workspace verbs as plain `plx` commands from the root of their workspace, whose `mise.toml` takes the newest release; the compendium pins it in its own `mise.toml` for `requirements`.
The ops verbs have followed: `changed-apps`, `deploy-targets` and `deploy` are commands of the tool ([PLX-Delivery](delivery.md)), mounted on the forge by `ci-cd`'s thin reusable workflows, which call the `plx` the tenant repo pins in its `mise.toml`, and run by hand from a checkout otherwise.
`ci-cd` carries no logic any more, only the mounts.
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
The deploy verb reached a tenant's CI as a checkout of `ci-cd` at a train tag, the movable-tag edge § 1.6 PLX names and accepts; the train tag now pins only the workflows.
The playbook wrapper and the `promote` and `sync` tasks still reach a tenant by copier, the second rung of § 4.3 PLX.
A published `@plexus-ms/cli` is immutable and provenance-attested ([§ 5 PLX-Delivery](delivery.md)), pinned in a repo's `mise.toml`, and bumped by the update bot under the stratification of [§ 2 PLX-Updates](updates.md).
For the verbs that is a tighter supply chain, not only better ergonomics.

**The verbs not written yet.**
`new tenant`, `new repo`, `new app`, and a `doctor` that runs the staleness check inside one tenant.
§ 13.4 PLX defers the tenant-side staleness check to a tenant that is not also the maintainer, because a toolbox script cannot travel; a subcommand of a pinned tool can.
Those are the primitives that move the marginal tenant's cost toward zero.


## § 3 Where it lives and what runs it

TypeScript in the `packages` repo, as `@plexus-ms/cli`, versioned by changesets and published through trusted publishing like every other package there, outside the train like the rest of `packages`.
The requirements check and `ship` are maintainer helpers and are public all the same: they are methodology, and they carry no tenant's substance.

The runtime is no objection.
mise installs npm tools directly, which is how `renovate-config` pins its validator today, and every repo and every CI runner already goes through mise ([§ 2 PLX-Repo](../contracts/repo.md)).
A platform repo does not take node into its toolchain; it takes one line in its tools table, mise brings the runtime, and the bot keeps that line current.
A few hundred lines of TypeScript with a YAML dependency read in half an hour at least as well as the awk they replaced, and they take unit tests in the ordinary way; the bash harnesses that faked copier, mise, docker and curl live on as integration tests in `packages`.

The train pins the workflows and the tenant pins the verbs, and the two move independently through reviewed pull requests.
A workflow that asks for a verb the pinned `plx` lacks fails as a usage error, loudly; no compatibility floor is checked, because no incident has asked for one.

The maintainers' workspace is the exception that takes no pin: its `mise.toml` asks for the newest release, because the release tool has to be newer than anything it releases.
From 0.7.0, `ship` and `propagate` hold the running `plx` against the registry (`npm view @plexus-ms/cli version`) and refuse to run behind it; an unreachable registry only warns.
The workspace exempts the tool from mise's minimum release age (`minimum_release_age_excludes`), as pnpm and the update bot already exempt `@plexus-ms`: without that, `mise up` holds a fresh release back for a day while `ship` refuses to run behind it.
mise also caches a tool's version list, so the update the refusal names is `mise cache clear npm:@plexus-ms/cli && mise up npm:@plexus-ms/cli`.
The copier a propagation runs is pinned inside `plx` and run as `mise exec copier@<version> -- copier`, which the dry run prints like every other step: the copier a consumer is updated with travels with the tool, and the operator's `PATH` has no say in it.


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
   Done, and the first verb a repo's CI runs rather than the maintainers' workspace: `changeset`, mounted on the update bot's pull requests by `ci-cd`'s `_changeset.yml`, with the runner taking `plx` as one line in the repo's tools table.
3. Done: `changed-apps` and `deploy-targets`.
   Read-only, run in CI: each `ci-cd` wrapper calls `plx` after `mise install`, and the tenant repo takes `plx` as one line in its tools table, written by the repo presets and bumped by the update bot.
   The train pins the workflows and the tenant pins the verbs; a workflow that asks for a verb the pinned `plx` lacks fails as a usage error, loudly, and no compatibility floor is checked, because no incident has asked for one.
   pnpm's range filter stays the authority on the workspace graph; the rules pnpm cannot know (bookkeeping is not source, a workspace-global input deploys everything, a platform repo is a path diff) are the verb's own, with tests.
4. Done: `deploy`, as a sequence of fine-grained ssh steps over one multiplexed connection, each a one-liner the dry run prints verbatim, the readiness poll the one remote loop, cleanup and the connection's close in a `finally`.
   Tested with the fake Io and with a fake `ssh` on `PATH` that runs each step locally against a scratch app dir with fake `docker` and `curl`, the old offline harness reborn; the dogfood tenant's deploys are the proof in production.
   With it `ci-cd` lost its last script, and its one check is actionlint over the workflows.
5. `new`, new ground, and `doctor` without a compendium checkout, so that a tenant runs its own staleness check.


## Maintaining

`plexus-ms/packages` ships the tool as `@plexus-ms/cli` with `@plexus-ms/lib` as its core, versioned by changesets and published with provenance ([§ 5 PLX-Delivery](delivery.md)); the repo presets write the pin into every tenant repo and the update bot moves it.
The page became a candidate with the train that moved the deploy verb, once the tool described was one a tenant's CI runs and not only the maintainers' helpers; it becomes standard, with the rules of § 4 as its requirements, when two tenants' repos that are not the maintainers' pin it.

Debts: the preset's playbook wrapper is still shell outside the tool and is brought under a check or dissolved into its mise tasks; `new` and a `doctor` without a compendium checkout (§ 6) are not written; whether the update bot bumps the `npm:` pin in a tenant's `mise.toml` is confirmed by the first bump it opens.
The copier version `plx` pins (`COPIER_VERSION` in `packages/lib/src/copier.ts`) carries a `// renovate:` annotation that a regex manager in `packages`' `renovate.json` reads; the bump is never automerged, because it changes how every consumer is propagated, and `plx changeset` owes it a patch like any runtime dependency.
The tool is a primitive of [PLX-Delivery](delivery.md), [PLX-Updates](updates.md) and § 13.4 PLX, and each of their Maintaining sections points here.
