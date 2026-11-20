---
title: The Plexus CLI
short_title: CLI
description: The plx family of command-line tools — the published plx with the tenant's and the operator's verbs and plx-ci with the CI verbs, and the unpublished plx-dev that cuts the version — why it replaced the shell scripts, where it lives, what it must not become, and how a repo takes it.
code: PLX-CLI
maturity: candidate
binds: repo
depends: [PLX-Repo]
order: 29
---

This module is the `plx` family of command-line tools, all on `@plexus-ms/lib`:

- `plx`, published as `@plexus-ms/cli`, the base in every tenant repo, with the ops verbs a tenant's CI runs and the helpers an operator of many repos runs;
- `plx-ci`, published as `@plexus-ms/cli-ci`, the CI verbs on top of it;
- `plx-dev`, which cuts the version and is never published.

A repo takes each published tool as one line in its `mise.toml` tools table, written by the repo templates and moved with each version the repo takes, and its workflows call the pins.
The page states the case for the tool and the rules that keep it a bag of verbs rather than a system; it is a candidate, so it states no requirements yet.


## § 1 What exists

`plx` carries these verbs, each documented in the header of its source in `tooling`:

- `overview`, the map of a folder of repos;
- `doctor`, the repo's checks (§ 13.4 PLX);
- `update`, by which a repo takes a version, and `update --recursive`, which runs it over many repos ([§ 3 PLX-Updates](updates.md));
- `requirements`, the standard's requirements check (§ 1.8 PLX);
- `changeset`, the changeset a dependency bump owes ([§ 5 PLX-Delivery](delivery.md));
- `umbrella up` and `umbrella down`, one pnpm workspace over several clones for developing a package in the app of another repo ([§ 5 PLX-Delivery](delivery.md));
- `deploy-targets` and `deploy`, the ops verbs ([§ 6 PLX-Delivery](delivery.md)).

The ops verbs are mounted on the forge by the thin reusable workflows next to the tool in `tooling`, which call the `plx` the tenant repo pins, and are run by hand from a checkout otherwise.
The workflows carry no logic, only the mounts.

`plx-ci` carries the CI verbs ([§ 8 PLX-Delivery](delivery.md)), at the Plexus version from the same repo.
Every strategy runs `registry`, `plan`, `build`, `test`, `publish` and `report`, which read the strategy, the registry and the overlay from `CI_STRATEGY`, `CI_REGISTRY` and `CI_OVERLAY`.
Under `hybrid` the instances have verbs of their own, `hybrid create-instances`, `destroy-instances` and `sweep-instances`.
Each is one line of a reusable workflow and runnable by hand with the same keys in the environment.
It is a package of its own so that the CI of one tenant can change without moving every tenant's `plx`, and so that an operations repo, which builds nothing, carries only the base.

`plx-dev` cuts a version (`ship`, § 1.5 PLX); it is the unpublished package `@plexus-ms/dev` in `tooling`, run from the maintainers' checkout of it (§ 3).

The verbs serve three roles: the upstream, which cuts a version (`plx-dev ship`); a tenant repo, which lives on one (`update`, `deploy`, `deploy-targets`, `changeset`); and an operator of many repos, the maintainers or a tenant's own (`overview`, `doctor`, `update --recursive`, `umbrella`).
Two tests draw the line between the first and the other two: the upstream's verbs work with no knowledge of any consumer, and the tenant's and the operator's work with published artifacts and the tenant's own repos alone.
The upstream's verbs are therefore not in `plx`, and `@plexus-ms/lib` holds nothing that cuts a version, so that a tenant repo pins nothing it cannot run.
The compendium's requirements check stays in `plx`: the compendium runs it from its pin in `mise check` like any repo's check, and it knows no consumer.
The shell that remains is the platform template's playbook wrapper, which prefixes the vault's CLI, and the contract verbs both repo templates ship as mise tasks.

The verbs are TypeScript rather than shell because dense bash, with its quoting and its heredocs, is harder for a human to maintain than TypeScript of the same portability.
The tighter supply chain of § 2 comes with it.


## § 2 What justified a CLI

Three things a shell-script surface cannot do are answered by the same tool.

**One parser instead of five.**
The marker (§ 1.4 PLX), a module's frontmatter (§ 1.3 PLX), copier's answers file, the app record in a tenant's inventory ([§ 3 PLX-Platform](platform.md)) and the labels in `compose.yaml` ([PLX-App](../contracts/app.md)) are formats that several verbs read.
Read by separate awk or sed, they form an unwritten contract: a quoted value, an indented list or a reordered key breaks one reader silently.
`@plexus-ms/lib` holds one reader of the marker, the module frontmatter, the answers file and the inventory record, one line-based editor of frontmatter, one editor that sets an answer in the answers file as YAML, and one detector of conflict markers.
The compose file is parsed for one fact only, whether the app service declares a healthcheck, which the deploy verb refuses to go without.
Everything else the verb needs of it, it asks the running container, which is reality rather than a parse.

