# PLX Requirements List (reqlist)

> **GENERATED** from `PLX.md` v0 (2026-07-10) by `generate-reqlist.sh` — do not edit (§ 10.4).

75 entries: 63 MUST · 21 MUST NOT · 18 SHOULD · 2 SHOULD NOT · 8 MAY · 2 unclassified.

## § 4.2 Federation, not multi-tenancy
*Classes: tenant-platform, standard-repo*

- **MUST** — **Never shared (the substance):** hosts and root access, git org/repo access, secrets vaults, databases, backups, domains. These MUST remain partitioned by tenant.
- **MUST** — **Everything is forkable — legally, not just technically.** The shared repos are public, and every `plexus-ms` repo MUST carry a permissive OSI-approved license (reference: MIT). A tenant that must move forward alone forks, retags, and re-points its pins — same verbs, same mounts, new upstream.
- **MUST** — **Disclosure:** every `plexus-ms` repo MUST provide a private vulnerability-reporting channel (reference: GitHub private vulnerability reporting, declared in a `SECURITY.md`), and fixes ship as ordinary versions so the § 8 flow propagates them like any other change.
- **MUST** — tenants sharing a host MUST be separated by virtualization technologies (never co-mingling tenants inside one single VM). 
- **SHOULD** — Everything else — Docker, ingress, secrets vault, backups, domains — SHOULD be kept per-VM as well.
- **MUST** — distinct legal persons sharing one box under one admin MUST document the arrangement in writing — e.g. a one-page document defining the relationship, plus a data-processing agreement where applicable. 
- **MUST** — **Tenant identifier** — every tenant MUST have a short slug (e.g. `acme`, `initech`, and `plexus` itself, the project dogfooding its own standard), and every deployed service MUST carry the label `plexus.tenant=<slug>`. 
- **SHOULD** — The slug SHOULD additionally appear in the tenant's forge org name, VM hostnames, Ansible inventory groups, and vault name, so one greppable name threads through every layer. 

## § 4.3 Repo & namespace layout
*Class: tenant-monorepo*

