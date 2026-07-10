---
title: PLX — The Plexus.ms Standard
short_title: PLX
description: A comprehensive, opinionated, federated IT initiative. Standardized, boring, yours.
version: v0
timestamp: 2026-07-09
---

*A comprehensive, opinionated, federated IT initiative. Standardized, boring, yours.*

**Revision:** v0 — Draft, comments welcome.

## Abstract

Plexus.ms is a comprehensive, opinionated, federated IT initiative:
one tenant-neutral collection of guidelines, tools, and approaches, spanning software development ("dev") to operations ("ops").
On the dev side it ships published `@plexus-ms/*` packages and a pinned toolchain (`library`); 
on the ops side, stateless operational procedures ("verbs", § 2), thin CI wrappers, and Ansible roles (`itops`). 
A template composes both sides into tenant monorepos (`preset`), and a small, interface-shaped app contract (§ 6) defines where the two sides meet.
Each tenant instantiates the standard into its own platform: 
virtual instance(s), optionally on shared metal, with ingress, secrets, backups, and observability. 
Every primitive is as stateless as possible and passes the two litmus tests of § 3 — a second reader understands it whole; losing it leaves the job doable by hand. 
State lives in git, the registry, the hosts, and the backup repo — never in a dashboard and never in someone's head.
Improvements federate across all tenants via the supply chain; root, secrets, and data never do.
The result is customer-1001 economics (§ 2):
each new tenant and project lands on the standard with near-zero overhead, and the fog (§ 1) lifts.

This document, referred to as "PLX – The Plexus.ms Standard", "PLX", "Plexus Standard", or simply "the standard", is the initiative's foundation.
It intended for Plexus contributors, and anyone operating any Plexus-governed tenant.


## Preamble

*The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) when they appear in ALL CAPITALS. 
Everything else is informative rationale, description, or documentation.*

*This standard is versioned, and conformance to it is recorded per repo. 
§ 10 defines the versioning scheme, what conformance means, and the format of the per-repo `PLEXUS.md` marker.*

*Concrete tools and services are named in two different strengths, and the conformance keyword decides which.
A tool named **inside a MUST or SHOULD is normative** — part of the standard itself, and the reference-stack convention below never softens it: 
mise and hk are normative across all stacks (§ 5, § 6); pnpm and the rest of the § 5.1 toolchain are normative within JS/TS repos.
A tool or service named **without a keyword** belongs to the **reference stack**:
the concrete choice we, the maintainers, use in our own projects and built the `plexus-ms` repos for — chiefly the external services Plexus deliberately consumes rather than self-hosts (GitHub as forge, 1Password as vault, the hosting provider) and swappable platform components (e.g. Caddy).
A tenant MAY substitute an equivalent for any reference-stack choice, and owns the divergence.
The design intent behind the split is lock-in resistance:
proprietary services sit behind thin adapters over Plexus's own portable primitives — workflow wrappers are dumb mounts over hand-runnable verbs, `op.env` is plain dotenv pointers any vault CLI could resolve — so leaving a reference service means rewriting a mount, never a verb (§ 7).*


## § 1 Why Plexus exists

When one IT operator, or a small team, runs several projects for several organizations, the surface area grows organically, not by design. 
As it grows, the dominant felt experience becomes **mental fog**:
losing track of what is deployed where, how configuration interacts, how to set up a given environment, and where one was mentally when last touching a project. 
Every system is slightly bespoke, every deployment is a unique snowflake, the operator's head quietly becomes the database.
Projects stay half-baked, never brought live properly, never documented enough for handoff.

**Plexus.ms is the response.** 
It is neither a single product nor an opaque control plane. 
It is a collection of opinionated guidelines, tools, and approaches, with philosophies derived from this document.
They are intended to make doing the right thing the easy thing, so that each new project adds near-zero overhead.
Except where something *genuinely* demands bespoke config, projects should be boring and identical, and run on autopilot.
They should be made up of reusable, ideally stateless primitives that have clear interfaces and are simply composable.

### Two fundamental insights upfront

1. **Fog is a structure problem, not a discipline problem.**
  Fog is not fixed by promising to document more; documentation written *next to* a system drifts and rots.
  The fix is making the artifacts *be* the documentation, and make everything as well-structured as possible — **simple, easy, no magic.**
  If every project answers *"how do I run you?"* the same executable way, nothing needs to be remembered.

2. **Autopilot has a precise mechanism:** 
  **decide once, encode the decision in a primitive, and propagate it to every project automatically (§ 8).**
  Most efforts get the first two steps and skip the third — and the propagation step is the whole game; without it every encoded decision is just another artifact that rots in place.
  Composition follows from it: primitives with clear interfaces get composed instead of reinvented — **don't repeat yourself**.


## § 2 Terminology

The standard's private vocabulary, defined once:

- **Tenant** — one trust domain in the federation: its own forge org, monorepo, VM(s), secrets vault, backups.
Nominally a distinct legal person or organization, but the boundary that matters is *access*, not legal personality — `plexus` itself is a tenant (the initiative dogfooding its own methodology) without being one.
The mostly-1:1:1 chain of *legal entity : monorepo : operations platform* will be the usual rule, but is not part of the definition.
- **Primitive** — any named guideline, tool, or approach the initiative ships or prescribes: a verb, a mount, an Ansible role, a published package, the copier template, a label scheme, a file layout, an endpoint path.
Decided once, reused, versioned and published, or otherwise propagated.
- **Verb** — a stateless, hand-runnable procedure that does one operational thing (deploy, backup, migrate, ...), authored in a portable manner.
- **Mount** — the thin, disposable glue binding a verb or role to an event or state source it doesn't own: 
a workflow wrapper on forge events, a tenant playbook on an inventory, a systemd timer on the clock.
Mounts carry no logic.
- **Methodology** and **substance** — the federation's sharing axis (§ 4.2): *methodology* is knowledge and code-shaped-as-knowledge, shared across all tenants; *substance* is data, secrets, access, hosts, and is never shared.
- **Seam** — where the dev side and the ops side meet, made explicit as the app contract (§ 6).
- **The paved road** — the composed default path (toolchain, CI, deploy, backup) a new project lands on with near-zero overhead.
In pursuit of convenience and standardization, ties to the reference stack cannot be avoided on this road.
- **Reference stack** — the substitutable concrete choices (external services, swappable platform components) named without a conformance keyword; see preamble above. Keyword-bearing tool names are normative, not reference stack.
- **Customer-1001 economics** — the goal state in which the *marginal* tenant, project, or app costs near-zero to onboard and operate: everything it needs has already been decided once, encoded in a primitive, and propagated (§ 8), so the 1001st lands as cheaply as the 11th. The measurable form of the initiative's ambition.
- **Fog** — the operational memory loss described in § 1; the failure mode Plexus exists to eliminate.


