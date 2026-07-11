---
title: The Plexus Manual
short_title: Manual
description: How the plexus-ms organization operates its own repos — release mechanics, artifact layering, governance, roadmap.
version: v0
timestamp: 2026-07-11
order: 3
---

Plexus is a comprehensive, opinionated, federated IT initiative: 
A neutral collection of guidelines, tools, and approaches, spanning software development to operations. 

This is the operating manual of the `plexus-ms` organization itself: how the repos that publish the shared methodology are structured, released, and governed.
It binds the maintainers, not the tenants — a consumer never needs it, and a contributor starts here.
The tenant-facing contract is [PLX, the Plexus Standard](standard.md); the reasoning behind the whole design is the [Manifesto](manifesto.md).

Unlike the standard, this document carries no BCP 14 keywords: its rules are written in plain prose, and they are still rules.
Where a maintainer obligation backs a guarantee tenants rely on, the standard states the guarantee (§ 3.5 PLX) and this manual records the mechanics that honor it.

## The repos

| Repo | Offering |
|---|---|
| **`library`** — dev side, focused on web technologies | The published `@plexus-ms/*` packages for the web / Node / TypeScript world: shared tool configs (biome, tsconfig), the `std` utilities, and — over time — the reusable application plumbing (framework glue, common auth concerns, repeatable non-domain features) that keeps each app's domain core small. |
| **`itops`** — ops side, focused on GitOps and IaC | The operations primitives: portable bash verbs, thin workflow wrappers that mount them on the forge, and the `plexus.itops` Ansible collection that provisions tenant hosts. Three artifact classes, one version tag. |
| **`preset`** — uniting both sides | A copier template that composes dev and ops into a ready tenant monorepo — `apps/` consuming the library, `infra/` binding the Ansible collection — and keeps generated repos re-syncable via `copier update`. |
| **`compendium`** — the doctrine | The three documents (Manifesto, Standard, Manual), the generated requirements list, and the supporting reference docs. |

The org doubles as home of `plexus`, the public dogfooding tenant — which is bound by the standard like any other tenant, not by this manual.
The border between dev side and ops side is blurry, and that is fine: CI is dev-side checks on an ops-side mount, and the app contract (§ 5 PLX) is the seam made explicit.
What matters is never which side a primitive lives on, but that it is tenant-neutral and composable.

Every `plexus-ms` repo follows the same toolchain conventions the standard sets for tenant repos (§ 4 PLX): tools pinned in `mise.toml`, verbs as mise tasks, checks wired through hk — the initiative eats its own cooking.

## Artifact layering

Procedures are layered as shared logic cores with thin mounts, and the boundary is load-bearing:

- **Verbs** — portable bash scripts (`itops` `scripts/`) that contain *all* the logic and stay hand-runnable: `git clone && ./scripts/deploy.sh deploy@host app image` works with no forge at all. This is what passes the degradation test.
  Bash's native failure modes (unset variables expanding to nothing, pipelines failing silently) are second-reader traps, so a safety baseline applies to every verb: strict mode (`set -euo pipefail` or equivalent) and shellcheck-clean, enforced mechanically at the repo boundary — hook or check, never the honor system.
- **Workflow wrappers** — thin reusable GitHub workflows that merely mount a verb on the forge's events: checkout, secrets plumbing, one invocation.
  Logic never lives in the YAML.
  GitHub's workflow format is not an open standard — the runner is self-hostable but GitHub remains the scheduler — so the wrapper is forge-specific and disposable, while the verb is portable and permanent.
  Leaving GitHub would mean rewriting the mounts, never the verbs.
- **Ansible roles** — the same split applied to the platform layer: the roles are the shared logic core, and each tenant's `infra/` keeps only the binding — `site.yml` (a roles list), inventory, group_vars, `op.env`.
  A tenant playbook is to the roles what a workflow wrapper is to a verb: a mount, not logic.

Two definition-of-done gates for any new or reworked primitive, from the [Manifesto](manifesto.md)'s litmus tests: a competent second reader understands it top to bottom in half an hour, and if it vanished tonight the job would still be doable by hand from the artifacts in git.
These are the definition of done, not aspirations.

**The deploy verb has a fence**, and crossing it takes a deliberate, documented decision: no persistent state, no daemon, no UI, no reconciliation loop, no provisioning of platform resources at deploy time.
Inside the fence, invest freely — logging, clean rollback, good error messages.
Outside it, it is either an existing tool's job or an architecture change, not feature creep.

Two single-encoding obligations sit in `itops` because the standard's platform machinery depends on them (§ 5.3, § 8.2 PLX): the canonical `env.schema` parser (every consumer parses through it, so the micro-format cannot fork), and the compose-up verb (the one encoding of the env-file wiring, called by both the deploy verb's up step and the rotation handler).