- **MUST** — tenants MUST reference `itops` artifacts by tag, never by branch.
- **MUST** — **One forge org (or account) per tenant (MUST)** — org membership governs code access; a person in tenant A's org is simply not in tenant B's.
- **SHOULD** — **One monorepo per tenant (SHOULD)** — `<org>/<tenant>` (e.g. `plexus-ms/plexus`) holds **both** dev side (most likely a mise monorepo with pnpm workspace, maybe with advanced monorepo tooling like Turborepo in the future) and ops side (Ansible inventory, host/VM definitions, that tenant's deployment configs). The benefits are direct: apps and the platform that runs them version together, cross-cutting changes land as one atomic commit, and it is safe because a monorepo is one access boundary (§ 8).
- **SHOULD** — Tenant monorepos SHOULD be generated from `plexus-ms/preset`.

## § 5 The dev side
*Classes: app, tenant-monorepo, standard-repo*

- **MUST** — Nor is Plexus secretly JS-only: mise and hk are language-neutral, and their bindings are stack-neutral requirements, not JS conventions — every Plexus repo MUST pin its tools in `mise.toml` and expose its verbs as mise tasks, and every Plexus repo MUST wire its checks through `hk` git hooks per the § 5.1 hook discipline (format/lint on pre-commit, typecheck-equivalent + test on pre-push), with stack-appropriate checks behind the same hooks. The standard verbs (§ 6) are the stack-neutral layer every app answers; only § 5.1's pnpm/tsc specifics bind JS/TS repos alone. A Python or Go app takes the same contract with different incantations behind the same verbs — JS/TS is simply the first toolchain the standard has specified.

## § 5.1 The JS/TS toolchain convention
*Classes: app, tenant-monorepo*

- **MUST** — Every Plexus JS/TS repo MUST use this toolchain, each choice made to pass the second-reader and degradation tests:
- **MUST, MUST NOT** — **mise is the single toolchain authority.** Tool versions (node, pnpm, biome, even `npm:@changesets/cli`) MUST be pinned in `mise.toml` and *nowhere else*; a `package.json` MUST NOT carry `packageManager` or `engines`. *Why:* two pins for one fact is drift.
- **MUST NOT** — **No root `package.json` unless a tool forces it.** A monorepo root MUST NOT carry a `package.json` except where a tool leaves no alternative; pnpm defines the workspace without one. The single current exception is changesets (its `@manypkg/find-root` needs a root manifest to anchor the monorepo), so the root carries a dependency-free, pin-free stub (`{ name, private }`).

## § 5.2 Publishing the `@plexus-ms/*` packages
*Class: standard-repo*

- **MUST, MUST NOT** — Cross-tenant sharing MUST use **published, versioned packages** (§ 8). The `@plexus-ms/*` packages are published to **public npmjs** under the `@plexus-ms` scope, versioned by **changesets** (merge a "version packages" PR → CI publishes), with **npm provenance**. Provenance is a signed attestation, generated in CI via OIDC, that links each published version to the exact source commit and workflow that built it. Going public (rather than a private registry) is consistent with `@plexus-ms/*` being tenant-neutral *methodology, not substance* — which makes one guardrail load-bearing: **tenant substance (business logic, secrets, anything tenant-specific) MUST NOT appear in a public `@plexus-ms/*` package.**
- **MUST** — **Tags + GitHub Releases are automatic** (`changeset publish` tags each `@plexus-ms/<pkg>@x.y.z`, the action pushes them and cuts a Release from the changelog). The release branch (`main`) MUST be protected by a ruleset requiring those CI checks — a requirement, not a description of current setup.
- **MUST, SHOULD** — **Package-design rules.** A `@plexus-ms/*` package MUST be tenant-neutral methodology (the guardrail above). Code utilities SHOULD start in `@plexus-ms/std` — the standard *library* ("the standard" alone always names PLX itself, never this package) is the default home for any small shared concern — and a concern graduates to its own package once it has its own audience or its own release cadence (a consumer shouldn't take updates because an unrelated helper changed). Tool configs (`biome-config`, `tsconfig`) are separate packages by construction: they exist to be one-line `extends` targets. **API stability:** packages follow semver, enforced by changesets — a breaking change MUST be a major bump, and its changeset SHOULD carry a migration note so the changelog doubles as the upgrade guide.

## § 5.3 Branching & release model — different per repo type
*Classes: tenant-monorepo, standard-repo*

- **MUST** — The library and the apps version and release by completely different physics, so they use different branch models — each repo type MUST follow its column below; the two *why* paragraphs after the table carry the argument.
- **MUST NOT** — **Why apps use environment branches.** An app has no version number to reconcile — a release *is* a deploy keyed by git SHA — so the back-merge problem vanishes. Branches map to deploy targets (`develop`→staging, `main`→prod); "promote staging to prod" is merging `develop → main`. Apps therefore MUST NOT use changesets at all.

## § 5.4 Deploy granularity in a multi-app monorepo
*Class: tenant-monorepo*

- **MUST** — **The unit of deployment is the app; the unit of promotion is the repo.** A merge to an environment branch releases into that environment *exactly the apps whose sources changed in the merge*. CI MUST be path-scoped per app — an app's own directory plus every workspace package it depends on — so a docs-only merge deploys nothing, a `packages/ui` change redeploys its dependents, and unchanged apps are neither rebuilt nor redeployed. The deploy verb needs no change for this: it was per-app all along (`deploy(host, app, image_tag)`); CI simply fans it out over the changed set, and the changed set is derived from the push event's `before..after` diff — one definition that covers merge commits, squash merges, and multi-commit direct pushes identically — stateless, no bookkeeping.
- **MUST, MUST NOT** — **Promotion is the whole train.** "Promote staging to prod" remains one merge, `develop → main`, and that merge asserts *everything on `develop` is prod-ready*. The discipline this buys its simplicity with: **`develop` MUST stay promotable** — unfinished or still-soaking work lives on feature branches, never parked on `develop`. Selective promotion (cherry-picks, path-restricted merges) MUST NOT be used: it would put on prod a repo state that never existed on staging, destroying the one guarantee environment branches exist to give.
- **MUST NOT** — **A failed deploy parks the train — and recovery is named, not improvised.** The changed set carries no memory, so CI never *rediscovers* a failed deploy: after the rollback and alert (§ 7.2), the environment branch is ahead of what actually runs, and the next unrelated merge will not close the gap. Closing it is the operator's move, on paths already paved — re-run the failed CI job (same SHA, same derivation) once the cause is fixed, or invoke the hand-runnable deploy verb directly; never an empty commit. Until staging is green again, `develop → main` MUST NOT be merged: promotion asserts everything on `develop` is prod-ready, and a red staging deploy is that assertion's direct falsification.
- **MAY** — **Which host an environment *is*, is inventory, not convention.** `main`→prod and `develop`→staging name deploy *targets*; the binding — which VM, which `apps[]` record, which domain — lives in the tenant's `infra/` inventory alongside every other domain→port→app fact (§ 7.5), and the CI mount reads it from there. Staging and prod MAY share a VM or take one each — both sit inside one tenant's trust domain, and § 4.2 partitions tenants, not environments.
- **MUST** — **Hotfixes skip the train without derailing it:** branch from `main`, merge to `main` (path-scoping deploys only the fixed app), then back-merge `main → develop` immediately (MUST) so the branches keep converging.
- **SHOULD** — **The escape valve is a repo split, not a process patch.** If two products in one tenant *persistently* need independent release cadences — one must ship while the other soaks, again and again — that is the § 4.3 monorepo SHOULD yielding, not the train rule: move the product into its own repo (still inside the tenant's org and access boundary, still on the same contract). Granularity problems are solved by moving a product off the train, never by making promotion partial.

## § 6 The app contract
*Class: app*

- **MUST** — Every Plexus app repo MUST provide:
- **MUST, MUST NOT, MAY** — **`mise.toml` with the standard verbs** — at minimum `mise :dev`, `mise :migrate` (idempotent and roll-forward-only — § 6.1), `mise :seed`, `mise :test`, and the CI-facing `mise :lint`, `mise :typecheck`, `mise :build`: the shared pipeline (§ 7.3) invokes an app only through these standard names, so a stage a given stack has no use for MUST still exist as a documented no-op (the § 6.2 pattern), never as a missing verb. `seed` loads development sample data only: it MAY assume a fresh database (right after `migrate`) and MUST NOT be invoked by the deploy verb — production data arrives by restore or by real use, never by seed. "What was the migration command again?" stops being a memory question; the answer is always `mise :migrate`, and the mise task encodes the real incantation. Toolchain pinning follows § 5.1 — that rule is stated once there, and only referenced here — so setup is `git clone && mise :dev` everywhere.
- **MUST, SHOULD** — **`compose.yml`** declaring the app and its **app-owned** infrastructure (e.g. its own Postgres/Mongo container). Apps SHOULD default to one DB container each — full isolation, dies with the app. Data services MUST carry the labels `plexus.tenant=<id>` and `plexus.backup=<postgres|mongo|...>`. The `plexus.backup` value vocabulary is defined by the backup handlers `itops` ships (§ 7.7): a value is valid exactly when a handler for it exists, and extending the vocabulary means adding a handler.
- **MUST** — One variable per line, `KEY=value` dotenv syntax; every variable the app reads MUST be listed.
- **MUST** — A trailing comment holds flags and nothing else; prose belongs in full-line comments. A trailing comment containing anything outside the flag vocabulary is a schema error — rejected, never skipped. A value containing a literal `#` MUST be quoted (plain dotenv convention); an unquoted `#` starts a comment.
- **MUST** — An unflagged key is optional and non-secret. A `secret` key MUST have an empty value position — a default secret in git is a leak, not a default.
- **MUST** — Full-line comments are prose for humans; parsers MUST ignore them.
- **MUST, MUST NOT** — Stack-neutral, greppable (`grep secret env.schema`), and checkable — the platform diffs the schema against the env it provides. To keep the micro-format from ever forking, `itops` ships the **one canonical parser** (a verb like any other), and every consumer — the CI schema check, the provisioning role that resolves `secret` keys against `apps[].secrets` (§ 7.6) — MUST parse through it; two parsers that could disagree simply don't exist. Secret *values* are resolved from the tenant's vault at provisioning time (§ 7.6, never at deploy time) and MUST NOT be committed.
- **MUST NOT** — **A single HTTP port** — the app serves plain HTTP on one container port, published to loopback only. The *host* side of that binding is not the app's to choose: the host port is assigned by the platform from the tenant's inventory (§ 7.5) and injected at deploy time, so the app's `compose.yml` publishes via interpolation — `127.0.0.1:${PLEXUS_APP_PORT}:<container-port>` — and MUST NOT hardcode a host port. TLS, hostnames, and the domain→port binding are likewise the platform's job (§ 7.5); domain and host port alike are deployment substance, so the app stays deployable under any hostname and next to any neighbour. The `PLEXUS_` variable prefix is reserved for such platform-injected bindings: an app MUST NOT define `PLEXUS_*` keys of its own, and platform-injected keys do not appear in `env.schema` — the schema declares what the *app* reads, while `PLEXUS_APP_PORT` is read by compose interpolation; the platform's schema diff ignores `platform.env` keys accordingly.
- **MUST, MUST NOT, SHOULD** — **A healthcheck** — `GET /healthz`, with **readiness semantics**, pinned normatively because the deploy verb's rollback decision rides on this endpoint (§ 7.2): it MUST return 200 if and only if the process can serve real requests *right now* — which includes probing hard dependencies the app cannot serve without (its own database, with a short bounded timeout) and MUST NOT include soft or third-party dependencies the app survives degraded. The endpoint MUST be cheap, side-effect-free, and unauthenticated — the deploy verb polls it bare over loopback. Unauthenticated is not the same as private: ingress maps the public domain onto the same single port (§ 7.5), so left alone `/healthz` would ride into the open as a free oracle for "is this app's database down". The platform therefore fences the path at the proxy (§ 7.5), and — belt and braces — the response SHOULD carry nothing beyond its status code: no version strings, no dependency names, no timings. Plexus deliberately does **not** split liveness from readiness: that distinction pays for itself only where a reconciler restarts processes on liveness, and the standard has no reconciler (§ 7.2, the fence) — one endpoint, one meaning. Transient dependency blips are the *poller's* problem, and handled there (§ 7.2).
- **MUST, MUST NOT** — **Logs on stdout/stderr** — the app MUST write logs to stdout/stderr and MUST NOT manage its own log files; shipping and retention are the platform's job.
- **MUST** — **A CI reference** — the app's CI MUST run the shared pipeline (§ 7.3: lint → typecheck → test → build → push image); on the reference stack this is a ~5-line reference to the shared reusable workflow.

## § 6.1 Migration discipline
*Class: app*

- **MUST, MUST NOT, SHOULD** — **Idempotent, spelled out:** `migrate` MUST be safe to invoke at any time — already-applied steps are skipped, and running it against a fully-migrated schema is a no-op. A failure partway through MUST leave the schema in a state from which re-running `migrate` can complete (each step applied atomically where the database supports it). Concurrent invocations MUST NOT corrupt the schema; `migrate` SHOULD serialize itself via a lock — mainstream migration tools do this out of the box, so the requirement is usually just *don't disable it*.
- **MUST** — **Roll forward, never back.** The deploy flow has no down-migration step, and its rollback path (§ 7.2) re-launches the *previous* image against the *already-migrated* schema. Every migration MUST therefore be backward-compatible with the release currently in production — expand/contract discipline: additive changes (new tables, nullable columns, backfills) ship first, and destructive ones (drops, renames, constraint tightening) ship only in a later release, once no deployed code depends on the old shape.
- **MUST** — **The escape hatch is deliberate, not silent.** A genuinely breaking migration — one that cannot honor expand/contract — forfeits automatic rollback. It MUST be deployed as a deliberate act: fresh backup taken first, and the operator aware that reverting means *restoring*, not re-upping the previous tag.

## § 6.2 The stateless-app profile
*Class: app*

- **MUST** — contract; the state-specific MUSTs collapse to *documented no-ops* so the platform
- **MUST, MAY** — **`mise :migrate` MUST still be present** (as a documented no-op); `seed` MAY be omitted. The deploy verb still
- **MAY** — **The env schema MAY declare zero secrets** (only runtime knobs like `PORT`).
- **MUST** — **`/healthz`, the CI reference, and `PLEXUS.md` remain MUSTs.**

## § 7 The ops side
*Classes: tenant-platform, standard-repo*

- **MUST** — A new or reworked primitive MUST pass both litmus tests (§ 3) before it is declared done — second-reader and degradation are the definition of done here, not aspirations.
- **MUST** — **Verbs** (the *ops verbs* of § 2) — portable bash scripts (`scripts/`) that contain *all* the logic and MUST stay hand-runnable: `git clone && ./scripts/deploy.sh deploy@host app image` works with no forge at all. This is what passes the degradation test. Bash's native failure modes (unset variables expanding to nothing, pipelines failing silently) are second-reader traps, so a safety baseline is normative: every verb MUST run under strict mode (`set -euo pipefail` or equivalent) and MUST be shellcheck-clean, enforced mechanically at the repo boundary (hook or check — never the honor system).
- **MUST NOT** — **Workflow wrappers** — thin reusable GitHub workflows (`.github/workflows/`) that merely mount a verb on the forge's events: checkout, secrets plumbing, one invocation. **Logic MUST NOT live in the YAML.** GitHub's workflow format is not an open standard — the runner is self-hostable but GitHub remains the scheduler — so the wrapper is forge-specific and disposable, while the verb is portable and permanent. Leaving GitHub would mean rewriting the mounts, never the verbs.
- **MUST** — **Ansible roles** (`ansible/` — the `plexus.itops` collection) — the same split applied to the platform layer: the roles are the shared logic core, and each tenant's `infra/` keeps only the binding — `site.yml` (a roles list), inventory, group_vars, `op.env`. A tenant playbook is to the roles what a workflow wrapper is to a verb: a mount, not logic. Tenants MUST pin the collection by tag in `requirements.yml`; every change under `ansible/` MUST bump `galaxy.yml` (SCM installs record that version — a moved tag alone won't reinstall).

## § 7.2 The deploy verb — a verb, not a system
*Classes: tenant-platform, standard-repo*

- **MUST NOT** — **The fence (MUST NOT be crossed without a deliberate, documented decision):** no persistent state · no daemon · no UI · no reconciliation loop · no provisioning of platform resources at deploy time. Inside the fence, invest freely (logging, clean rollback, good error messages). Outside it, it's either an existing tool's job or an architecture change — not feature creep.

## § 7.3 CI
*Classes: tenant-platform, standard-repo*

- **MUST NOT** — One reusable workflow in `plexus-ms/itops`: lint → typecheck → test → build → push image (tagged with git SHA). Every stage that touches the app runs through its contract verbs (`mise :lint`, `:typecheck`, `:test`, `:build` — § 6); the image push is the workflow's own step. That indirection is what keeps one workflow tenant- and stack-neutral: it knows verb names, never incantations. Each app references it in ~5 lines; in a multi-app monorepo each app's mount is path-scoped to that app and its workspace dependencies, so a push builds and deploys only what changed (§ 5.4). Push → tests run. GitHub Actions is a control plane, but one *someone else operates* with git as input — that's allowed; a tenant MUST NOT operate its own.

## § 7.5 Ingress
*Classes: tenant-platform, standard-repo*

- **SHOULD** — Platform concern. A reverse proxy per VM (reference stack: Caddy) terminates TLS and maps domains to app ports. **The host port belongs to the platform, not the app:** each app's host port is assigned in the tenant's inventory (`apps[].port`), in the same record that binds its domain — domain→port→app is one line in `infra/`, so per-VM port uniqueness is checkable in a single file (the playbook SHOULD fail on a duplicate) instead of being coordination state scattered across app repos. From that one record, provisioning renders the ingress config *and* injects the port into the app's compose interpolation (§ 6): it writes the value to `<app_dir>/platform.env` on the host, and the deploy verb hands that file to compose alongside its own `.env` — the verb itself stays port-unaware. A domain, like a host port, is deployment substance, never the app's concern. The contract's side of the seam stays deliberately small: one loopback-published HTTP port (§ 6).
- **SHOULD** — One path is deliberately not routed: the proxy SHOULD refuse external requests for `/healthz` (§ 6) — the endpoint exists for the loopback poller and probes hard dependencies, so routing it publicly would publish a database-status oracle. A tenant that points an external uptime monitor at it does so as an owned deviation (§ 10.2), knowing what it reveals.

## § 7.6 Secrets
*Classes: tenant-platform, standard-repo*

- **MUST, MUST NOT** — **Rotation is complete only when the running process holds the new value.** Environment is injected at container *creation* — rewriting `secrets.env` on its own rotates a file, not a credential. The full loop is therefore: change the vault item → re-run the playbook (rewrites `secrets.env`) → **re-create the affected containers**. The playbook MUST close that loop itself: the role that writes `secrets.env` notifies a handler that re-ups the app whenever the file changed, and compose re-creates exactly the services whose environment differs. One duplication trap sits here, and the standard closes it: re-upping means invoking compose with the *same* wiring the deploy verb uses — `.env` and `platform.env` handed in for interpolation, `secrets.env` loaded from inside the compose file — and that invocation MUST be encoded exactly once, as an `itops` verb that both the deploy verb's up step and the handler call. An Ansible handler that open-codes its own `docker compose up -d` is logic in YAML (§ 7) and a second copy of the env-file wiring, waiting to drift. So "re-run the playbook" genuinely rotates — but only because the handler exists; rotation MUST NOT be left to ride along on whenever the next deploy happens to run. This is also the one documented interaction between secrets and the deploy verb: a redeploy re-creates containers and thereby picks up the *current* `secrets.env` as a side effect, yet the verb itself still never reads, writes, or resolves a secret — staying secret-unaware is part of what keeps it a verb, not a system.

## § 7.7 Backups
*Classes: tenant-platform, standard-repo*

- **MUST** — Platform concern, scheduled-event-driven. Ansible installs a nightly unit per VM: `pg_dump`/`mongodump` per labelled data service + restic to an off-site repository (e.g. a Hetzner Storage Box). Schedule + retention MUST live as code in the tenant monorepo's `infra/`. The backup job MUST discover what to dump by **reading the `plexus.backup` labels** — new app deployed → automatically backed up, zero bookkeeping. Failure surfaces via the dead-man's-switch (§ 7.8): a failed nightly unit never pings, and the missed ping alerts.
- **SHOULD** — **The restore test is a scheduled job like any other:** Ansible installs a periodic unit (SHOULD run at least monthly) that restores the latest snapshot of each labelled data service into a scratch container and runs a sanity check — the dump loads, a trivial query answers — then pings **its own dead-man's-switch check**, separate from the backup job's. A restore test that silently stops running alerts exactly like a backup that silently stops running.
- **MUST** — **First-use gate:** a new backup path MUST pass one end-to-end restore before it is relied upon — that first run of the restore test *is* the verification — and MUST be re-verified after any material change to the path; the scheduled test carries re-verification from then on.

## § 7.8 Scheduling & the orchestrator question
*Classes: tenant-platform, standard-repo*

- **MUST NOT** — **No orchestrator in v1.** A workflow orchestrator (Kestra, Airflow, etc.) MUST NOT be stood up as platform infrastructure. The jobs an orchestrator would do are already covered:
- **MUST** — "Did a cron silently stop?" → a **dead-man's-switch**: every scheduled job MUST ping a per-job check on success, and a missed ping MUST raise an alert. Which monitor provides the checks, and which channel carries the alert — self-hosted or managed — are reference-stack choices, deferred (§ 9); the requirement stands regardless of the tool. The valuable 20% of an orchestrator at ~zero operating cost.
- **SHOULD** — *Revisit an orchestrator only when:* workflows span multiple hosts with inter-step dependencies · human-in-the-loop approvals appear · scheduled-job interrelations become hard to track · backfill/replay ("re-run last Tuesday") matters. If reached, prefer a single vanilla shared instance (solve secrets via `op run` or equivalent, not a fork). An orchestrator that exists but barely runs anything is fog by this document's own definition; a tenant that finds itself with one SHOULD migrate its jobs onto the mechanisms above or retire it.

## § 8 Propagation with customizability
*Classes: tenant-monorepo, standard-repo*

- **MUST** — **Renovate's own status, settled explicitly:** the *mechanism* is normative — every conforming repo MUST run an automated update bot that watches its pins and opens PRs, because a pin no machinery watches is invisible staleness (§ 1) — while the *bot* is reference stack: Renovate, extending the shared preset, is the reference choice this section is written against, and substituting an equivalent is owned per § 10.2 like any other reference-stack divergence.
- **MAY** — **`@plexus-ms/*` packages** — run inside an app, versions immutable and provenance-attested: CI-green patch/minor auto-merge MAY be enabled and is the paved-road default.
- **SHOULD, MAY** — **CI workflow and verb tag bumps** — run in tenant CI, next to its secrets, and reference a movable tag (§ 4.2): auto-merge MAY be enabled, but a tenant whose CI holds sensitive credentials SHOULD review these PRs instead.
- **SHOULD NOT** — **The `plexus.itops` Ansible collection** — runs with root on tenant hosts: Renovate opens the PR, but it SHOULD NOT be auto-merged; a human reads the diff before anything new runs as root.
- **MUST** — **Does the shared thing cross a tenant boundary? Yes → it MUST be a published, versioned package. No → workspace dependency.**
- **MUST NOT, MAY** — *Bootstrap shortcut only:* static config (tsconfig/biome) MAY be pulled by git-dep/`degit` into the copier template on day one, replaced by proper publishing once stable — but this MUST NOT be done for `@plexus-ms/std`.

## § 10.2 What conformance means
*Classes: app, tenant-monorepo, tenant-platform, standard-repo*

- **MUST, MUST NOT** — A repo **conforms** to a PLX version when it satisfies every MUST and MUST NOT applicable to it under that version.
- **MUST, SHOULD, SHOULD NOT** — SHOULD and SHOULD NOT mark the paved road: deviating is permitted, but the deviation MUST be *owned* — recorded in the repo's `PLEXUS.md` (§ 10.3) with a sentence of rationale, so it reads as a decision, never as drift.
- **MUST, MAY** — Reference-stack substitutions follow the same rule: a tenant MAY substitute an equivalent for any reference-stack choice (preamble), the substitution MUST be recorded the same way, and `PLEXUS.md` is where the tenant owns the divergence.

## § 10.4 The requirements list
*Class: standard-repo*

- **MUST, SHOULD** — Normative content is mechanically extractable from this document by construction: every binding requirement carries an ALL-CAPS keyword (preamble), so the full MUST/SHOULD inventory is one grep away, each hit carrying its section anchor.
- **MUST** — the compendium MUST ship the reqlist-generator alongside the standard — a script like any other verb, hand-runnable — and MUST regenerate the index whenever the standard changes.
- **MUST NOT** — The index MUST NOT be hand-maintained: a hand-edited requirements list beside its source is exactly the shadow documentation that drifts and rots (§ 1) — the source stays the single authority.

## Unclassified

*Hits the section→class mapping cannot place — listed, never guessed (§ 10.4).*

- **MUST** [§ 9] — **A concrete dead-man's-switch service for the reference stack** — the § 7.8 requirement (every scheduled job MUST ping on success) stands now; which service — self-hosted (e.g. Uptime Kuma) or managed (e.g. Healthchecks.io) — joins the reference stack is decided together with observability.
- **SHOULD** [§ 9] — **Host patching & lifecycle** — who updates the OS and Docker engine on tenant VMs, and when a host is rebuilt rather than patched, is explicitly deferred. Interim posture: the base role SHOULD enable the distribution's unattended security upgrades, and everything beyond that (kernel-update reboots, engine major bumps, host rebuilds) is a supervised operator act. Revisit together with observability — patch drift has to be visible before a policy about it can be honest.
