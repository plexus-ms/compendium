---
title: The Plexus Requirements List
short_title: The Reqlist
description: Condensed requirements list extracted from the Plexus Standard.
version: v0
timestamp: 2026-07-11
note: Auto-generated from `standard.md` v0 (2026-07-11) by `generate-reqlist.sh` — do not edit.
order: 2
---

## § 1 General provisions

### § 1.1 Normative language

- The keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY in this document are to be interpreted as described in BCP 14 ([RFC 2119](https://www.rfc-editor.org/rfc/rfc2119), [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174)).
- Blockquotes in this document are reserved for normative statements; everything outside a blockquote is informative prose.
- Normative keywords appear only inside blockquotes; a keyword outside one is a defect in this document, and should be reported as a bug.

### § 1.2 Normative tools and services

- A tool or service named inside a MUST is mandated: part of the standard itself.
- A tool or service named inside a SHOULD is a suggested default; a tenant MAY substitute an equivalent, owning the deviation in `PLEXUS.md` (§ 3.4).

## § 2 The supply chain and upstream guarantees

- The `plexus-ms` repos are **public and GPLv3-licensed**; every change is reviewable, and nothing breaks on the day the upstream goes unmaintained — published versions keep resolving, and the repos remain forkable.
- `@plexus-ms/*` packages are published to the public NPM registry; published versions are immutable and carry provenance attestations linking each version to its source commit and build.
- A breaking change to a package is released as a semver major, with a migration note in the changelog.
- Tenant substance — business logic, secrets, anything tenant-specific — never appears in a public package.

## § 3 The tenant

### § 3.1 Trust domain

- All tenants MUST share the methodology: the app contract, the `@plexus-ms/*` packages, the reusable CI workflow, the deploy verb, the copier template, the Ansible roles, the doctrine.
- Tenants MUST NOT share substance: hosts and root access, forge org and repo access, secrets vaults, databases, backups, domains.

### § 3.2 Slug & labels

- Every tenant MUST have a short slug (e.g. `acme`, `initech`, `plexus`).
- Every deployed service MUST carry the label `plexus.tenant=<slug>`.
- The slug SHOULD additionally appear consistently in the tenant's forge org name, VM hostnames, Ansible inventory groups, and vault name.

### § 3.3 The `PLEXUS.md` marker

- Every conforming repo MUST carry a `PLEXUS.md` marker at its root.
- The repo marker MUST carry YAML frontmatter with `plx` (the PLX version targeted) and `profile` = `repository`).
- Every conforming app MUST carry a `PLEXUS.md` marker at its root. In a tenant monorepo, this will be at `apps/<app-name>/PLEXUS.md`.
- The app marker MUST carry YAML frontmatter with `plx` (the PLX version targeted) and `profile` being one of the profiles listed in § 6.
- A repo or app whose `PLEXUS.md` is missing or unparsable is non-conformant.

### § 3.4 Conformance

- A repo or app conforms to a PLX version when it satisfies every MUST and MUST NOT applicable to it under that version.
- Deviating from a SHOULD or SHOULD NOT is permitted, but the deviation MUST be recorded in `PLEXUS.md` with a sentence of rationale.

### § 3.5 Shared metal

- Tenants sharing physical hardware MUST be separated by hypervisor virtualization; two tenants MUST NOT co-mingle inside one VM.
- Platform concerns — ingress, secrets, backups, monitoring — SHOULD be kept per-tenant as well.
- Distinct legal persons sharing platform root access or further platform concerns MUST document the arrangement in writing — e.g. a one-page document defining the relationship, plus a data-processing agreement where applicable.

### § 3.6 Forge layout

- Tenant repos SHOULD be partitioned by separate forge orgs.
- A tenant SHOULD use the monorepo pattern: one `<org>/<tenant>` repo holding both the dev side (`apps/`, `packages/`) and the ops side (`infra/`: inventory, host definitions, deployment configs).
- Tenant monorepos SHOULD be generated from `plexus-ms/preset`.

## § 4 The toolchain

### § 4.1 mise & hk, in every repo

- Every tenant repo MUST expose its verbs as mise tasks at the repo root, and MUST bootstrap its stack's entry-point tools in `mise.toml`.
- A fact with an ecosystem-canonical home MUST live in that home and MUST NOT be restated elsewhere; mise pins only facts that have no such home.
- Every tenant repo MUST wire its checks through hk git hooks: format and lint on pre-commit, `check` and `test` on pre-push, with stack-appropriate checks behind the same hook names.
- Git hooks SHOULD delegate to mise tasks.
- mise tasks MUST NOT encode cross-project ordering; the task graph belongs to the stack's graph-aware tool (§ 4.2), to which the verbs delegate.

### § 4.2 The JS/TS toolchain

- Every Plexus JS/TS repo MUST use the toolchain of this section.
- JS/TS tenant repos MUST use the monorepo pattern: pnpm workspace plus Turborepo.
- Turborepo owns the task graph: leaf tasks are `package.json` scripts, `turbo.json` states the task rules (`build`, `typecheck`, and `test` depend on `^build`), and the workspace edges are read from each `package.json` — the graph MUST NOT be re-encoded in mise tasks or CI configuration.
- Leaf projects MUST NOT carry a `mise.toml`; the root verbs delegate to turbo.
- mise MUST install only node for the JS/TS toolchain; the package manager arrives through node itself — a `postinstall` hook enables corepack, which installs the pnpm version pinned in the root `package.json` `packageManager` field, the single pnpm pin (Turborepo requires the field anyway).
- The node version MUST be pinned exactly once: `NODE_VERSION` in the root `mise.toml` `[env]`, read by `[tools]` via template, by CI via `mise env`, and by the image build as a build arg.
- JS-ecosystem dev tools (turbo, biome, …) MUST be devDependencies — on the PATH via mise's `_.path`, never mise `[tools]` entries; a `package.json` MUST NOT carry `engines`.

## § 5 The app contract

- Every app MUST satisfy this section, and MUST declare exactly one § 6 profile in its `PLEXUS.md` (§ 3.3).

### § 5.1 Standard verbs

- Every tenant repo MUST answer the standard verbs as root mise tasks, each taking an optional app argument: `dev`, `build`, `check`, `test`.
- `dev` MUST take a fresh checkout to a running development environment; `build` MUST produce the production artifact; `check` MUST run every static check that gates a deploy; `test` MUST run the tests that gate a deploy, providing whatever environment they need.
- Every verb MUST succeed from a fresh checkout — installing dependencies and building internal workspace packages first is the repo's own business (§ 4.2), never the caller's.
- A verb a given stack has no use for MUST still exist and pass (a documented no-op), never as a missing verb.

### § 5.2 compose.yaml

- Every app MUST provide a `compose.yaml` declaring the app service and any app-owned infrastructure.
- Every service in it MUST carry the label `plexus.tenant=<slug>` (§ 3.2).

### § 5.3 The env schema

- Every app MUST provide an `env.schema` file at the app root declaring every variable the app reads.
- One variable per line, `KEY=value` dotenv syntax; every variable the app reads MUST be listed.
- The value position MUST hold the default; an empty value means no default.
- Flags MUST be a trailing comment on the same line as the key — `# required`, `# secret` — whitespace-separated, combinable in either order.
- A trailing comment MUST hold flags and nothing else; a trailing comment containing anything outside the flag vocabulary is a schema error — rejected, never skipped. Prose belongs in full-line comments.
- A value containing a literal `#` MUST be quoted; an unquoted `#` starts a comment.
- An unflagged key is optional and non-secret; a `secret` key MUST have an empty value position — a default secret in git is a leak, not a default.
- Parsers MUST ignore full-line comments.
- Every consumer of the schema MUST parse it through the canonical parser `itops` ships; where this grammar is silent, that parser's behavior is normative.
- Secret values MUST NOT be committed; they are resolved from the tenant's vault at provisioning time (§ 7.2).

### § 5.4 One HTTP port

- The app MUST serve plain HTTP on exactly one container port, published to loopback only.
- The app MUST NOT hardcode a host port; `compose.yaml` publishes via interpolation — `127.0.0.1:${PLEXUS_APP_PORT}:<container-port>`.
- The app MUST NOT define `PLEXUS_*` keys of its own; the prefix is reserved for platform-injected bindings.

### § 5.5 Healthcheck

- The app MUST expose `GET /healthz` with readiness semantics: it MUST return 200 if and only if the process can serve real requests right now.
- The probe MUST include hard dependencies the app cannot serve without (its own database, with a short bounded timeout) and MUST NOT include soft or third-party dependencies the app survives degraded.
- The endpoint MUST be cheap, side-effect-free, and unauthenticated.
- The response SHOULD carry nothing beyond its status code: no version strings, no dependency names, no timings.

### § 5.6 Logs

- The app MUST write logs to stdout/stderr and MUST NOT manage its own log files.

### § 5.7 CI reference

- The app's CI MUST run the shared pipeline (§ 8.5): check → test → build → package & push image.
- The app MUST provide a runtime-only Dockerfile: it packages the `build` verb's output into the runtime image and MUST NOT rebuild the app.

## § 6 The app contract profiles

### § 6.1 The stateless app

- `compose.yaml` MUST declare only stateless services — no data services, no `plexus.backup` labels, and no `migrate` service.
- A `seed` task MAY be omitted.
- The env schema MAY declare zero secrets.

### § 6.2 The stateful app

- Data services MUST carry the labels `plexus.tenant=<slug>` and `plexus.backup=<type>`; a `plexus.backup` value is valid exactly when `itops` ships a backup handler for it (§ 7.3).
- The app SHOULD default to one database container of its own — full isolation, dies with the app.
- `compose.yaml` MUST declare a one-shot `migrate` service: the app's own image, its migration command, and `profiles: ["migrate"]` so a plain `up` never starts it.
- `migrate` MUST be idempotent: already-applied steps are skipped, and running it against a fully-migrated schema is a no-op.
- A `migrate` failure partway through MUST leave the schema in a state from which re-running `migrate` can complete, each step applied atomically where the database supports it.
- Concurrent `migrate` invocations MUST NOT corrupt the schema; `migrate` SHOULD serialize itself via a lock.
- Every migration MUST be backward-compatible with the release currently in production — expand/contract discipline, roll-forward only.
- A genuinely breaking migration — one that cannot honor expand/contract — MUST be deployed as a deliberate act: fresh backup taken first, and the operator aware that reverting means restoring, not re-upping the previous tag.
- The app MUST provide a `seed` task, loading development sample data only; it MAY assume a fresh database (right after `migrate`) and MUST NOT be invoked by the deploy verb.

## § 7 The operations platform

### § 7.1 Ingress

- Each app's host port MUST be assigned in the tenant's inventory (`apps[].port`), in the same record that binds its domain.
- The reverse proxy SHOULD be Caddy.
- The playbook SHOULD fail on a duplicate host port per VM.
- The proxy SHOULD refuse external requests for `/healthz`.

### § 7.2 Secrets

- Secret values MUST live only in the tenant's vault; git holds only references.
- The vault SHOULD be 1Password.
- Secrets MUST be resolved at provisioning time, never at deploy time.
- `secrets.env` on the host MUST be owned by the deploy user, mode 0600, never world-readable.
- The playbook MUST re-create the affected containers whenever `secrets.env` changed; rotation MUST NOT be left to ride along on whenever the next deploy happens to run.
- The compose-up invocation MUST be encoded exactly once, as an `itops` verb that both the deploy verb's up step and the rotation handler call.

### § 7.3 Backups

- Backup schedule and retention MUST live as code in the tenant's `infra/`.
- The backup job MUST discover what to dump by reading the `plexus.backup` labels (§ 6.2).
- A new backup path MUST pass one end-to-end restore before it is relied upon, and MUST be re-verified after any material change to the path.
- A scheduled restore test SHOULD run at least monthly: restore the latest snapshot of each labelled data service into a scratch container, run a sanity check, and ping its own dead-man's-switch check (§ 7.4), separate from the backup job's.

### § 7.4 Scheduling & the dead-man's-switch

- A workflow orchestrator MUST NOT be stood up as platform infrastructure.
- Every scheduled job MUST ping a per-job check on success, and a missed ping MUST raise an alert.
- A tenant that finds itself with an orchestrator that barely runs anything SHOULD migrate its jobs onto the mechanisms below or retire it.

### § 7.5 Host lifecycle (interim)

- Tenant hosts SHOULD run the distribution's unattended security upgrades (the base role's default).

