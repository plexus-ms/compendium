---
title: PLX-Repo – the repo contract
short_title: PLX-Repo
description: What Plexus asks of every repo — a marker, mise and hk as the one executable answer to "how do I run you", and the standard verbs.
code: PLX-Repo
maturity: standard
binds: repo
depends: []
order: 1
---

The repo contract sits at the seam between a repo and everything that operates on it: a developer at a fresh checkout, a git hook, a CI job, `plx doctor`.
It asks three things of a repo, and nothing about what the repo contains: that it carries a marker, that it answers the standard verbs through one front door, and that its checks run before code leaves the machine.
A JS/TS monorepo, a Python service, an Ansible operations repo and the compendium itself take the same contract with different incantations behind the same names.
The requirements bind the repo, the authors' side, except where a line names the operating side.

Every other module that binds a repo or an app depends on this one: [PLX-App](app.md) asks for its verbs, [PLX-Delivery](../approaches/delivery.md) calls them, [PLX-Updates](../approaches/updates.md) bumps the pins that live where this contract says facts live.


## § 1 The marker

> - `PLX-Repo/Marker`: Every repo MUST carry a `PLEXUS.md` marker at its root whose YAML frontmatter parses.

`plx doctor` checks `PLX-Repo/Marker`.

The marker's format is that of § 1.4 PLX; a repo's marker carries no `profile`, which is an app's.
A repo is bound by this contract by being a repo; the marker does not list what the repo follows, and the Plexus version it is on is its `plx` pin (§ 1.5 PLX).


## § 2 mise and hk

> - `PLX-Repo/Toolchain`: Every repo MUST bootstrap its stack's entry-point tools in `mise.toml`.
> - `PLX-Repo/CanonicalHome`: A fact with an ecosystem-canonical home MUST live in that home and MUST NOT be restated elsewhere.
> - `PLX-Repo/Hooks`: Every repo MUST wire hk git hooks that run `lint` on pre-commit and `check` on pre-push.
> - `PLX-Repo/HooksDelegate`: Git hooks SHOULD delegate to mise tasks.
> - `PLX-Repo/NoTaskGraph`: mise tasks MUST NOT encode cross-project ordering.

