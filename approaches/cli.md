---
title: A Plexus CLI
short_title: CLI
description: Considerations for folding the shell verbs and maintainer helpers into one published command-line tool — what would justify it, where it would live, what it must not become, and in which order the verbs would move.
maturity: note
binds: repo
depends: [PLX-Repo]
order: 29
---

This page records the case for one published command-line tool, `plexus`, in place of the shell scripts that today carry the verbs and the maintainers' helpers.
It is a note: a decision recorded with its reasoning and its trigger, no primitive shipped.
Nothing on this page changes what a repo runs today.


## § 1 What exists

The verbs and helpers are bash, split by where they run.
The maintainers' toolbox holds the release train (`ship`), the workspace map (`overview`) and the staleness check (`staleness`, § 13.4 PLX), with an offline harness for the first and the last.
`ci-cd` holds the ops verbs `deploy`, `changed-apps` and `deploy-targets`, mounted on the forge by thin reusable workflows and run by hand from a checkout otherwise ([PLX-Delivery](delivery.md)).
The compendium holds `requirements.sh`, the linter and extractor for the standard's requirement lines (§ 1.8 PLX).
The platform preset ships a playbook wrapper that prefixes the vault's CLI, and both repo presets ship the contract verbs and `sync` as mise tasks.

The volume is small, about two thousand lines upstream, and the discipline is uniform: a header stating what the script does and how to run it by hand, strict mode, shellcheck clean, a `check` verb that enforces both.
Every script passes the second-reader and degradation tests of the [manifesto](../essentials/manifesto.md).
Volume alone is no reason to replace it.


## § 2 What would justify a CLI

Three things in the current surface are debts a shell script cannot pay, and all three are answered by the same tool.

**One parser instead of five.**
The declaration marker (§ 1.4 PLX), a module's frontmatter (§ 1.3 PLX), copier's answers file, the app record in a tenant's inventory ([§ 3 PLX-Platform](platform.md)) and the labels in `compose.yaml` ([PLX-App](../contracts/app.md)) are each read today by whichever awk or sed last touched them: `ship` edits markers and frontmatter, `staleness` reads frontmatter, `deploy-targets` reads inventory records, `requirements.sh` reads module pages, `overview` reads answers files.
Each is honest about its limits, and together they are an unwritten contract: a quoted value, an indented list or a reordered key breaks one of them silently.
A tool with a YAML library and one frontmatter reader gives Plexus a single definition of its own file shapes, which the modules can then point at.

**Rung one of the ladder for the verbs themselves.**
The deploy verb reaches a tenant's CI as a checkout of `ci-cd` at a train tag, the movable-tag edge § 1.6 PLX names and accepts.
The playbook wrapper and the `promote` and `sync` tasks reach a tenant by copier, the second rung of § 4.3 PLX.
A published `@plexus-ms/cli` is immutable and provenance-attested ([§ 5 PLX-Delivery](delivery.md)), pinned in a repo's `mise.toml`, and bumped by the update bot under the stratification of [§ 2 PLX-Updates](updates.md).
For the verbs that is a tighter supply chain, not only better ergonomics.

**The verbs not written yet.**
`new tenant`, `new repo`, `new app`, and a `doctor` that runs the staleness check inside one tenant.
§ 13.4 PLX defers the tenant-side staleness check to a tenant that is not also the maintainer, because a toolbox script cannot travel; a subcommand of a pinned tool can.
Those are the primitives that move the marginal tenant's cost toward zero.


## § 3 Where it would live and what would run it

TypeScript in the `packages` repo, as `@plexus-ms/cli`, versioned by changesets and published through trusted publishing like every other package there, outside the train like the rest of `packages`.
The compendium's `requirements.sh` and the toolbox's `ship` are maintainer helpers and stay public all the same: they are methodology, and they carry no tenant's substance.

The runtime is no objection.
mise installs npm tools directly, which is how `renovate-config` pins its validator today, and every repo and every CI runner already goes through mise ([§ 2 PLX-Repo](../contracts/repo.md)).
A platform repo does not take node into its toolchain; it takes one line in its tools table, and the bot keeps that line current.
A few hundred lines of TypeScript with a YAML dependency read in half an hour at least as well as the awk they replace, and they take unit tests in the ordinary way instead of a bash harness faking copier and mise.


## § 4 What it must not become

The manifesto's objection to control planes applies to a tool of one's own.
Three rules keep a CLI a bag of verbs rather than a system:

- Every subcommand is stateless and hand-runnable, and `--dry-run` prints the exact shell and ssh it would run.
  A stranded operator copies the printed commands; that is the degradation test, kept.
- The tool has no configuration file of its own.
  It reads the artifacts that already exist: markers, inventory, answers files, `compose.yaml`, module pages.
- The host side stays bash.
  The remote half of the deploy verb, the script ssh feeds to the host, is a string the tool carries verbatim and shellchecks in its own tests.
  Hosts have bash and docker and nothing else, and that stays true.


## § 5 What it would not solve

The command tasks in the infrastructure roles stay Ansible and still need an offline test of their own ([PLX-Infrastructure](infrastructure.md), Maintaining).
The hook and task stanzas repeated across the upstream repos stay manual sync, because the upstream repos are not consumers of any preset.
A tenant's restore drill scripts and per-app backup hooks are the prototypes of [backups per service](backup.md) and move upstream with that module, not with this one.


## § 6 Order of migration

If the decision falls for the tool, the verbs move in order of risk, each replacing one script and leaving the rest as they are:

1. The parser library, with `staleness` and the compendium's requirement check on top of it.
   Read-only, maintainer-side, and `ship` can call both while it is still bash.
2. `changed-apps` and `deploy-targets`.
   Read-only, run in CI, where each `ci-cd` wrapper changes one line.
3. `deploy`, with the remote half carried verbatim, run against the existing offline harness of fake `docker` and `curl` before the dogfood tenant takes it.
4. `ship` last: the largest script, the best harness to diff against, and the one that loses the most sed.
5. `new` and `doctor`, new ground, after the parser has settled on the formats above.


## Maintaining

The trigger that reopens this page is any of the three in § 2 becoming acute: a format change that breaks one of the five parsers, a decision to close the movable-tag edge of § 1.6 PLX, or a tenant that is not the maintainer asking for `doctor` or `new`.
Until then the debts of § 2 are paid in place: the marker and record shapes the parsers assume are stated in [§ 1.4 PLX](../essentials/standard.md) and [§ 3 PLX-Platform](platform.md), the preset's playbook wrapper is brought under the same check as every other script or dissolved into its mise tasks, and the offline fixtures of the toolbox harness cover the compendium's modules and the preset's inventory.

The page becomes a candidate module when the first subcommand ships from `packages` and one repo pins it; it becomes standard when two tenants' repos do.
The tool is a primitive of several modules, [PLX-Delivery](delivery.md), [PLX-Updates](updates.md) and § 13.4 PLX, and each of their Maintaining sections points here once a verb of theirs has moved.