## § 8 Releases & deployment

### § 8.1 Environment branches

- Tenant monorepos MUST use environment branches: `main`→prod, `develop`→staging.
- Apps MUST NOT use changesets.
- A hotfix branches from `main` and merges to `main`; it MUST be back-merged `main → develop` immediately.
- Staging and prod MAY share a VM or take one each — both sit inside one tenant's trust domain; § 3.5 partitions tenants, not environments.

### § 8.2 The release train

- CI MUST be path-scoped per app: an app's own directory plus every workspace package it depends on.
- `develop` MUST stay promotable; unfinished or still-soaking work lives on feature branches, never parked on `develop`.
- Selective promotion — cherry-picks, path-restricted merges — MUST NOT be used.

### § 8.3 Failed deploys & recovery

- While a staging deploy is red, `develop → main` MUST NOT be merged.

### § 8.5 The CI pipeline

- A tenant MUST NOT operate its own CI control plane.
- The forge SHOULD be GitHub; a tenant SHOULD NOT self-host a forge.

## § 9 Propagation

- A consumer config SHOULD extend the shared `@plexus-ms/*` config and keep local additions in its own file.

### § 9.1 The update bot

- Every tenant repo MUST run an automated update bot that watches its pins and opens update PRs.
- The update bot SHOULD be Renovate, extending the shared preset (`plexus-ms/renovate-config`).
- Tenants MUST pin the `plexus.itops` collection by tag in `infra/requirements.yml`.
- For `@plexus-ms/*` packages, CI-green patch/minor auto-merge MAY be enabled and is the recommended default.
- For CI-workflow and verb tag bumps, auto-merge MAY be enabled; a tenant whose CI holds sensitive credentials SHOULD review these PRs instead.
- Update PRs for the `plexus.itops` Ansible collection SHOULD NOT be auto-merged; a human reads the diff before anything new runs as root.

### § 9.2 Dependency mechanics

- A shared thing that crosses a tenant boundary MUST be consumed as a published, versioned package; a shared thing inside one tenant is a workspace dependency.