## § 3 Core principles

These principles are PLX's load-bearing philosophy: the defaults every design starts from, not positions to re-debate per project.

In real designs they will pull against each other — statelessness against convenience, standardized boundaries against a genuinely bespoke need. 
When principles conflict, the resolution is a **documented trade-off**: decide, record the assumption or constraint that drove the decision where the next reader will meet it (in the primitive itself, or as an owned deviation in `PLEXUS.md` — § 10.2), and move on. 
A principle set aside with a written reason is the standard working as designed; a principle eroded silently is drift.

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
- **Have methodology cross tenant lines; never substance.** 
  Improvements in shared primitives federate to all tenants.
  Root, secrets, and data access stay siloed per tenant.
  The one honest exception — the shared supply chain — is named and mitigated in § 4.2.

### Litmus tests to stay honest over time

- **The second-reader test:** Can a competent second person read a Plexus primitive top to bottom in half an hour and understand every line? If not, it's most likely too opaque.
- **The degradation test:** If a primitive vanished tonight, could the job still be done by hand from the same artifacts in git? If yes, it's automation of a procedure that remains manually executable, and it will be less likely to cause trouble. If no, it is a magic automation that strands the operator in its absence.


## § 4 Architecture

### § 4.1 Two sides, one seam

Plexus is end-to-end: it standardizes both how software is *built* (development, dev) and how it is *run* (operations, ops).
There is no hierarchy between these concerns — they are two ends of one spectrum, and the tenant-neutral repositories map onto it directly:

| Repo | Offering |
|---|---|
| **`library`** – dev side, focused on web technologies | The published `@plexus-ms/*` packages for the web / Node / TypeScript world: shared tool configs (biome, tsconfig), the `std` utilities, and — over time — the reusable application plumbing (framework glue, common auth concerns, repeatable non-domain features) that keeps each app's domain core small (§ 3). For more, see § 5, § 8. |
| **`itops`** – ops side, focused on GitOps and IaC | The operations primitives: portable bash verbs, thin workflow wrappers that mount them on the forge, and the `plexus.itops` Ansible collection that provisions tenant hosts. For more, see § 7. |
| **`preset`** - uniting dev and ops sides with a web-focused starter | A copier template that composes both sides into a ready tenant monorepo — `apps/` consuming the library, `infra/` binding the Ansible collection — and keeps generated repos re-syncable via `copier update`. For more, see § 8. |

The border between the sides is blurry, and that is fine.
CI is dev-side checks on an ops-side mount; `mise :test` is authored dev-side and invoked by the deploy pipeline; the app contract (§ 6) is the seam made explicit — what ops asks of dev.
What matters is never which side a primitive lives on, but that it is tenant-neutral and composable (§ 3).

Together the three repos form the **paved road**: a new project lands on the whole **methodology** — toolchain, CI, deploy, backup — with near-zero overhead, and keeps receiving improvements afterwards (§ 8).
What none of them contain is any tenant's **substance**: each tenant instantiates the standard into its own monorepo and its own platform (hosts, ingress, secrets, backups) — § 4.2 covers that axis.

### § 4.2 Federation, not multi-tenancy

What spans the tenants is **separate trust domains sharing a *methodology*, not a *runtime*.** 
This is federation under a common standard — *one cookbook, many kitchens*. 
And to preempt what the word usually evokes: nothing federates at *runtime*. 
Tenants never talk to each other — no shared identity, no inter-instance protocol, no ActivityPub; what travels is versioned methodology from one upstream, hub-and-spoke. 
A federation of practice, not of instances.

- **Shared across all tenants (the methodology):** the contract, the `@plexus-ms/*` config/lib packages, the reusable CI workflow, the deploy verb, the copier template, the Ansible *roles*, the doctrine. Knowledge, and code-shaped-as-knowledge. No tenant owns it.
- **Never shared (the substance):** hosts and root access, git org/repo access, secrets vaults, databases, backups, domains. These MUST remain partitioned by tenant.

**One channel does cross tenant lines: the supply chain.** 
Whoever controls `plexus-ms` ships code that runs with root on every tenant's hosts (the Ansible roles), inside every tenant's CI (workflows and verbs), and inside every tenant's apps (the packages) — and § 8's Renovate flow keeps all three channels current, with how much of it runs unattended stratified by blast radius (auto-merge is a defensible default for packages, and deliberately not for code that re-runs with root — § 8). 
"Authority never crosses tenant lines" therefore has one honest exception: 
*the standard itself is a trust channel, and adopting it means trusting its maintainers.*
The mitigations are structural, not promises: 
The shared repos are public and every change is reviewable; auto-upgrading must be handled per tenant by risk appetite; npm packages carry provenance attestations. 
One sharp edge: Some approaches rely on Git tags, which are movable — unlike npm versions, a retargeted tag silently changes what every tenant executes, with no attestation. 
Referencing by commit SHA instead is an alternative; for now the trade-off of readability and Renovate flow over immutability is accepted as a deliberate decision.

**The standard itself has a bus factor — the degradation test, applied to the initiative.** 
Plexus removes the operator's head as the database of the *systems*, and in exchange concentrates a new single point: today, one maintainer controls the doctrine, the packages, the template, and the supply chain above. 
The honest question is not "will the maintainer stay responsive" but "what happens to a tenant the day `plexus-ms` goes unmaintained" — so that answer is written down here, not discovered under pressure:

