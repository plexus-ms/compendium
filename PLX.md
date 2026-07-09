---
title: PLX — The Plexus Standard
short_title: PLX
description: A comprehensive, opinionated, federated IT initiative. Standardized, boring, yours.
version: v0
timestamp: 2026-07-09
---

*A comprehensive, opinionated, federated IT initiative. Standardized, boring, yours.*

**Revision:** v0 — Request for Comments.

## Abstract

Plexus is a federation, not a platform: one tenant-neutral standard spanning dev to ops — published `@plexus-ms/*` packages and a pinned toolchain on the dev side (`library`), stateless verbs, CI wrappers, and Ansible roles on the ops side (`itops`), a copier template as the seam composing both into tenant monorepos (`preset`), and a tiny interface-shaped app contract where the two sides meet. Each tenant instantiates the standard into its own platform: one VM per tenant on shared tier-0 metal, with Caddy ingress, per-tenant secrets, and label-driven backups. Every primitive is stateless and passes the second-reader and degradation tests; state lives in git, the registry, the hosts, and the backup repo — never in a dashboard and never in your head. Improvements federate across all tenants automatically (Renovate, `copier update`); root, secrets, and data never do. The result is customer-1001 economics for your own infrastructure: each new project lands on the standard with near-zero overhead, and the fog lifts because nothing important is remembered — it's all runnable, greppable, and versioned.

This document is intended for Plexus contributors, and anyone operating any Plexus-governed tenant.

## Conformance language

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119), and — per [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174) — only when they appear in ALL CAPITALS. Everything else is informative: rationale, description, or documentation of the reference stack.

**The reference stack.** Where a concrete tool is named without a conformance keyword — GitHub and GHCR, Caddy, restic and a Hetzner Storage Box, 1Password and `op`, Renovate — the document is describing the *reference stack*: the implementation the `plexus-ms` repos are built for and the paved road (§ 4.1) assumes. Requirements are written tool-agnostically where possible; a tenant MAY substitute an equivalent for a reference-stack tool, but owns the divergence — the shared wrappers, roles, and presets target the reference stack only.

**Versioning of this standard.** The frontmatter `version` identifies the revision of PLX itself — `v0` while the standard is a draft RFC, then `vMAJOR.MINOR` (e.g. `v1.0`) once live — and `timestamp` records its date. Each released version is cut as a git tag of the `compendium` repository (optionally a GitHub Release). Minor revisions are additive or clarifying: a repo conformant to `v1.0` remains conformant under every `v1.x`; only a major revision may change or remove requirements. The contract version a repo records in its `PLEXUS.md` (§ 6) is the PLX version it targets.


## § 1 Why Plexus exists

When one operator, or a small team, runs several projects for several organizations, the surface area grows organically, not by design. 
As it grows, the dominant felt experience becomes **mental fog**:
losing track of what is deployed where, how configuration interacts, how to set up a given environment, and where one was mentally when last touching a project. 
Every system is slightly bespoke, every deployment is a unique snowflake, the operator's head quietly becomes the database.
Projects stay half-baked, never brought live properly, never documented enough for handoff.

**Plexus is the response.** 
It is neither a single product nor an opaque control plane. 
It is a collection of opinionated guidelines, tools, and approaches, with philosophies derived from this document.
They are intended to make doing the right thing the easy thing, so that each new project adds near-zero overhead.
Except where something *genuinely* demands bespoke config, projects should be boring and identical, and run on autopilot.
They should be made up of reusable, ideally stateless primitives that have clear interfaces and are simply composable.

### Two fundamental insights upfront

1. **Fog is a structure problem, not a discipline problem.**
  Fog is not fixed by promising to document more; documentation written *next to* a system drifts and rots.
  The fix is making the artifacts *be* the documentation, and **make everything as well-structured as possible — simple, easy, no magic.**
  If every project answers *"how do I run you?"* the same executable way, nothing needs to be remembered.

2. **Autopilot has a precise mechanism:** 
  **decide once, encode the decision in a versioned primitive, and propagate it to every project automatically (§ 8).**
  Most efforts get the first two steps and skip the third — and the propagation step is the whole game; without it every encoded decision is just another artifact that rots in place.
  Composition follows from it: primitives with clear interfaces get composed instead of reinvented — don't repeat yourself.