Plexus mandates the language-neutral [mise-en-place](https://mise.jdx.dev/) for toolchain management and [hk](https://hk.jdx.dev/) for git-hook wiring, and these are the two tools this contract names.
Both are required rather than suggested defaults because the contract's whole point is one executable answer to "how do I run you".
The pipeline calls `mise :verify` and nothing else, a second reader at any Plexus repo types the same three verbs, and a hook that bypasses mise would be a second encoding of the same check.

mise is the front door, not the landlord: it bootstraps the stack's entry point onto the PATH, exports env, wires hooks, and names the verbs, then hands off to the stack's own machinery.
Every fact past the bootstrap lives where its ecosystem natively binds it; mise pins only the facts that have no such home.
The canonical home matters twice over: it is where a developer of that stack already looks, and it is the API the machine ecosystem reads.
Update bots, IDEs, and the stack's own tools all consume the canonical files and are blind to a custom scheme.
The shell is accordingly graph-blind: the task graph belongs to the stack's graph-aware tool, to which the verbs delegate.
mise knows nothing of a workspace's dependency edges and every ecosystem already has a tool that does (cargo, go, gradle natively; JS/TS via the one [PLX-JS](../approaches/js.md) designates).
That delegation is one line in one task, which makes it the deliberate swap point: a repo that outgrows its orchestrator changes the line behind the verbs, and nothing above them.
hk configuration (`hk.pkl`) is likewise a plumbing layer over mise tasks, which is why hooks delegate.
Behind the two hook names each stack runs its own checks; whether `test` runs on pre-push as well is the repo's choice.
Hooks self-install via the `mise.toml` `[hooks] postinstall` on the first `mise install`, with no per-repo or per-machine step; `HK=0 git …` bypasses a hook when needed.
The templates' `postinstall` installs the hooks only where hk is on the PATH.
A CI job whose mise installs only the tools the job names has no hk and needs no hooks, so the step stays silent there instead of failing.

The answer to *"how do I run you?"* is always a mise verb, asked at the repo root: `mise :verb` answers repo-wide, `mise :verb <app>` scopes the answer to one app.
The verbs live only at the root; a per-app `mise.toml` would be a second encoding of the same delegation.


## § 3 The standard verbs

> - `PLX-Repo/Verbs`: Every repo MUST answer `dev`, `build` and `verify` as root mise tasks, each taking an optional app argument, a verb the repo has no use for existing all the same as a no-op that passes.
> - `PLX-Repo/SubVerbs`: `verify` MUST be `check` followed by `test`, each a root mise task, and `check` MUST include `lint`, a root mise task as well.
> - `PLX-Repo/VerbSemantics`: The verbs MUST achieve what their names promise: `dev` takes a fresh checkout to a running development environment; `build` produces the production artifact; `verify` performs every automated step that ascertains code quality, providing whatever environment those steps need; `lint` checks style and formatting, fixable in place; `check` runs every static check and nothing that executes the code under test; `test` runs everything that executes code, pure unit tests included.
> - `PLX-Repo/FreshCheckout`: Every verb MUST succeed from a fresh checkout; installing dependencies and building internal workspace packages first is the repo's own business, never the caller's.
> - `PLX-Repo/OperatorBoundary`: Whatever operates on a repo without having written it, the pipeline first, MUST reach it only through the standard verbs and the image build of `PLX-App/Dockerfile`.

`plx doctor` checks of `PLX-Repo/Verbs` that `dev`, `build` and `verify` exist as root mise tasks, and of `PLX-Repo/SubVerbs` that `lint`, `check`, `test` and `verify` do, not what they run, in which order, or whether they pass.

The verbs are the stack-neutral layer every repo answers, and a stack that has no use for a verb answers it with a documented no-op, never with a missing verb.
`PLX-Repo/OperatorBoundary` binds the operating side, not the repo.
A toolchain module such as [PLX-JS](../approaches/js.md) specifies the incantations behind them for one stack.
The pipeline ([§ 1 PLX-Delivery](../approaches/delivery.md)) invokes a repo only through these names, so the names are load-bearing and the incantations are not.
They are deliberately stack-neutral: `verify` subsumes what a JS/TS repo answers with biome, tsc and vitest and a Go repo answers with vet and `go test`.
*Typecheck* was an incantation posing as contract.
The sub-verbs nest by cost, which is what places them on the hooks.
`lint` takes seconds and is cheap enough to run on every commit, `check` on every push, and `test` wherever the repo can afford the environment it needs, the pipeline at the latest.
`verify` is the one name the pipeline knows; it answers repo-wide, or scoped to one app and its dependencies when the pipeline gates that app alone.
Migration is deliberately not a verb: at deploy time the repo is absent and the artifact is what is present.
Migrating is a capability of the image, declared in the app's compose file (`PLX-App/Stateful/MigrateService`) and invoked by the deploy verb through docker.
Toolchain pinning follows § 2, so setup is `git clone && mise :dev` everywhere.


## Maintaining

The contract names no stack, and the pressure to let one in is constant: every new incantation looks like it belongs here first.
The test is whether a repo in a different stack could answer the line unchanged.
If not, it belongs in a toolchain module.

The marker's frontmatter is read by `plx doctor` (§ 13.4 PLX); its format changes only with a major version.

Approaches on the authors' side: [PLX-JS](../approaches/js.md), [§ 5 PLX-Delivery](../approaches/delivery.md), [PLX-Updates](../approaches/updates.md).
On the operating side: [PLX-Delivery](../approaches/delivery.md), the hooks, `plx doctor` (§ 13.4 PLX).