- **Nothing breaks on day one.** Every consumption path is pinned and pull-based: published npm versions are immutable, `itops` tags keep resolving, and each generated repo records its template version. No Plexus service runs anywhere; there is nothing to go down.
- **Everything is forkable — legally, not just technically.** The shared repos are public, and every `plexus-ms` repo MUST carry a permissive OSI-approved license (reference: MIT). A tenant that must move forward alone forks, retags, and re-points its pins — same verbs, same mounts, new upstream.
- **The real cost is slow drift, not sudden failure:** upstream tools keep moving, security patches stop arriving, and the § 8 staleness visibility starts flagging repos behind a standard that no longer advances. Fog returning on a timescale of months, not an outage — an acceptable degradation mode, and the reason unmaintained-upstream is a *migration trigger*, not an emergency.

Two adoption prerequisites follow from taking that question seriously. 
**Governance:** the initiative is single-maintainer today, and this document says so plainly rather than performing a committee; growing past that is a named deferred decision (§ 9). 
**Disclosure:** every `plexus-ms` repo MUST provide a private vulnerability-reporting channel (reference: GitHub private vulnerability reporting, declared in a `SECURITY.md`), and fixes ship as ordinary versions so the § 8 flow propagates them like any other change.

**Tenants may share bare metal — with eyes open.** 
At small scale, pooling workloads on one physical host is the correct economics, and virtualization draws the boundary: 
tenants sharing a host MUST be separated by virtualization technologies (never co-mingling tenants inside one single VM). 
Everything else — Docker, ingress, secrets vault, backups, domains — SHOULD be kept per-VM as well.
Feeling the need to deviate from this and sharing ingress, networking, secrets, might be acceptable under certain conditions but must also be interpreted as a sign of a deeper structural problem, of the standard falling short of its own economics goals.
Also, be clear about what virtualization does and does not buy:
it solves performance and fault isolation, but it *centralizes* access rather than partitioning it — a hypervisor has God-mode over every VM, so the host is a critical attack vector — and it does nothing for legal controllership: 
distinct legal persons sharing one box under one admin MUST document the arrangement in writing — e.g. a one-page document defining the relationship, plus a data-processing agreement where applicable. 
*Why (informative, and not legal advice):* data-protection regimes commonly require such arrangements to exist in writing — under the GDPR, typically an AVV/DPA. The standard can require the artifact; whether the artifact satisfies a given jurisdiction is a legal question each tenant answers for itself — PLX conformance is not legal compliance.

**Tenant identifier** — every tenant MUST have a short slug (e.g. `acme`, `initech`, and `plexus` itself, the project dogfooding its own standard) that threads through as consistently as possible: forge org names, VM hostnames, Ansible inventory groups, vault names, and a `plexus.tenant=` label, which every deployed service MUST carry. 
That label makes the boundary visible exactly where fog otherwise creeps back in (staring at a host wondering whose service this is).

### § 4.3 Repo & namespace layout