## § 2 Terminology

The document's private vocabulary, defined once:

- **Tenant** — one trust domain in the federation: its own forge org, monorepo, VM(s), secrets vault, backups. Nominally a distinct legal person or organization, but the boundary that matters is *access*, not legal personality — `plexus` itself is a tenant (the standard dogfooding its own methodology) without being one. The mostly-1:1:1:1 chain of legal person : forge org : monorepo : VM is the § 4.2/§ 4.3 rule, not part of the definition.
- **Primitive** — any named, versioned building block the standard ships or prescribes: a verb, a mount, an Ansible role, a published package, the copier template, or a convention (a label scheme, a file layout, an endpoint path). Decided once, versioned, reused — that is what makes something a primitive.
- **Verb** — a stateless, hand-runnable procedure that does one operational thing (deploy, backup, migrate), authored as a portable script or mise task. The executable answer to *"how do I run you?"*.
- **Mount** — the thin, disposable glue binding a verb or role to an event or state source it doesn't own: a workflow wrapper on forge events, a tenant playbook on an inventory, a systemd timer on the clock. Mounts carry no logic (§ 7).
- **Methodology / substance** — the federation's sharing axis (§ 4.2): *methodology* is knowledge and code-shaped-as-knowledge, shared across all tenants; *substance* is data, secrets, access, hosts — never shared.
- **Seam** — where the dev side and the ops side meet, made explicit as the app contract (§ 6).
- **The paved road** — the composed default path (toolchain, CI, deploy, backup) a new project lands on with near-zero overhead (§ 4.1).
- **Reference stack** — the concrete tool choices the paved road assumes; see *Conformance language* above.
- **Fog** — the operational memory loss described in § 1; the failure mode Plexus exists to eliminate.
- **`PLEXUS.md`** — the per-repo contract marker recording which PLX version the repo targets (§ 6). Deliberately distinct from `PLX.md`, this standard.


## § 3 Core principles

These principles are the load-bearing philosophy of Plexus.

However, they are not to be seen as non-negotiable, as in reality they will often be at odds with each other and require compromise, or will not be possible to implement at all.
When architecting new primitives or reworking existing ones, trade-offs must be considered and a balance must be struck.
Ideally, assumptions and constraints should be documented or clearly apparent to avoid second-guessing the structure.

- **Have state in Git, runnable, greppable.** 
  Control planes and other heavyweight ITOps applications routinely create opaque and stateful abstraction layers that are hard to see through and debug.
  They achieve developer experience gains with abstractions that might be referred to as "magic" or "black boxes".
  Also, they often rely on a database for state management, which displaces the Git repository as the source of truth.
  In Plexus, git owns *intent and definition*; the runtime owns *current state* — what is live right now is read from the host itself, never from a bookkeeping database (see § 7).
  Such tools, frameworks and managed services (e.g. Coolify, Dokploy, Vercel) are deliberately not part of Plexus for exactly these reasons.
- **Primitives should rarely remember anything.** 
  Primitives are best reused when authored as "verbs" / stateless procedures (deploy, backup, CI steps) and conventions (labels, file structures, endpoints), and then mounted on event and state sources that already exist. 
- **Standardize boundaries, free the core.** 
  Plexus aims to own those edges where apps touch shared components and logic (framework plumbing, common auth concerns, repeatable features that do not relate to the domain model) and shared infrastructure (ingress, secrets, deploy, backup, telemetry). 
  The core interior of an application, usually its data model and business logic, is not Plexus's concern.
  This core is an independent layer that can be engineered with test-driven development, and it is surprisingly small once everything that can be shared is lifted up.
- **Prefer "versioned dependency" over "copied scaffold".** 
  Publishing and versioning mechanisms should be preferred over copying and templating presets, where possible.
  Spending extra time extracting a shared package buys back many future hours of manual template sync.
- **Methodology crosses tenant lines; authority never does.** 
  Improvements in shared primitives federate to all tenants.
  Root, secrets, and data access stay siloed per tenant.