**Rung one of the ladder for the verbs themselves.**
A published `@plexus-ms/cli` is immutable and provenance-attested ([§ 5 PLX-Delivery](delivery.md)), pinned in a repo's `mise.toml` at the Plexus version, and moved by the pull request in which the repo takes a version ([§ 1 PLX-Updates](updates.md)).
The version tag of `tooling` pins only the workflows, and every version tag is locked by an immutable release (§ 1.6 PLX).
The playbook wrapper and the `promote` task reach a tenant by copier, the second rung of § 4.3 PLX.
For the verbs that is a tighter supply chain, not only better ergonomics.

**Verbs that travel.**
A toolbox script cannot travel to a tenant's repo; a subcommand of a pinned tool can.
The verbs that move the marginal tenant's cost toward zero, `new tenant`, `new repo` and `new app`, are not written.


## § 3 Where it lives and what runs it

TypeScript in `tooling`, as `@plexus-ms/cli` with `@plexus-ms/lib`, published through trusted publishing at the Plexus version (§ 1.5 PLX).
The tool is arrangement, like the workflows and the collections it sits beside, and one number names the version and the tools a repo runs.
It is released with the Plexus version (§ 1.5 PLX).
`plx-dev` and the requirements check are the maintainers' and are public all the same: they are methodology, and they carry no tenant's substance.

The runtime is no objection.
mise installs npm tools directly, and every repo and every CI runner already goes through mise ([§ 2 PLX-Repo](../contracts/repo.md)).
An operations repo has no Node toolchain, only the runtime the two tools run on, which it pins in its tools table like any tool; the bot keeps both lines current.
A few hundred lines of TypeScript with a YAML dependency read at least as well as awk, and they take unit tests in the ordinary way.
Integration tests in `tooling` fake copier, mise, docker, curl, `gh` and `npm`.

Taking a version moves the workflow refs and the tool's pin alike, in one pull request per consumer, so the verbs a workflow asks for are the ones the pinned `plx` has.
A workflow that asks for a verb the pinned `plx` lacks fails as a usage error, loudly.

The tool that cuts the version is neither pinned nor published (§ 1.5 PLX).
The copier an update runs is pinned inside `plx` and run through mise, which the dry run prints like every other step: the copier a repo is updated with travels with the tool, and the operator's `PATH` has no say in it.

A tool mise builds through uv, copier and Ansible among them, needs `python` pinned beside `uv`, since mise's Python keeps the uv tools' environments inside its cached data directory.
Whoever picks that pin owes that the pinned Python satisfies every uv tool's Python requirement, and follows a change to it by reinstalling them (`mise install -f <tool>`).


## § 4 What it must not become

The manifesto's objection to control planes applies to a tool of one's own.
Three rules keep a CLI a bag of verbs rather than a system:

- Every subcommand is stateless and hand-runnable, and `--dry-run` prints the exact shell and ssh it would run.
  A stranded operator copies the printed commands; that is the degradation test, kept.
- The tool has no configuration file of its own.
  It reads the artifacts that already exist: markers, inventory, answers files, `compose.yaml`, module pages.
- The host side needs bash and docker, and nothing else; that stays true.
  Every command the deploy verb sends over ssh is a one-liner the dry run prints verbatim, so what reaches a host is readable in the plan, not in a script shipped alongside.

The dry run of `ship` is the one exception to "a dry run performs no effect": it previews the unreleased templates in scratch clones, performed in every mode because nothing the operator owns changes.


## § 5 What it does not solve

The command tasks in the infrastructure roles stay Ansible ([PLX-Infrastructure](infrastructure.md)).
The hook and task stanzas repeated across the upstream repos stay manual sync, because the upstream repos are not consumers of any template.
A tenant's restore drill scripts and per-app backup hooks are the prototypes of [backups per service](backup.md) and move upstream with that module, not with this one.


## § 6 Order of migration

Every script the tool was written to replace is gone; the verbs not written are those of § 2.


## Maintaining

`plexus-ms/tooling` ships the tools as `@plexus-ms/cli` and `@plexus-ms/cli-ci` with `@plexus-ms/lib` as their core, at the Plexus version, published with provenance from that version's release (§ 1.6 PLX).
The repo templates write the pins into every tenant repo, and taking a version moves them.
`plx-dev` is the workspace package `packages/dev` beside them, private and never published: `mise ship` builds it and runs it, and nothing outside the maintainers' checkout depends on it.
The copier version `plx` pins carries an annotation that a regex manager in the `renovate.json` of `tooling` reads; the bump is never automerged, because it changes how every consumer is propagated.
The tool is a primitive of [PLX-Delivery](delivery.md), [PLX-Updates](updates.md) and § 13.4 PLX.

The page becomes standard, with the rules of § 4 as its requirements, when two tenants' repos that are not the maintainers' pin it.
