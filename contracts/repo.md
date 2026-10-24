---
title: PLX-Repo – the repo contract
short_title: PLX-Repo
description: What Plexus asks of every repo — a declaration marker, mise and hk as the one executable answer to "how do I run you", and the four standard verbs.
code: PLX-Repo
maturity: standard
binds: repo
changed: 0.60.0
depends: []
order: 10
---

The repo contract sits at the seam between a repo and everything that operates on it: a developer at a fresh checkout, a git hook, a CI job, the staleness check.
It asks three things of a repo, and nothing about what the repo contains: that it declares what it follows, that it answers the standard verbs through one front door, and that its checks run before code leaves the machine.
A JS/TS monorepo, a Python service, an Ansible platform repo and the compendium itself take the same contract with different incantations behind the same names.
The sections bind the repo, the authors' side; what the operating side owes in return is stated where it applies.

Every other module that binds a repo or an app depends on this one: [PLX-App](app.md) asks for its verbs, [PLX-CI](../approaches/ci.md) calls them, [PLX-Updates](../approaches/updates.md) bumps the pins that live where this contract says facts live.


## § 1 The declaration marker

> - Every repo MUST carry a `PLEXUS.md` marker at its root.
> - The marker MUST carry YAML frontmatter with `plexus`, the Plexus version the repo was last brought up to, and `modules`, the list of module codes the repo follows.
> - `modules` MUST include this module, and for every module it lists, every module that one depends on, unless an enclosing declaration lists it (§ 1.4 PLX).
> - A repo whose marker is missing or unparsable follows no module.

The marker is the one artifact the standard cannot degrade gracefully without, because it is how staleness stays visible (§ 1.4 PLX).
Machine checks read only the frontmatter; the body is for humans, and it is where owned deviations live:

```markdown
---
plexus: 0.60.0
modules: [PLX-Repo, PLX-JS, PLX-Release, PLX-CI, PLX-Updates]
---

- Free-form prose.
- Owned deviations live here, one bullet each, with rationale.
```

A repo that follows only this module is a complete consumer; there is no global verdict to fail.
What the marker buys is a precise answer to "is this repo behind": for each listed module, whether that module's requirements changed in a train newer than the declared version.


## § 2 mise and hk

> - Every repo MUST expose its verbs as mise tasks at the repo root, and MUST bootstrap its stack's entry-point tools in `mise.toml`.
> - A fact with an ecosystem-canonical home MUST live in that home and MUST NOT be restated elsewhere; mise pins only facts that have no such home.
> - Every repo MUST wire its checks through hk git hooks: format and lint on pre-commit, `check` and `test` on pre-push, with stack-appropriate checks behind the same hook names.
> - Git hooks SHOULD delegate to mise tasks.
> - mise tasks MUST NOT encode cross-project ordering; the task graph belongs to the stack's graph-aware tool, to which the verbs delegate.

Plexus mandates the language-neutral [mise-en-place](https://mise.jdx.dev/) for toolchain management and [hk](https://hk.jdx.dev/) for git-hook wiring, and these are the two tools this contract names.
Both are hard requirements rather than suggested defaults because the contract's whole point is one executable answer to "how do I run you": the CI approach calls `mise :check` and nothing else, a second reader at any Plexus repo types the same four verbs, and a hook that bypasses mise would be a second encoding of the same check.

mise is the front door, not the landlord: it bootstraps the stack's entry point onto the PATH, exports env, wires hooks, and names the verbs, then hands off to the stack's own machinery, and every fact past the bootstrap lives where its ecosystem natively binds it.
The canonical home matters twice over: it is where a developer of that stack already looks, and it is the API the machine ecosystem reads.
Update bots, IDEs, and the stack's own tools all consume the canonical files and are blind to a custom scheme.
The shell is accordingly graph-blind: mise knows nothing of a workspace's dependency edges, and every ecosystem already has a graph-aware tool that does (cargo, go, gradle natively; JS/TS via the one [PLX-JS](../approaches/js.md) designates).
That delegation is one line in one task, which makes it the deliberate swap point: a repo that outgrows its orchestrator changes the line behind the verbs, and nothing above them.
hk configuration (`hk.pkl`) is likewise a plumbing layer over mise tasks, which is why hooks delegate.
Hooks self-install via the `mise.toml` `[hooks] postinstall` on the first `mise install`, with no per-repo or per-machine step; `HK=0 git …` bypasses a hook when needed.

The answer to *"how do I run you?"* is always a mise verb, asked at the repo root: `mise :verb` answers repo-wide, `mise :verb <app>` scopes the answer to one app.
The verbs live only at the root; a per-app `mise.toml` would be a second encoding of the same delegation.


## § 3 The standard verbs

> - Every repo MUST answer the standard verbs as root mise tasks, each taking an optional app argument: `dev`, `build`, `check`, `test`.
> - `dev` MUST take a fresh checkout to a running development environment; `build` MUST produce the production artifact; `check` MUST run every static check that gates a deploy; `test` MUST run the tests that gate a deploy, providing whatever environment they need.
> - Every verb MUST succeed from a fresh checkout; installing dependencies and building internal workspace packages first is the repo's own business, never the caller's.
> - A verb a given stack has no use for MUST still exist and pass (a documented no-op), never as a missing verb.

The verbs are the stack-neutral layer every repo answers; a toolchain module such as [PLX-JS](../approaches/js.md) specifies the incantations behind them for one stack.
The shared pipeline ([PLX-CI](../approaches/ci.md)) invokes a repo only through these names, so the names are load-bearing and the incantations are not.
They are deliberately stack-neutral: `check` subsumes what a JS/TS repo answers with biome and tsc and a Go repo answers with vet; *typecheck* and *lint* were incantations posing as contract.
Migration is deliberately not a verb: at deploy time the repo is absent and the artifact is what is present, so migrating is a capability of the image, declared in the app's `compose.yaml` ([PLX-AppStateful](app-stateful.md)) and invoked by the deploy verb through docker.
Toolchain pinning follows § 2, so setup is `git clone && mise :dev` everywhere.


## Maintaining

The contract names no stack, and the pressure to let one in is constant: every new incantation looks like it belongs here first.
The test is whether a repo in a different stack could answer the line unchanged.
If not, it belongs in a toolchain module.

The marker's frontmatter is read by the staleness check (§ 13.4 PLX) once it ships, and by `ship` when it stamps `changed` on the modules; the format changes only with a major train.

Approaches on the authors' side: [PLX-JS](../approaches/js.md), [PLX-Packages](../approaches/packages.md), [PLX-Updates](../approaches/updates.md).
On the operating side: [PLX-CI](../approaches/ci.md), the hooks, the staleness check (§ 13.4 PLX).