### Litmus tests to stay honest over time

- **The second-reader test:** Can a competent second person read a Plexus primitive top to bottom in half an hour and understand every line? If not, it's most likely too opaque.
- **The degradation test:** If a primitive vanished tonight, could the job still be done by hand from the same artifacts in git? If yes, it's automation of a procedure that remains manually executable, and it will be less likely to cause trouble. If no, it is a magic automation that strands the operator in its absence.


## § 4 Architecture

### § 4.1 The shape of the standard: two sides, one seam

Plexus is end-to-end: it standardizes both how software is *built* (dev) and how it is *run* (ops), because fog does not respect that border either. There is no hierarchy between these concerns — they are two ends of one spectrum, and the tenant-neutral repositories map onto it directly:

| Repo | Side | Offering |
|---|---|---|
| **`library`** | **dev** | The published `@plexus-ms/*` packages for the web / Node / TypeScript world: shared tool configs (biome, tsconfig), the `std` utilities, and — over time — the reusable application plumbing (framework glue, common auth concerns, repeatable non-domain features) that keeps each app's domain core small (§ 3). Detail: § 5, § 8. |
| **`itops`** | **ops** | The operations primitives: portable bash verbs, thin workflow wrappers that mount them on the forge, and the `plexus.itops` Ansible collection that provisions tenant hosts. Detail: § 7. |
| **`preset`** | **the seam** | The monorepo starter: a copier template that composes both sides into a ready tenant monorepo — `apps/` consuming the library, `infra/` binding the Ansible collection — and keeps generated repos re-syncable via `copier update`. Detail: § 8. |

The doctrine — this document, in the `compendium` repo — underpins all three and records the *why* behind every choice.

The border between the sides is blurry by design, and that is fine. CI is dev-side checks on an ops-side mount; `mise :test` is authored dev-side and invoked by the deploy pipeline; the app contract (§ 6) is the seam made explicit — the set of questions ops asks of dev. What matters is never which side a primitive lives on, but that it is tenant-neutral, versioned, and composable (§ 3).

Together the three repos form the **paved road**: a new project lands on the whole standard — toolchain, CI, deploy, backup — with near-zero overhead, and keeps receiving improvements afterwards (§ 8). What none of them contain is any tenant's *substance*: each tenant instantiates the standard into its own monorepo and its own platform (hosts, ingress, secrets, backups) — § 4.2 covers that second axis.

### § 4.2 Federation, not multi-tenancy

What spans the tenants is **separate trust domains sharing a *methodology*, not a *runtime*.** This is federation under a common standard — *one cookbook, many kitchens*. Identical methods and shared recipe updates; separate ingredients, separate staff, separate health inspections.

- **Shared across all tenants (the methodology):** the contract, the `@plexus-ms/*` config/lib packages, the reusable CI workflow, the deploy verb, the copier template, the Ansible *roles*, the doctrine. Knowledge, and code-shaped-as-knowledge. No tenant owns it.
- **Never shared (the substance):** hosts and root access, git org/repo access, secrets vaults, databases, backups, domains. These MUST remain partitioned by tenant.