## library: releasing the packages

The library is trunk-based on a single `main`, versioned and published by **changesets**.
Why trunk-based: changesets accumulates changeset files on one branch, bumps them in one PR on that branch, and publishes from it.
A second long-lived branch (GitFlow `develop`) forces reconciling version numbers between branches on every release — a perpetual back-merge tax; changesets is a trunk-based tool, and pairing it with GitFlow fights it.
Concurrency is not a reason to avoid this: changeset files have random names and the bump is deferred to one central step, so simultaneous feature branches never conflict and never double-publish.
(The apps' environment-branch model is the tenant-facing counterpart, specified in § 7.1 PLX — the two models are never mixed.)

How a release runs:

- **Two phases.** Changesets accumulate on `main`; `changesets/action` opens a "version packages" PR that bumps versions and writes changelogs; merging it publishes.
  The only manual step is recording a changeset with each publishable change — versioning and publishing run in CI, never locally.
  PRs run lint/typecheck/test/build plus a `changeset status` guard that fails when a publishable change ships without a changeset.
- **Token-less via OIDC.** Publishing authenticates through GitHub OIDC *trusted publishing* (`id-token: write`), not a stored npm token — which also makes provenance automatic.
  *Bootstrap caveat:* a package cannot be registered as a trusted publisher until it exists, so each package's **first** publish is a one-time manual `npm publish` — token-authenticated and therefore *without* provenance; the attestation chain starts at the second release, and CI takes over after.
- **Tags and GitHub Releases are automatic** — `changeset publish` tags each `@plexus-ms/<pkg>@x.y.z`, the action pushes them and cuts a Release from the changelog.
  The release branch (`main`) is protected by a ruleset requiring those CI checks — keep it that way; this is what stands behind the § 3.5 PLX guarantees.

**Package-design rules.**
A `@plexus-ms/*` package is tenant-neutral methodology, never substance — this is the standard's guardrail (§ 3.5 PLX), and it binds every publish.
Code utilities start in `@plexus-ms/std` — the standard *library* ("the standard" alone always names PLX itself, never this package) is the default home for any small shared concern — and a concern graduates to its own package once it has its own audience or its own release cadence: a consumer shouldn't take updates because an unrelated helper changed.
Tool configs (`biome-config`, `tsconfig`) are separate packages by construction: they exist to be one-line `extends` targets.
Packages follow semver, enforced by changesets — a breaking change is a major bump, and its changeset carries a migration note so the changelog doubles as the upgrade guide (again backing § 3.5 PLX).

## itops: versioning the ops artifacts

All three artifact classes — verbs, workflow wrappers, Ansible roles — version together under one `vN` tag; `itops` has no CI of its own beyond its checks.
Every change under `ansible/` bumps the `galaxy.yml` version: SCM installs record that version, so a moved tag alone won't reinstall.
Tenants pin the collection by tag (§ 9.1 PLX); the tag-mutability trade-off this creates is named in the standard (§ 3.5 PLX) and accepted deliberately — revisit if attestation for tag-referenced artifacts becomes practical.

## preset: the template

`copier copy gh:plexus-ms/preset <tenant>` generates a tenant monorepo; `copier update` re-applies template changes as a three-way merge against local edits, surfacing conflicts explicitly — template as living dependency, not `cp`.

Scaffolding is the last resort, chosen per artifact in three tiers:

1. **Convert to a dependency if at all possible.** Most "boilerplate" is secretly extractable — a `mise.toml` can `include` a shared, version-pinned task file (`git::…?ref=vN`), keeping only project-specific tasks local.
   This is the highest-value work; every bit extracted moves from the rotting pile to the auto-propagating pile, and the version pin lets the update bot carry the updates.
2. **Use a re-appliable scaffolder, not `cp`.** copier records the template version a project was generated from and merges updates like a rebase.
3. **For the genuine remainder, make staleness visible:** the `PLEXUS.md` marker's frontmatter is mechanically checkable, and a scheduled check flags repos that have drifted behind the current standard.
   These are never auto-fixed, but they are never invisibly stale — and invisible staleness, not staleness itself, is the failure mode.

One bootstrap shortcut is permitted and bounded: static config (tsconfig/biome) can be pulled by git-dep/`degit` into the template on day one, replaced by proper publishing once stable — but never for `@plexus-ms/std`.

## compendium: the doctrine

Three documents with three registers, one per audience:

- [`manifesto.md`](manifesto.md) — why; evocative register is allowed here and nowhere else.
- [`standard.md`](standard.md) — the tenant contract; BCP 14, requirements as blockquotes, sober prose.
- `manual.md` — this document; internal rules in plain prose.

The standard's structural conventions are self-policing, and the machinery lives here:

- Every requirement is a `> - ` line under its section heading; blockquotes are reserved for requirements (§ 1.2 PLX).
- `generate-reqlist.sh` regenerates [`standard-reqlist.md`](standard-reqlist.md) from that structure — headings plus quoted lines, nothing cleverer — and *fails* if a BCP 14 keyword appears anywhere outside a blockquote.
  Run it via `mise reqlist`; a pre-commit hook regenerates and stages the list whenever the standard changes.
  The generated list is never hand-edited (§ 10.4 PLX).
- Section numbers are append-only within a major version (§ 1.4 PLX): new sections go at the end of their level, insertions wait for a major revision.

**Graduating the draft is a bar, not a feeling.** `v1.0` of the standard requires: every roadmap deferral below resolved or explicitly re-deferred, the reqlist generating clean (generation and keyword lint both green), and at least one tenant besides `plexus` itself conformant in production.

## Governance & roadmap

**Bus factor, honestly.** Today one maintainer controls the doctrine, the packages, the template, and the supply chain.
The consequences and the day-one safety net are stated where tenants can see them (§ 3.5 PLX, and the [Manifesto](manifesto.md)'s honest edges).
More maintainers follow the same lazy rule as everything else — when a real second contributor exists — with one proactive trigger: the day a third-party tenant runs the standard in production, single-maintainer governance stops being merely honest and starts being a liability to someone else.

**Deferred decisions, written down so they are decisions, not drift:**

- **An orchestrator (e.g. vanilla Kestra)** — only on the § 8.4 PLX triggers: multi-host dependent workflows, approvals, unmanageable schedule count, replay needs.
- **Observability (metrics, logs, dashboards, phone alerting)** — becomes part of the paved road later.
  The answer to "when is it time to scale?" is data, not vibes — the usual gap is measurement, not orchestration — and the same stack provides the "what's running where" view grouped by `plexus.tenant`.
  Candidates: Grafana + Prometheus/node-exporter + Loki, or lighter (Beszel + Uptime Kuma).
  Until then, the only monitoring the standard requires is the § 8.4 PLX dead-man's-switch.
- **A concrete dead-man's-switch service for the reference stack** — the requirement stands now (§ 8.4 PLX); which service — self-hosted (e.g. Uptime Kuma) or managed (e.g. Healthchecks.io) — joins the reference stack is decided together with observability.
- **An alerting channel (paging, chat, email)** — the standard requires alerts to exist (§ 7.3, § 8.4 PLX) but defers the channel; today a failed deploy alerts as the failing CI job, and the monitor notifies however it natively can.
  Who gets woken, and how, is decided together with observability.
- **Host patching & lifecycle** — the interim posture is in the standard (§ 8.5 PLX: unattended security upgrades on, everything else supervised); the full policy is deferred until patch drift is visible — visibility first, then an honest policy.
- **Kubernetes** — only on genuine multi-node scheduling / contractual HA-SLA / team-coordination needs.
  Not anticipated for years: single beefy hosts with Compose scale far past small-tenant needs, the bottleneck will be Postgres and operator time long before Compose, and self-hosted K8s would *worsen* the bus factor.
- **Moving a commercial tenant off shared metal** — the day a tenant has a customer with real data-processing expectations (anything in a regulated domain), revisit migrating that tenant's VMs to hardware it controls itself.
  Not because the hypervisor stops isolating, but because "dedicated, tenant-only" can be a commercial/trust requirement independent of the technical reality; the one-VM-per-tenant rule already keeps the migration path clean.
- **Application-plumbing packages** — the "standardize boundaries" edges (framework glue, common auth concerns, repeatable non-domain features) as published `@plexus-ms/*` packages.
  Extract when a second app needs the same plumbing — never speculatively from the first; until then it lives in the app that needs it.
- **Zero-downtime deploys (blue-green / rolling)** — the deploy verb re-creates containers in place and accepts seconds of downtime per deploy (§ 7.3 PLX).
  Revisit when an app has traffic for which a blink is a real cost; whatever the answer, it stays a verb, not a reconciler (the fence, above).
- **Registry image retention** — SHA-tagged images accumulate in GHCR unboundedly, and nothing prunes them; that is the deliberate default for now (rollback and re-deploys assume history stays available, and storage is cheap at this scale).
  Revisit when registry cost or quota bites; any future GC policy has a floor — the tags currently deployed in any environment, plus their predecessors — or rollback loses its guarantee.
- **Preview environments per PR** — a single staging per app covers ~90% of the value; revisit when a product has real customers.
- **Per-tenant second admins** — provision lazily, only when a real second operator exists.