- **The neutral namespace hosts the methodology.** `plexus-ms` is the tenant-neutral home of `library`, `preset`, and `itops` (see § 4.1 for details), and of the `@plexus-ms` npm scope the library publishes under.
It doubles as the org of the public dogfooding tenant (`plexus`).
- **Tag discipline for `itops`:** one version tag covers its three artifact classes (verbs, workflow wrappers, Ansible collection — § 7) atomically;
tenants MUST reference `itops` artifacts by tag, never by branch.
(Tags are git's *movable* pointer — this mandate deliberately accepts the supply-chain sharp edge named in § 4.2, where the tag-over-SHA trade-off is owned.)
- **One forge org (or account) per tenant (MUST)** — org membership governs code access; a person in tenant A's org is simply not in tenant B's.
- **One monorepo per tenant (SHOULD)** — Because this standard is somewhat web-focused, the monorepo pattern has several benefits: `<org>/<tenant>` (e.g. `plexus-ms/plexus`) can hold **both** dev side (most likely a mise monorepo with pnpm workspace, maybe with advanced monorepo tooling like Turborepo in the future) and ops side (Ansible inventory, host/VM definitions, that tenant's deployment configs). Apps and the platform that runs them version together; 
safe because a monorepo is one access boundary (§ 8).
Tenant monorepos SHOULD be generated from `plexus-ms/preset`.
With several apps in one repo, deploys are per-app and promotion is repo-wide (the release train — § 5.4); a product that persistently needs its own release cadence is the one reason to give it its own repo within the tenant's org.

## § 5 The dev side

How Plexus software is *built*: the pinned toolchain, the shared packages, and the release models. These are the dev side of § 4.1; their ops counterparts are the primitives of § 7, and the contract between the two sides is § 6.

Scope, honestly: v0 standardizes the toolchain, the publishing mechanics, and the release models. The reusable application plumbing the § 3 boundary principle aims at — framework glue, common auth concerns, repeatable non-domain features — is future work, deferred with its trigger in § 9; until it exists, that plumbing lives in the app that needs it.

Nor is Plexus secretly JS-only: mise and hk are language-neutral, so they bind every Plexus repo regardless of stack — the standard verbs (§ 6) are the stack-neutral layer every app answers, and the hook discipline of § 5.1 applies with stack-appropriate checks behind the same hooks. Only § 5.1's pnpm/tsc specifics bind JS/TS repos alone. A Python or Go app takes the same contract with different incantations behind the same verbs — JS/TS is simply the first toolchain the standard has decided.

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

**Package-design rules.** A `@plexus-ms/*` package MUST be tenant-neutral methodology (the guardrail above). Code utilities SHOULD start in `std` — the standard library is the default home for any small shared concern — and a concern graduates to its own package once it has its own audience or its own release cadence (a consumer shouldn't take updates because an unrelated helper changed). Tool configs (`biome-config`, `tsconfig`) are separate packages by construction: they exist to be one-line `extends` targets. **API stability:** packages follow semver, enforced by changesets — a breaking change MUST be a major bump, and its changeset SHOULD carry a migration note so the changelog doubles as the upgrade guide.

### § 5.3 Branching & release model — different per repo type

The library and the apps version and release by completely different physics, so they use different branch models — each repo type MUST follow its column below. Conflating the two generates dead-end "extra work" in the design.

| | **Library** (`plexus-ms/library`) | **Tenant monorepo** (e.g. `plexus-ms/plexus`) |
|---|---|---|
| Output | published `@plexus-ms/*` packages | a deployed running service |
| "Version" | semver in the registry | the git SHA / image tag that's live |
| Release tool | **changesets** | **none** — the deploy verb (§ 7.2) |
| Branch model | **single `main`** (trunk-based) | **environment branches**: `main`→prod, `develop`→staging |
| Release trigger | merge the "version packages" PR → publish | merge to the env branch → build image → deploy (per changed app — § 5.4) |

**Why the library is trunk-based.** changesets accumulates changeset files on one branch, bumps them in one PR on that branch, and publishes from it. A second long-lived branch (GitFlow `develop`) forces reconciling version numbers between branches on every release — a perpetual back-merge tax. changesets is a trunk-based tool; pairing it with GitFlow fights it. Concurrency is *not* a reason to avoid this: changeset files have random names and the bump is deferred to one central step, so simultaneous feature branches never conflict and never double-publish — exactly what changesets is built for.

**Why apps use environment branches.** An app has no version number to reconcile — a release *is* a deploy keyed by git SHA — so the back-merge problem vanishes. Branches map to deploy targets (`develop`→staging, `main`→prod); "promote staging to prod" is merging `develop → main`. Apps therefore MUST NOT use changesets at all.

This is the § 8 dependency-mechanics rule applied to release flow: changesets lives only where something is *published across a tenant boundary* (the library). Within a tenant, packages are `workspace:*` deps and apps are deployed — neither needs it.

### § 5.4 Deploy granularity in a multi-app monorepo

A tenant monorepo holds N apps plus `infra/`, so "merge to `main` deploys" needs a precise subject. The model is a **release train**: promotion is repo-wide, deployment is per-app.

- **The unit of deployment is the app; the unit of promotion is the repo.** A merge to an environment branch releases into that environment *exactly the apps whose sources changed in the merge*. CI MUST be path-scoped per app — an app's own directory plus every workspace package it depends on — so a docs-only merge deploys nothing, a `packages/ui` change redeploys its dependents, and unchanged apps are neither rebuilt nor redeployed. The deploy verb needs no change for this: it was per-app all along (`deploy(host, app, image_tag)`); CI simply fans it out over the changed set, and the changed set is derived from the merge diff — stateless, no bookkeeping.
- **Promotion is the whole train.** "Promote staging to prod" remains one merge, `develop → main`, and that merge asserts *everything on `develop` is prod-ready*. The discipline this buys its simplicity with: **`develop` MUST stay promotable** — unfinished or still-soaking work lives on feature branches, never parked on `develop`. Selective promotion (cherry-picks, path-restricted merges) MUST NOT be used: it would put on prod a repo state that never existed on staging, destroying the one guarantee environment branches exist to give.
- **Hotfixes skip the train without derailing it:** branch from `main`, merge to `main` (path-scoping deploys only the fixed app), then back-merge `main → develop` immediately (MUST) so the branches keep converging.
- **`infra/` rides no train.** It is not an app and the deploy verb never touches it; applying it is a playbook run (§ 7), its own mount, on its own occasions.
- **The escape valve is a repo split, not a process patch.** If two products in one tenant *persistently* need independent release cadences — one must ship while the other soaks, again and again — that is the § 4.3 monorepo SHOULD yielding, not the train rule: move the product into its own repo (still inside the tenant's org and access boundary, still on the same contract). Granularity problems are solved by moving a product off the train, never by making promotion partial.


## § 6 The app contract

Small, verb-shaped, and identical for every stack. The contract is the § 4.1 seam made explicit — the set of *questions the platform (ops) asks of an app (dev)*; any stack that answers them is conformant. **PayloadCMS + MongoDB**, **Prisma + Postgres**, and a non-JS **Django + Postgres** app all satisfy it identically.

Every Plexus app repo MUST provide:

- **`mise.toml` with the standard verbs** — at minimum `mise :dev`, `mise :migrate` (idempotent and roll-forward-only — § 6.1), `mise :seed`, `mise :test`. `seed` loads development sample data only: it MAY assume a fresh database (right after `migrate`) and MUST NOT be invoked by the deploy verb — production data arrives by restore or by real use, never by seed. "What was the migration command again?" stops being a memory question; the answer is always `mise :migrate`, and the mise task encodes the real incantation. Toolchain pinning follows § 5.1 — that rule is stated once there, and only referenced here — so setup is `git clone && mise :dev` everywhere.
- **`compose.yml`** declaring the app and its **app-owned** infrastructure (e.g. its own Postgres/Mongo container). Apps SHOULD default to one DB container each — full isolation, dies with the app. Data services MUST carry the labels `plexus.tenant=<id>` and `plexus.backup=<postgres|mongo|...>`.
- **An env schema file (`env.schema`)** — a file at the app root declaring every variable the app reads. The base format is not invented: it is plain dotenv, the same syntax `docker compose --env-file` and every language's dotenv library already parse. The only Plexus addition is a two-word flag vocabulary, and because § 7 builds machinery on it, the grammar is specified exactly:
  1. One variable per line, `KEY=value` dotenv syntax; every variable the app reads MUST be listed.
  2. The value position holds the default; an empty value means "no default".
  3. Flags are a trailing comment **on the same line as the key** (never the line above): `# required`, `# secret`, combinable as `# required secret`.
  4. An unflagged key is optional and non-secret. A `secret` key MUST have an empty value position — a default secret in git is a leak, not a default.
  5. Full-line comments are prose for humans; parsers MUST ignore them.

  Stack-neutral, greppable (`grep secret env.schema`), and checkable — the platform diffs the schema against the env it provides. To keep the micro-format from ever forking, `itops` ships the **one canonical parser** (a verb like any other), and every consumer — the CI schema check, the provisioning role that resolves `secret` keys against `apps[].secrets` (§ 7.6) — MUST parse through it; two parsers that could disagree simply don't exist. Secret *values* are resolved from the tenant's vault at provisioning time (§ 7.6, never at deploy time) and MUST NOT be committed.
- **A single HTTP port** — the app serves plain HTTP on one container port, published to loopback only. The *host* side of that binding is not the app's to choose: the host port is assigned by the platform from the tenant's inventory (§ 7.5) and injected at deploy time, so the app's `compose.yml` publishes via interpolation — `127.0.0.1:${PLEXUS_APP_PORT}:<container-port>` — and MUST NOT hardcode a host port. TLS, hostnames, and the domain→port binding are likewise the platform's job (§ 7.5); domain and host port alike are deployment substance, so the app stays deployable under any hostname and next to any neighbour.
- **A healthcheck** — `GET /healthz`, with **readiness semantics**, pinned normatively because the deploy verb's rollback decision rides on this endpoint (§ 7.2): it MUST return 200 if and only if the process can serve real requests *right now* — which includes probing hard dependencies the app cannot serve without (its own database, with a short bounded timeout) and MUST NOT include soft or third-party dependencies the app survives degraded. The endpoint MUST be cheap, side-effect-free, and unauthenticated (it is reachable only via loopback anyway). Plexus deliberately does **not** split liveness from readiness: that distinction pays for itself only where a reconciler restarts processes on liveness, and the standard has no reconciler (§ 7.2, the fence) — one endpoint, one meaning. Transient dependency blips are the *poller's* problem, and handled there (§ 7.2).
- **Logs on stdout/stderr** — the app MUST write logs to stdout/stderr and MUST NOT manage its own log files; shipping and retention are the platform's job.
- **A CI reference** — the app's CI MUST run the shared pipeline (§ 7.3: lint → typecheck → test → build → push image); on the reference stack this is a ~5-line reference to the shared reusable workflow.
- **A `PLEXUS.md`** — the per-repo conformance marker: the PLX version targeted, the profile taken, and any owned deviations. Format and semantics: § 10.

### § 6.1 Migration discipline

`migrate` is the one contract verb the deploy pipeline invokes against production data, so its semantics are pinned precisely rather than left to the word "idempotent":

- **Idempotent, spelled out:** `migrate` MUST be safe to invoke at any time — already-applied steps are skipped, and running it against a fully-migrated schema is a no-op. A failure partway through MUST leave the schema in a state from which re-running `migrate` can complete (each step applied atomically where the database supports it). Concurrent invocations MUST NOT corrupt the schema; `migrate` SHOULD serialize itself via a lock — mainstream migration tools do this out of the box, so the requirement is usually just *don't disable it*.
- **Roll forward, never back.** The deploy flow has no down-migration step, and its rollback path (§ 7.2) re-launches the *previous* image against the *already-migrated* schema. Every migration MUST therefore be backward-compatible with the release currently in production — expand/contract discipline: additive changes (new tables, nullable columns, backfills) ship first, and destructive ones (drops, renames, constraint tightening) ship only in a later release, once no deployed code depends on the old shape.
- **The escape hatch is deliberate, not silent.** A genuinely breaking migration — one that cannot honor expand/contract — forfeits automatic rollback. It MUST be deployed as a deliberate act: fresh backup taken first, and the operator aware that reverting means *restoring*, not re-upping the previous tag.

### § 6.2 The stateless-app profile

Some apps hold no state — static/marketing sites, stateless APIs. They still take the
contract; the state-specific MUSTs collapse to *documented no-ops* so the platform
treats every app identically:

- **`compose.yml`** declares only the app service with `plexus.tenant=<id>`; **no data
  service and no `plexus.backup` label** (nothing to back up).
- **`mise :migrate` MUST still be present** (as a documented no-op); `seed` MAY be omitted. The deploy verb still
  calls `mise migrate` uniformly (bare form, deliberately — deploy-host context, § 5.1) — it never needs to know an app is stateless.
- **The env schema MAY declare zero secrets** (only runtime knobs like `PORT`).
- **`/healthz`, the CI reference, and `PLEXUS.md` remain MUSTs.**

A stateless app passes the degradation test trivially: the host is fully reconstructable
from git + the image registry, with no data to restore.

What the contract deliberately does **not** mention: databases, ORMs, frameworks, or anything interior. The deploy verb only needs *"is there a migration step and how do I invoke it"* → `mise migrate` (bare form: on the deploy host, the verb runs against the app's standalone `mise.toml`, where path syntax does not apply — § 5.1). The backup job only needs *"which services hold state and of what type"* → the labels. Adding Mongo support means writing one `mongodump` handler once in the platform, after which every Mongo app is covered.


## § 7 The ops side (all stateless, all second-reader-test-passable)

A CI/CD system needs **state** (what should exist), **events** (something changed), and **procedures** (make it so). Plexus puts state in git and in tools it doesn't author, takes events from systems someone else operates, and authors only stateless procedures. These are the ops side of § 4.1; their dev-side counterparts are the toolchain and packages of § 5.

A new or reworked primitive MUST pass both litmus tests (§ 3) before it is declared done — second-reader and degradation are the definition of done here, not aspirations.

Procedures are layered as shared logic cores with thin mounts (all in `plexus-ms/itops`, versioned by one tag), and the boundary is load-bearing:

- **Verbs** — portable bash scripts (`scripts/`) that contain *all* the logic and MUST stay hand-runnable: `git clone && ./scripts/deploy.sh deploy@host app image` works with no forge at all. This is what passes the degradation test. Bash's native failure modes (unset variables expanding to nothing, pipelines failing silently) are second-reader traps, so a safety baseline is normative: every verb MUST run under strict mode (`set -euo pipefail` or equivalent) and MUST be shellcheck-clean, enforced mechanically at the repo boundary (hook or check — never the honor system).
- **Workflow wrappers** — thin reusable GitHub workflows (`.github/workflows/`) that merely mount a verb on the forge's events: checkout, secrets plumbing, one invocation. **Logic MUST NOT live in the YAML.** GitHub's workflow format is not an open standard — the runner is self-hostable but GitHub remains the scheduler — so the wrapper is forge-specific and disposable, while the verb is portable and permanent. Leaving GitHub would mean rewriting the mounts, never the verbs.
- **Ansible roles** (`ansible/` — the `plexus.itops` collection) — the same split applied to the platform layer: the roles are the shared logic core, and each tenant's `infra/` keeps only the binding — `site.yml` (a roles list), inventory, group_vars, `op.env`. A tenant playbook is to the roles what a workflow wrapper is to a verb: a mount, not logic. Tenants MUST pin the collection by tag in `requirements.yml`; every change under `ansible/` MUST bump `galaxy.yml` (SCM installs record that version — a moved tag alone won't reinstall).

### § 7.1 Forge
**GitHub** (reference stack — deliberately not self-hosted). Code and CI configs aren't personal data, and self-hosting the forge would make it a tier-0 dependency *you* must secure and back up before it backs you up. Be honest about what that decision buys, though: **the forge is tier-0 for deploys either way** — CI is the deploy trigger and GHCR holds the images, so a GitHub outage means no automated deploys, and rolling back during one leans on the previous image still sitting in the host's local cache (or on git plus a local build). That trade is accepted, and named here rather than implied away: not-self-hosting avoids *operating* tier-0, not *depending* on it. What bounds the damage is the usual pair — running systems keep running and git is distributed, so an outage costs deploy availability, never data; and the verbs stay hand-runnable (degradation test), so a forge-less deploy remains possible, just not convenient. GitHub is the event source for all git-triggered procedures and hosts the container registry (GHCR).

### § 7.2 The deploy verb — a verb, not a system
A stateless procedure (`plexus-ms/itops` `scripts/deploy.sh`), ~150 lines, referenced by version tag:

```
deploy(host, app, image_tag):
  ssh → docker compose pull
      → mise migrate            # bare form: standalone mise.toml on the host (§ 5.1);
                                # idempotent, roll-forward-only (§ 6.1)
      → docker compose up -d
      → poll /healthz
      → on failure: re-up previous tag, alert
```

It reads everything from git (compose, env schema) and from the host (`docker ps` = runtime truth) and stores **nothing**. "Which version is live" is the running container's image tag, queryable from reality. Rollback needs no memory — the previous tag is in the registry and the git log.

**The healthcheck poll is deadline-based, not one-shot:** the verb retries `/healthz` until it answers 200 or a deadline expires (reference: ~60 s). A transient blip inside the window is absorbed; only *sustained* not-ready fails the deploy. Because `/healthz` carries readiness semantics including hard dependencies (§ 6), a down database fails the deploy — correctly, since the new code cannot serve — and the ensuing rollback is harmless by idempotence: the old tag can't serve either, its poll fails too, and the alert fires. The verb never needs to diagnose *why* readiness failed; it only ever acts on *whether*.

**Rollback's honest limit:** it re-ups the previous image; it never reverses a migration — by the time the healthcheck fails, `migrate` has already run, and the old code comes back up against the new schema. That is sound only because the contract makes it sound: § 6.1 requires every migration to be backward-compatible with the release currently in production. For the rare deploy that deliberately breaks that discipline, reverting is a *restore from backup*, not a re-up — the verb cannot and does not pretend otherwise.

**The fence (MUST NOT be crossed without a deliberate, documented decision):** no persistent state · no daemon · no UI · no reconciliation loop · no provisioning of platform resources at deploy time. Inside the fence, invest freely (logging, clean rollback, good error messages). Outside it, it's either an existing tool's job or an architecture change — not feature creep.

### § 7.3 CI
One reusable workflow in `plexus-ms/itops`: lint → typecheck → test → build → push image (tagged with git SHA). Each app references it in ~5 lines; in a multi-app monorepo each app's mount is path-scoped to that app and its workspace dependencies, so a push builds and deploys only what changed (§ 5.4). Push → tests run. GitHub Actions is a control plane, but one *someone else operates* with git as input — that's allowed; a tenant MUST NOT operate its own.

### § 7.4 Push to main → deploy
Pure composition of the above: `push → CI (test, build, push image) → deploy verb (pull, migrate, up, healthcheck, rollback-on-fail)`. Continuous *behaviour* from a continuous *event source*, with nothing of yours running continuously.

### § 7.5 Ingress
Platform concern. A reverse proxy per VM (reference stack: Caddy) terminates TLS and maps domains to app ports. **The host port belongs to the platform, not the app:** each app's host port is assigned in the tenant's inventory (`apps[].port`), in the same record that binds its domain — domain→port→app is one line in `infra/`, so per-VM port uniqueness is checkable in a single file (the playbook SHOULD fail on a duplicate) instead of being coordination state scattered across app repos. From that one record, provisioning renders the ingress config *and* injects the port into the app's compose interpolation (§ 6): it writes the value to `<app_dir>/platform.env` on the host, and the deploy verb hands that file to compose alongside its own `.env` — the verb itself stays port-unaware. A domain, like a host port, is deployment substance, never the app's concern. The contract's side of the seam stays deliberately small: one loopback-published HTTP port (§ 6).

### § 7.6 Secrets
Platform concern, and strictly tenant substance. The tenant's vault (reference stack: 1Password) is the only place secret *values* live; git holds only *references*. Two flows, both resolved at provisioning time, never at deploy time:

- **Platform secrets** (deploy SSH key, registry credentials): the tenant's `infra/op.env` is a committed dotenv file of `op://` pointers — it holds no values, so it is safe in git — and the playbook runs as `op run --env-file=op.env -- ansible-playbook site.yml`, which resolves the pointers into env vars the playbook reads.
- **App runtime secrets:** each key marked `# secret` in an app's `env.schema` (§ 6) is declared in the tenant's inventory (`apps[].secrets`), resolved from the vault when the playbook runs, and written to `<app_dir>/secrets.env` on the host — owned by the deploy user, mode `0600`, never world-readable; the app's compose file loads it via `env_file`.

The deploy verb never touches secrets: provisioning owns `secrets.env` (secret values) and `platform.env` (non-secret platform bindings such as the host port — § 7.5), the deploy verb owns `.env` (the image ref), and no two writers share a file.

**Rotation is complete only when the running process holds the new value.** Environment is injected at container *creation* — rewriting `secrets.env` on its own rotates a file, not a credential. The full loop is therefore: change the vault item → re-run the playbook (rewrites `secrets.env`) → **re-create the affected containers**. The playbook MUST close that loop itself: the role that writes `secrets.env` notifies a handler that runs `docker compose up -d` for the app whenever the file changed, and compose re-creates exactly the services whose environment differs. So "re-run the playbook" genuinely rotates — but only because the handler exists; rotation MUST NOT be left to ride along on whenever the next deploy happens to run. This is also the one documented interaction between secrets and the deploy verb: a redeploy re-creates containers and thereby picks up the *current* `secrets.env` as a side effect, yet the verb itself still never reads, writes, or resolves a secret — staying secret-unaware is part of what keeps it a verb, not a system.

### § 7.7 Backups
Platform concern, scheduled-event-driven. Ansible installs a nightly unit per VM: `pg_dump`/`mongodump` per labelled data service + restic to an off-site repository (e.g. a Hetzner Storage Box). Schedule + retention MUST live as code in the tenant monorepo's `infra/`. The backup job MUST discover what to dump by **reading the `plexus.backup` labels** — new app deployed → automatically backed up, zero bookkeeping. Failure surfaces via the dead-man's-switch (§ 7.8): a failed nightly unit never pings, and the missed ping alerts.

**Untested backups are not backups — and that rule is encoded, not aspirational.** Left as prose, "verify your backups" is exactly the failure § 1 insight 2 warns about: a decision made but never encoded into a primitive and never propagated. So it is encoded, in three parts:

- **The `restore` verb** (`plexus-ms/itops` `scripts/restore.sh`) is backup's stateless counterpart, and the reason the backup path passes the degradation test at all: given a restic repository, a snapshot, and a target service, it restores hand-runnably with no platform present (`git clone && ./scripts/restore.sh …`). A backup without a hand-runnable restore is write-only storage.
- **The restore test is a scheduled job like any other:** Ansible installs a periodic unit (SHOULD run at least monthly) that restores the latest snapshot of each labelled data service into a scratch container and runs a sanity check — the dump loads, a trivial query answers — then pings **its own dead-man's-switch check**, separate from the backup job's. A restore test that silently stops running alerts exactly like a backup that silently stops running.
- **First-use gate:** a new backup path MUST pass one end-to-end restore before it is relied upon — that first run of the restore test *is* the verification — and MUST be re-verified after any material change to the path; the scheduled test carries re-verification from then on.

### § 7.8 Scheduling & the orchestrator question
**No orchestrator in v1.** A workflow orchestrator (Kestra, Airflow, etc.) MUST NOT be stood up as platform infrastructure. The jobs an orchestrator would do are already covered:
- Deploys → the forge's CI.
- Backups → systemd timers (`Restart=on-failure`, journald logging).
- "Did a cron silently stop?" → a **dead-man's-switch**: every scheduled job MUST ping a check on success — some sort of dead-man's-switch / smoke-test monitor, self-hosted or managed (a concrete reference-stack choice is deferred, § 9). Missed ping → alert. The valuable 20% of an orchestrator at ~zero operating cost.
- App-internal pipelines (e.g. a fetch→dedupe→process flow) → a job queue **inside the app** (BullMQ / pg-boss), deployed as a worker container in the same compose file. Product logic stays out of platform-level infrastructure.

*Revisit an orchestrator only when:* workflows span multiple hosts with inter-step dependencies · human-in-the-loop approvals appear · scheduled-job interrelations become hard to track · backfill/replay ("re-run last Tuesday") matters. If reached, prefer a single vanilla shared instance (solve secrets via `op run` or equivalent, not a fork). An orchestrator that exists but barely runs anything is fog by this document's own definition; a tenant that finds itself with one SHOULD migrate its jobs onto the mechanisms above or retire it.

## § 8 Propagation with customizability — the rot-proofing

Separate the two things that propagate by completely different physics:

**Dependencies (versioned, pulled, auto-updated)** — anything that can live behind a stable interface:
- `@plexus-ms/biome-config`, `@plexus-ms/tsconfig` — extended in one line.
- The reusable CI workflow and the deploy verb — referenced by `@vN` tag.
- The `plexus.itops` Ansible collection — installed via each tenant's `requirements.yml` from the same `vN` tag.
- The shared **Renovate preset** (`plexus-ms/renovate-config`) — extended in one line from every repo's `renovate.json`, so the update policy itself propagates the same way.
- `@plexus-ms/std` and, over time, the rest of the dev-side plumbing (framework glue, common auth concerns, repeatable non-domain features — the § 3 edges) as shared TS packages.

These propagate automatically: fix once → bump version → **Renovate** opens a PR in every consumer repo.

**How unattended the merge is, is stratified by blast radius — one policy does not fit three risk classes:**

- **`@plexus-ms/*` packages** — run inside an app, versions immutable and provenance-attested: CI-green patch/minor auto-merge MAY be enabled and is the paved-road default.
- **CI workflow and verb tag bumps** — run in tenant CI, next to its secrets, and reference a movable tag (§ 4.2): auto-merge MAY be enabled, but a tenant whose CI holds sensitive credentials SHOULD review these PRs instead.
- **The `plexus.itops` Ansible collection** — runs with root on tenant hosts: Renovate opens the PR, but it SHOULD NOT be auto-merged; a human reads the diff before anything new runs as root.

The paved-road default is therefore deliberately *not* trust-maximal: unattended propagation is granted per risk class, each tenant's Renovate config records the stratification it chose, and per § 4.2 the risk appetite behind that choice is the tenant's own.

Consumers customize by **overriding at the edges** (their `biome.json` extends yours and adds local rules) — inheritance with a local override slot, so base updates never clobber local changes because they live in different files.

**Scaffolding (copied once, then owned)** — the irreducible repo shape. Three tiers, chosen per artifact:
1. **Convert to a dependency if at all possible.** Most "boilerplate" is secretly extractable — a `mise.toml` can `include` a shared, **version-pinned** task file (`git::…?ref=vN`), keeping only project-specific tasks local. This is the highest-value work; every bit extracted moves from the rotting pile to the auto-propagating pile (and unlike `just import`, the version pin lets Renovate carry the updates).
2. **Use a re-appliable scaffolder, not `cp`.** **copier**: a project records the template version it was generated from; `copier update` re-applies template changes as a diff, merging against local edits like a rebase, surfacing conflicts explicitly. Template-as-living-dependency.
3. **For the genuine remainder, make staleness visible:** the `PLEXUS.md` conformance marker (its § 10.3 frontmatter is what makes this mechanically checkable) + a Renovate-scheduled check flagging repos that have drifted behind the current standard. You won't auto-fix these, but you'll never again *not know* which repos are stale — which kills most of the fog by itself.

### The dependency-mechanics rule (monorepo vs publish)
A monorepo has **one** access boundary, so it **cannot span tenants** without dissolving the federation. Therefore:

> **Does the shared thing cross a tenant boundary? Yes → it MUST be a published, versioned package. No → workspace dependency.**

- **Within a tenant:** monorepo + pnpm workspaces. Instant edits, atomic cross-package commits, no publish overhead — and safe because it's one access boundary.
- **Across tenants (`@plexus-ms/*`):** published + versioned to **public npmjs** (`@plexus-ms` scope; see § 5.2). This is the *only* mechanism that crosses org boundaries, and it buys decoupled upgrade timing (app A pins `^2`, upgrades when *it* chooses) and Renovate propagation (Renovate needs a version to detect). The publish "overhead" is the thing buying the stability — and it collapses to near-nothing when automated: changesets opens a release PR on merge, CI publishes with provenance, Renovate auto-opens consumer PRs, CI-green patch/minor auto-merge. The human steps become "write the change, review the auto-PRs."
- *Bootstrap shortcut only:* static config (tsconfig/biome) MAY be pulled by git-dep/`degit` into the copier template on day one, replaced by proper publishing once stable — but this MUST NOT be done for the std.


## § 9 Deferred decisions & triggers to revisit

Written down so these are *decisions*, not drift:

- **Komodo (thin git-native deploy UI)** — trial after the foundation is stable, if a dashboard is wanted. Not before.
- **An orchestrator (e.g. vanilla Kestra)** — only on the § 7.8 triggers (multi-host dependent workflows, approvals, unmanageable schedule count, replay needs).
- **Observability (metrics, logs, dashboards, phone alerting)** — becomes part of the paved road later. The answer to "when is it time to scale?" is *data, not vibes* — the usual gap is measurement, not orchestration — and the same stack provides the "what's running where" view grouped by `plexus.tenant`. Candidates: Grafana + Prometheus/node-exporter + Loki, or lighter (Beszel + Uptime Kuma). Until then, the only monitoring the standard requires is the § 7.8 dead-man's-switch.
- **A concrete dead-man's-switch service for the reference stack** — the § 7.8 requirement (every scheduled job MUST ping on success) stands now; which service — self-hosted (e.g. Uptime Kuma) or managed (e.g. Healthchecks.io) — joins the reference stack is decided together with observability.
- **Kubernetes** — only on genuine multi-node scheduling / contractual HA-SLA / team-coordination needs. Not anticipated for years: single beefy hosts with Compose scale far past small-tenant needs, the bottleneck will be Postgres and operator time long before Compose, and self-hosted K8s would *worsen* the bus factor.
- **Moving a commercial tenant off the shared box** — the day a tenant has a customer with real data-processing expectations (anything in a regulated domain), revisit migrating that tenant's VMs to metal it controls itself. Not because the hypervisor stops isolating, but because "dedicated, tenant-only" can be a *commercial/trust* requirement independent of the technical reality. The one-VM-per-tenant rule already keeps this migration path clean.
- **Application-plumbing packages** — the § 3 "standardize boundaries" edges (framework glue, common auth concerns, repeatable non-domain features) as published `@plexus-ms/*` packages. Extract when a second app needs the same plumbing — never speculatively from the first; until then it lives in the app that needs it.
- **Preview environments per PR** — deferred deliberately. A single `staging` per app covers ~90% of the value; revisit when a product has real customers.
- **Per-tenant second admins** — provision lazily, only when a real second operator exists.
- **A second maintainer for `plexus-ms` itself** — the initiative's own bus-factor mitigation (§ 4.2). Same lazy rule as second admins — when a real second contributor exists — but with one proactive trigger: the day a third-party tenant runs the standard in production, single-maintainer governance stops being merely honest and starts being a liability to someone else.


## § 10 Versioning & conformance

### § 10.1 Versioning of this standard

The frontmatter `version` of this document identifies the revision of PLX itself: `v0` while the standard is a draft, then `vMAJOR.MINOR` (e.g. `v1.0`) once live; the frontmatter `timestamp` records the version's date.
Minor revisions are additive or clarifying — a repo conformant to `v1.0` remains conformant under every `v1.x`; only a major revision may change or remove requirements.

### § 10.2 What conformance means

A repo **conforms** to a PLX version when it satisfies every MUST and MUST NOT applicable to it under that version.
SHOULD and SHOULD NOT mark the paved road: deviating is permitted, but the deviation MUST be *owned* — recorded in the repo's `PLEXUS.md` (§ 10.3) with a sentence of rationale, so it reads as a decision, never as drift.
Reference-stack substitutions (see preamble) follow the same rule: substituting is conformant, and `PLEXUS.md` is where the tenant owns the divergence.

### § 10.3 The `PLEXUS.md` marker

Every conforming repo carries a `PLEXUS.md`; in a tenant monorepo, each app additionally carries one at its app root.
(The name is deliberately distinct from this document: `PLX.md` is the standard, `PLEXUS.md` is the per-repo marker.)
Because § 8's staleness detection must parse it mechanically, its format is specified:

```markdown
---
plx: v1.0        # PLX version this repo targets — REQUIRED
profile: app     # app | stateless-app | tenant-monorepo — REQUIRED
---

Free-form prose. Owned SHOULD-deviations and reference-stack
substitutions live here — one bullet each, with rationale.
```

Machine checks read **only the YAML frontmatter**; the body is for humans.
`plx` is compared against the current standard version to flag drift (§ 8, tier 3); `profile` selects which contract requirements apply (`app` and `stateless-app` per § 6/§ 6.2, `tenant-monorepo` per § 4.3).
A repo whose `PLEXUS.md` is missing or unparsable is *non-conformant by definition* — the marker is the one artifact the standard cannot degrade gracefully without, because it is how staleness stays visible (§ 8).