**Tenants may share bare metal — with eyes open.** At small scale, pooling workloads on one physical host is the correct economics, and virtualization draws the boundary: tenants sharing a host MUST be separated one VM per tenant (never co-mingling tenants inside a VM), with everything else — Docker, ingress, secrets vault, backups, domains — kept per-VM as well. Be clear about what virtualization does and does not buy: it solves performance and fault isolation, but it *centralizes* access rather than partitioning it — the hypervisor has God-mode over every VM, so the host is tier-0 (no workloads on it, access locked down, its own VM-image backups; its compromise is everyone's) — and it does nothing for legal controllership: distinct legal persons sharing one box under one admin MUST document the arrangement in writing (a one-page boundary document plus a data-processing agreement, e.g. an AVV/DPA where the GDPR applies).

**Tenant identifier** — every tenant MUST have a short slug (e.g. `acme`, `initech`, and `plexus` itself, the project dogfooding its own standard) that threads through: forge org names, VM hostnames, Ansible inventory groups, vault names, and a `plexus.tenant=` label, which every deployed service MUST carry. That label makes the boundary visible exactly where fog otherwise creeps back in — staring at a host wondering whose service this is — and gives the monitoring view free grouping by tenant.

### § 4.3 Repo & namespace layout

- **The neutral namespace hosts the methodology.** `plexus-ms` is the tenant-neutral home of `library`, `preset`, and `itops` (what each offers: § 4.1), and of the `@plexus-ms` npm scope the library publishes under. It doubles as the org of the public dogfooding tenant (`plexus`).
- **Tag discipline for `itops`:** one version tag covers its three artifact classes (verbs, workflow wrappers, Ansible collection — § 7) atomically; tenants MUST reference `itops` artifacts by tag, never by branch. The repo has no CI of its own.
- **One forge org (or account) per tenant (MUST)** — org membership governs code access; a person in tenant A's org is simply not in tenant B's.
- **One monorepo per tenant (MUST)** — `<org>/<tenant>` (e.g. `plexus-ms/plexus`) holds **both** `apps/` (the tenant's applications — pnpm workspace + mise monorepo) **and** `infra/` (Ansible inventory, host/VM definitions, that tenant's deployment configs — the kitchen's layout). Apps and the platform that runs them version together; safe because a monorepo is one access boundary (§ 8). Generated from `plexus-ms/preset`.

## § 5 The dev side

How Plexus software is *built*: the pinned toolchain, the shared packages, and the release models. These are the dev side of § 4.1; their ops counterparts are the primitives of § 7, and the contract between the two sides is § 6.

### § 5.1 The JS/TS toolchain convention

Every Plexus JS/TS repo MUST use this toolchain, each choice made to pass the second-reader and degradation tests:

- **mise is the single toolchain authority *and* the verb runner.** Tool versions (node, pnpm, biome, even `npm:@changesets/cli`) MUST be pinned in `mise.toml` and *nowhere else* — a `package.json` MUST NOT carry `packageManager` or `engines`, because two pins for one fact is drift. Verbs are mise tasks, so "how do I run you?" is always `mise :<verb>` (monorepo path syntax: `:verb` for the current root, `//apps/<app>:verb` from anywhere, `//...:verb` to fan out; bare `mise <verb>` against a standalone `mise.toml`, as on a deploy host — never `mise run`). This is why Plexus uses mise, **not justfiles**: mise unifies tools + env + verbs in one artifact, and its task `include`s are version-pinned (`git::…?ref=vN`) — which `just import` cannot do — so shared verbs propagate via Renovate like any other dependency.
- **Monorepo = pnpm workspace + mise monorepo.** `pnpm-workspace.yaml` (`packages:` globs + a `catalog:` pinning shared dev-tool versions) owns install/linking; `monorepo_root = true` + `[monorepo] config_roots` in the root `mise.toml` gives two-altitude verbs — `mise //...:test` at the root fans out, `mise :test` inside a package runs only that one.
- **No root `package.json` unless a tool forces it.** A monorepo root MUST NOT carry a `package.json` except where a tool leaves no alternative; pnpm defines the workspace without one. The single current exception is changesets (its `@manypkg/find-root` needs a root manifest to anchor the monorepo), so the root carries a dependency-free, pin-free stub (`{ name, private }`).
- **Build with `tsc`, test with Node's built-in runner.** A published package compiles to `dist/` via `tsc` (transparent, no bundler) and tests via `node --test` on Node's native TS type-stripping (zero test dependencies). Both stay trivially hand-runnable.
- **Git hooks via `hk`, self-installing.** Pre-commit runs biome (format + lint on staged files); pre-push runs typecheck + test. `hk` is a mise tool and its config is `hk.pkl`; a `mise.toml` `[hooks] postinstall = "hk install --mise"` wires the git hooks on the first `mise install` — no `experimental` needed, no per-repo or per-machine step. The copier template ships `hk.pkl` + that hook, so every repo gets working hooks the moment its toolchain is installed (decide once → versioned artifact → propagate). `HK=0 git …` bypasses a hook when needed.

### § 5.2 Publishing the `@plexus-ms/*` packages

Cross-tenant sharing MUST use **published, versioned packages** (§ 8); the `@plexus-ms/*` packages go to **public npmjs** under the `@plexus-ms` scope, versioned by **changesets** (merge a "version packages" PR → CI publishes), with **npm provenance** — a signed attestation, generated in CI via OIDC, linking each published version to the exact source commit and workflow that built it. Going public (rather than a private registry) is consistent with `@plexus-ms/*` being tenant-neutral *methodology, not substance* — which makes one guardrail load-bearing: **tenant substance (business logic, secrets, anything tenant-specific) MUST NOT appear in a public `@plexus-ms/*` package.**

How the release runs:

- **Two phases.** Changesets accumulate on `main`; `changesets/action` opens a "version packages" PR that bumps versions + writes changelogs; merging it publishes. The only manual step is recording a changeset (`changeset` interactively) — versioning and publishing run in CI, never locally. PRs run `lint/typecheck/test/build` plus a `changeset status` guard that fails when a publishable change ships without a changeset.
- **Token-less via OIDC.** Publishing authenticates through GitHub OIDC *trusted publishing* (`id-token: write`), not a stored npm token — which also makes provenance automatic. *Bootstrap caveat:* a package can't be registered as a trusted publisher until it exists, so each package's **first** publish is a one-time manual `npm publish`; CI takes over after.
- **Tags + GitHub Releases are automatic** (`changeset publish` tags each `@plexus-ms/<pkg>@x.y.z`, the action pushes them and cuts a Release from the changelog). The release branch is protected by a ruleset requiring the CI checks.

### § 5.3 Branching & release model — different per repo type

The library and the apps version and release by completely different physics, so they use different branch models — each repo type MUST follow its column below. Conflating the two generates dead-end "extra work" in the design.

| | **Library** (`plexus-ms/library`) | **Tenant monorepo** (e.g. `plexus-ms/plexus`) |
|---|---|---|
| Output | published `@plexus-ms/*` packages | a deployed running service |
| "Version" | semver in the registry | the git SHA / image tag that's live |
| Release tool | **changesets** | **none** — the deploy verb (§ 7) |
| Branch model | **single `main`** (trunk-based) | **environment branches**: `main`→prod, `develop`→staging |
| Release trigger | merge the "version packages" PR → publish | merge to the env branch → build image → deploy |

**Why the library is trunk-based.** changesets accumulates changeset files on one branch, bumps them in one PR on that branch, and publishes from it. A second long-lived branch (GitFlow `develop`) forces reconciling version numbers between branches on every release — a perpetual back-merge tax. changesets is a trunk-based tool; pairing it with GitFlow fights it. Concurrency is *not* a reason to avoid this: changeset files have random names and the bump is deferred to one central step, so simultaneous feature branches never conflict and never double-publish — exactly what changesets is built for.

**Why apps use environment branches.** An app has no version number to reconcile — a release *is* a deploy keyed by git SHA — so the back-merge problem vanishes. Branches map to deploy targets (`develop`→staging, `main`→prod); "promote staging to prod" is merging `develop → main`. Apps therefore MUST NOT use changesets at all.

This is the § 8 dependency-mechanics rule applied to release flow: changesets lives only where something is *published across a tenant boundary* (the library). Within a tenant, packages are `workspace:*` deps and apps are deployed — neither needs it.


## § 6 The app contract

Small, verb-shaped, and identical for every stack. The contract is the § 4.1 seam made explicit — the set of *questions the platform (ops) asks of an app (dev)*; any stack that answers them is conformant. **PayloadCMS + MongoDB**, **Prisma + Postgres**, and a non-JS **Django + Postgres** app all satisfy it identically.

Every Plexus app repo MUST provide:

- **`mise.toml` with the standard verbs** — at minimum `mise :dev`, `mise :migrate` (MUST be idempotent), `mise :seed`, `mise :test`. "What was the migration command again?" stops being a memory question; the answer is always `mise :migrate`, and the mise task encodes the real incantation. Toolchain pinned in `mise.toml` (the single authority — never in `package.json`) so setup is `git clone && mise :dev` everywhere. See § 5.1.
- **`compose.yml`** declaring the app and its **app-owned** infrastructure (e.g. its own Postgres/Mongo container). Apps SHOULD default to one DB container each — full isolation, dies with the app. Data services MUST carry the labels `plexus.tenant=<id>` and `plexus.backup=<postgres|mongo|...>`.
- **An env schema file** — declares what env the app needs; secrets are injected at deploy time from the tenant's secrets vault and MUST NOT be committed.
- **A healthcheck** — `GET /healthz` returns 200 when ready.
- **A CI reference** — the app's CI MUST run the shared pipeline (§ 7: lint → typecheck → test → build → push image); on the reference stack this is a ~5-line reference to the shared reusable workflow.
- **A `PLEXUS.md`** — records the PLX version the repo targets (see *Versioning of this standard*). (The per-repo contract marker — deliberately distinct from this document, `PLX.md`, the standard itself.)

### The stateless-app profile

Some apps hold no state — static/marketing sites, stateless APIs. They still take the
contract; the state-specific MUSTs collapse to *documented no-ops* so the platform
treats every app identically:

- **`compose.yml`** declares only the app service with `plexus.tenant=<id>`; **no data
  service and no `plexus.backup` label** (nothing to back up).
- **`mise :migrate` MUST still be present** (as a documented no-op); `seed` MAY be omitted. The deploy verb still
  calls `mise migrate` uniformly — it never needs to know an app is stateless.
- **The env schema MAY declare zero secrets** (only runtime knobs like `PORT`).
- **`/healthz`, the CI reference, and `PLEXUS.md` remain MUSTs.**

A stateless app passes the degradation test trivially: the host is fully reconstructable
from git + the image registry, with no data to restore. *First instance:* `plexus-website`
(the `plexus` tenant — the project dogfooding its own standard).

What the contract deliberately does **not** mention: databases, ORMs, frameworks, or anything interior. The deploy verb only needs *"is there a migration step and how do I invoke it"* → `mise migrate`. The backup job only needs *"which services hold state and of what type"* → the labels. Adding Mongo support means writing one `mongodump` handler once in the platform, after which every Mongo app is covered.


## § 7 The ops side (all stateless, all second-reader-test-passable)

A CI/CD system needs **state** (what should exist), **events** (something changed), and **procedures** (make it so). Plexus puts state in git and in tools it doesn't author, takes events from systems someone else operates, and authors only stateless procedures. These are the ops side of § 4.1; their dev-side counterparts are the toolchain and packages of § 5.

Procedures are layered as shared logic cores with thin mounts (all in `plexus-ms/itops`, versioned by one tag), and the boundary is load-bearing:

- **Verbs** — portable bash scripts (`scripts/`) that contain *all* the logic and MUST stay hand-runnable: `git clone && ./scripts/deploy.sh deploy@host app image` works with no forge at all. This is what passes the degradation test.
- **Workflow wrappers** — thin reusable GitHub workflows (`.github/workflows/`) that merely mount a verb on the forge's events: checkout, secrets plumbing, one invocation. **Logic MUST NOT live in the YAML.** GitHub's workflow format is not an open standard — the runner is self-hostable but GitHub remains the scheduler — so the wrapper is forge-specific and disposable, while the verb is portable and permanent. Leaving GitHub would mean rewriting the mounts, never the verbs.
- **Ansible roles** (`ansible/` — the `plexus.itops` collection) — the same split applied to the platform layer: the roles are the shared logic core, and each tenant's `infra/` keeps only the binding — `site.yml` (a roles list), inventory, group_vars, `op.env`. A tenant playbook is to the roles what a workflow wrapper is to a verb: a mount, not logic. Tenants MUST pin the collection by tag in `requirements.yml`; every change under `ansible/` MUST bump `galaxy.yml` (SCM installs record that version — a moved tag alone won't reinstall).

### Forge
**GitHub** (reference stack — deliberately not self-hosted). Code and CI configs aren't personal data, and self-hosting the forge would make it a tier-0 dependency to secure and back up before it backs you up. GitHub is the event source for all git-triggered procedures and hosts the container registry (GHCR).

### The deploy verb — a verb, not a system
A stateless procedure (`plexus-ms/itops` `scripts/deploy.sh`), ~150 lines, referenced by version tag:

```
deploy(host, app, image_tag):
  ssh → docker compose pull
      → mise migrate            # idempotent migration hook
      → docker compose up -d
      → poll /healthz
      → on failure: re-up previous tag, alert
```

It reads everything from git (compose, env schema) and from the host (`docker ps` = runtime truth) and stores **nothing**. "Which version is live" is the running container's image tag, queryable from reality. Rollback needs no memory — the previous tag is in the registry and the git log.

**The fence (MUST NOT be crossed without a deliberate, documented decision):** no persistent state · no daemon · no UI · no reconciliation loop · no provisioning of platform resources at deploy time. Inside the fence, invest freely (logging, clean rollback, good error messages). Outside it, it's either an existing tool's job or an architecture change — not feature creep.

### CI
One reusable workflow in `plexus-ms/itops`: lint → typecheck → test → build → push image (tagged with git SHA). Each app references it in ~5 lines. Push → tests run. GitHub Actions is a control plane, but one *someone else operates* with git as input — that's allowed; a tenant MUST NOT operate its own.

### Push to main → deploy
Pure composition of the above: `push → CI (test, build, push image) → deploy verb (pull, migrate, up, healthcheck, rollback-on-fail)`. Continuous *behaviour* from a continuous *event source*, with nothing of yours running continuously.

### Backups
Platform concern, scheduled-event-driven. Ansible installs a nightly unit per VM: `pg_dump`/`mongodump` per labelled data service + restic to an off-site repository (e.g. a Hetzner Storage Box). Schedule + retention MUST live as code in the tenant monorepo's `infra/`. The backup job MUST discover what to dump by **reading the `plexus.backup` labels** — new app deployed → automatically backed up, zero bookkeeping. Failure alerts route through the monitoring stack.

### Scheduling & the orchestrator question
**No orchestrator in v1.** A workflow orchestrator (Kestra, Airflow, etc.) MUST NOT be stood up as platform infrastructure. The jobs an orchestrator would do are already covered:
- Deploys → the forge's CI.
- Backups → systemd timers (`Restart=on-failure`, journald logging).
- "Did a cron silently stop?" → a **dead-man's-switch**: every scheduled job MUST ping a check on success (reference stack: Healthchecks.io or self-hosted Uptime Kuma push monitors — wanted anyway). Missed ping → alert. The valuable 20% of an orchestrator at ~zero operating cost.
- App-internal pipelines (e.g. a fetch→dedupe→process flow) → a job queue **inside the app** (BullMQ / pg-boss), deployed as a worker container in the same compose file. Product logic stays out of platform-level infrastructure.

*Revisit an orchestrator only when:* workflows span multiple hosts with inter-step dependencies · human-in-the-loop approvals appear · scheduled-job interrelations become hard to track · backfill/replay ("re-run last Tuesday") matters. If reached, prefer a single vanilla shared instance (solve secrets via `op run` or equivalent, not a fork). Any pre-existing, semi-dormant orchestrator instance in a tenant is fog — schedule it for migration-or-retirement.

### Observability
The answer to "when is it time to scale?" is **data, not vibes** — and the usual gap is measurement, not orchestration. A small stack (Grafana + Prometheus/node-exporter + Loki, or lighter: Beszel + Uptime Kuma) plus phone alerting. This *also* provides the "what's running where" view (grouped by `plexus.tenant`), so no PaaS dashboard is needed for it. **You do not need Kubernetes** — single beefy hosts with Compose scale far past small-tenant needs; the bottleneck will be Postgres and operator time long before Compose, and self-hosted K8s would *worsen* the bus factor.


## § 8 Propagation with customizability — the rot-proofing

Separate the two things that propagate by completely different physics:

**Dependencies (versioned, pulled, auto-updated)** — anything that can live behind a stable interface:
- `@plexus-ms/biome-config`, `@plexus-ms/tsconfig` — extended in one line.
- The reusable CI workflow and the deploy verb — referenced by `@vN` tag.
- The `plexus.itops` Ansible collection — installed via each tenant's `requirements.yml` from the same `vN` tag.
- The shared **Renovate preset** (`plexus-ms/renovate-config`) — extended in one line from every repo's `renovate.json`, so the update policy itself propagates the same way.
- `@plexus-ms/std` and, over time, the rest of the dev-side plumbing (framework glue, common auth concerns, repeatable non-domain features — the § 3 edges) as shared TS packages.

These propagate automatically: fix once → bump version → **Renovate** opens a PR in every consumer repo. Consumers customize by **overriding at the edges** (their `biome.json` extends yours and adds local rules) — inheritance with a local override slot, so base updates never clobber local changes because they live in different files.

**Scaffolding (copied once, then owned)** — the irreducible repo shape. Three tiers, chosen per artifact:
1. **Convert to a dependency if at all possible.** Most "boilerplate" is secretly extractable — a `mise.toml` can `include` a shared, **version-pinned** task file (`git::…?ref=vN`), keeping only project-specific tasks local. This is the highest-value work; every bit extracted moves from the rotting pile to the auto-propagating pile (and unlike `just import`, the version pin lets Renovate carry the updates).
2. **Use a re-appliable scaffolder, not `cp`.** **copier**: a project records the template version it was generated from; `copier update` re-applies template changes as a diff, merging against local edits like a rebase, surfacing conflicts explicitly. Template-as-living-dependency.
3. **For the genuine remainder, make staleness visible:** the `PLEXUS.md` contract version + a Renovate-scheduled check flagging repos that have drifted behind the current standard. You won't auto-fix these, but you'll never again *not know* which repos are stale — which kills most of the fog by itself.

### The dependency-mechanics rule (monorepo vs publish)
A monorepo has **one** access boundary, so it **cannot span tenants** without dissolving the federation. Therefore:

> **Does the shared thing cross a tenant boundary? Yes → it MUST be a published, versioned package. No → workspace dependency.**

- **Within a tenant:** monorepo + pnpm workspaces. Instant edits, atomic cross-package commits, no publish overhead — and safe because it's one access boundary.
- **Across tenants (`@plexus-ms/*`):** published + versioned to **public npmjs** (`@plexus-ms` scope; see § 5.2). This is the *only* mechanism that crosses org boundaries, and it buys decoupled upgrade timing (app A pins `^2`, upgrades when *it* chooses) and Renovate propagation (Renovate needs a version to detect). The publish "overhead" is the thing buying the stability — and it collapses to near-nothing when automated: changesets opens a release PR on merge, CI publishes with provenance, Renovate auto-opens consumer PRs, CI-green patch/minor auto-merge. The human steps become "write the change, review the auto-PRs."
- *Bootstrap shortcut only:* static config (tsconfig/biome) MAY be pulled by git-dep/`degit` into the copier template on day one, replaced by proper publishing once stable — but this MUST NOT be done for the std.


## § 9 Deferred decisions & triggers to revisit

Written down so these are *decisions*, not drift:

- **Komodo (thin git-native deploy UI)** — trial after the foundation is stable, if a dashboard is wanted. Not before.
- **An orchestrator (e.g. vanilla Kestra)** — only on the § 7 triggers (multi-host dependent workflows, approvals, unmanageable schedule count, replay needs).
- **Kubernetes** — only on genuine multi-node scheduling / contractual HA-SLA / team-coordination needs. Not anticipated for years.
- **Moving a commercial tenant off the shared box** — the day a tenant has a customer with real data-processing expectations (anything in a regulated domain), revisit migrating that tenant's VMs to metal it controls itself. Not because the hypervisor stops isolating, but because "dedicated, tenant-only" can be a *commercial/trust* requirement independent of the technical reality. The one-VM-per-tenant rule already keeps this migration path clean.
- **Preview environments per PR** — deferred deliberately. A single `staging` per app covers ~90% of the value; revisit when a product has real customers.
- **Per-tenant second admins** — provision lazily, only when a real second operator exists.

