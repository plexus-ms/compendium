---
title: PLX-Delivery – from a verified commit to a running or published artifact
short_title: PLX-Delivery
description: The three delivery verbs verify, release and deploy; the workflows that mount them on the forge; environment branches and promotion; how an image and a package are released; what the deploy verb does; and what happens when a deploy is red.
code: PLX-Delivery
maturity: standard
binds: repo
changed: 0.64.0
depends: [PLX-Repo]
consumes: [PLX-App, PLX-Host]
order: 17
---

A CI/CD system needs state (what exists), events (something changed), and procedures (make it so).
Plexus puts state in git, takes events from a forge someone else operates, and runs only stateless procedures.
This module is everything between a verified commit and a running container or a published package: three verbs, the workflows that mount them, the branch model that decides what runs where, and the recovery when a deploy fails.

It binds a repo.
Which sections bind which kind of repo is said at each section: an app repo releases images and deploys them, a package repo releases packages, the platform repo deploys third-party apps and releases nothing.
The app's side of being deployed, the compose file, the readiness endpoint, the Dockerfile, is [PLX-App](../contracts/app.md); the host's side is [PLX-Host](../contracts/host.md).


## § 1 The three verbs

> - Every repo MUST answer `verify`: perform every automated step that ascertains code quality (§ 3 PLX-Repo).
> - A repo that publishes an artifact MUST do so through `release`: from verified code, create and publish a versioned artifact to a registry.
> - A repo that runs an artifact MUST do so through `deploy`: launch a released artifact into an execution environment.
> - `release` and `deploy` MUST act only on code that `verify` has passed in the same workflow run; neither verb re-verifies.
> - Whatever operates on a repo without having written it MUST reach it only through these verbs; the incantations behind them are the repo's own.

Every repo answers the first verb; the other two are answered by the repos that produce and run artifacts.
Together they form a chain with one direction: `build` ([§ 3 PLX-Repo](../contracts/repo.md)) makes the artifact on the author's machine, `release` makes it once more hermetically and publishes it under a version, `deploy` launches a version that exists.
`deploy` never builds: the platform repo deploys images it never built, a rollback re-launches an image that was released long ago, and a re-run deploys the same artifact again.

The verbs are of two kinds, and the difference is where they run.
`verify` is a contract verb: a root mise task of the repo, with whatever decomposition the repo's toolchain gives it (`lint`, `check`, `test`, § 3 PLX-Repo).
`release` and `deploy` are ops verbs: they run outside the repo, on the forge, and are the same for every repo of their kind.
The deploy verb is one bash script in `plexus-ms/ci-cd`; the release verb is two arrangements of forge steps, one for an image (§ 4) and one for a package (§ 5), and both are hand-runnable from a checkout.

The guarantee "from verified code" is the pipeline's, not the verb's.
A `release` job runs after a `verify` job it depends on, in the same run, for the same commit; hand-run, `release` publishes what it is pointed at.


## § 2 Workflows and the pipeline

> - A tenant MUST NOT operate its own CI control plane.
> - The forge SHOULD be GitHub; a tenant SHOULD NOT self-host a forge.
> - Every repo MUST carry `.github/workflows/verify.yml`, triggered on every push, with one job `verify` that answers the verb repo-wide.
> - A repo that deploys MUST carry `deploy.yml`, and a repo that releases packages MUST carry `release.yml`, each triggered by pushes to the branches that name its environments and each verifying first within the same run.
> - A job MUST be named after the verb it mounts; a workflow is named after the occasion it mounts the verbs on.
> - Reusable workflows live in `plexus-ms/ci-cd`, named with a leading underscore; a tenant repo SHOULD carry only the generated workflows and MUST NOT carry logic in workflow YAML.
> - A tenant repo's workflows reference the reusable ones by the train tag.

A job is a verb; a workflow is a mount: the trigger that runs the verbs on an occasion.
Three verbs therefore do not need three files.
`verify.yml` runs on every push and answers the question "is the repo sound" for every commit, whatever branch it lands on.
`deploy.yml` runs on pushes to an environment branch and answers "may this ship", per app: verify the app, release its image, deploy it.
`release.yml` does the same for a package repo on its trunk: verify, release.
On an environment branch both files run, and the two verifies are not the same thing: one is repo-wide, the other is scoped to one app and is the gate for that app alone.

The per-app chain is `_pipeline.yml`, a reusable workflow with the jobs `verify`, `release` and `deploy` for one app, which the tenant's `deploy.yml` fans out over the changed set.
It exists because the forge's job graph is static and `needs` connects jobs, never the legs of a matrix: a job after a matrixed job waits for every leg and sees only one leg's outputs.
So the three verbs of one app have to live in one unit, and the only unit the forge can nest inside a matrix leg is a reusable workflow.
The same shape keeps a broken app from holding back a sound one on a push to `develop`: each leg fails on its own.

Every mount is thin: checkout, secrets plumbing, one invocation of a verb.
`_changed-apps.yml` mounts the `changed-apps` verb and emits the matrix; `_deploy-targets.yml` mounts `deploy-targets`; `_verify.yml` runs the contract verb; `_release-image.yml` and `_release-package.yml` are the two shapes of `release`; `_deploy.yml` mounts the deploy verb.
The tenant's own workflows are generated by the preset and shipped on the train; a tenant repo carries no reusable workflow of its own, and the underscore says at a glance which files are triggered and which are called.
Where the jobs run is the tenant's choice, made in repo variables: a label selects GitHub's runners or a runner of the tenant's own, and a second variable says whether that runner keeps its disk between jobs, so caches stay local instead of round-tripping through the forge.

GitHub Actions *is* a control plane, but one someone else operates, with git as input; that is the allowed shape.
The forge is tier-0 for deploys either way: CI is the deploy trigger and GHCR holds the images, so a forge outage means no automated deploys.
What bounds the damage is the usual pair: running systems keep running and git is distributed, so an outage costs deploy availability, never data; and the verbs stay hand-runnable, so a forge-less deploy remains possible, just not convenient.
Not-self-hosting avoids *operating* tier-0, not *depending* on it; code and CI configs are not personal data, and a self-hosted forge would be a tier-0 dependency the tenant has to secure and back up before it protects anything.
Leaving GitHub means adjusting the mounts, never the logic: a tenant on another forge rewrites a few YAML files and keeps every verb.


## § 3 Environment branches and promotion

> - App repos MUST use environment branches: `main`→prod, `develop`→staging.
> - The platform repo SHOULD have a single `main`; environments are inventory groups, never branches.
> - Apps MUST NOT use changesets.
> - A hotfix branches from `main` and merges to `main`; it MUST be back-merged `main → develop` immediately.
> - Promotion MUST be a fast-forward of `main` to `develop`; `main` MUST NOT carry merge commits of its own.
> - The pipeline MUST be path-scoped per app: an app's own directory plus every workspace package it depends on.
> - `develop` MUST stay promotable; unfinished or still-soaking work lives on feature branches, never parked on `develop`.
> - Selective promotion (cherry-picks, path-restricted merges) MUST NOT be used.
> - A tenant SHOULD start with a single web monorepo (one repo holding `apps/` and `packages/` for one web ecosystem) and add a further app repo only for a product that persistently needs a release cycle of its own.
> - Staging and prod MAY share a VM or take one each; both sit inside one tenant's trust domain, and [PLX-Tenancy](../contracts/tenancy.md) partitions tenants, not environments.

This section binds app repos.
An app release has no version number to reconcile: a release is an image keyed by git SHA, and the deploy that follows is keyed by the same SHA.
Branches map to deploy targets; "promote staging to prod" is fast-forwarding `main` to `develop` (`git push origin origin/develop:main`, the `promote` task the preset ships), never a merge commit.
A merge commit on `main` is a commit `develop` does not know, so the next promotion has to merge again, and `main` becomes a chain of promotion merges that says nothing; a fast-forward keeps `main` a pointer into `develop`'s history, and git refuses the push when it would be anything else.
The hotfix back-merge is what keeps the fast-forward possible: after it, `main` is an ancestor of `develop` again.
Release tooling built for registries (changesets) has nothing to version in an app repo, which is why it is excluded outright; packages version by different physics (§ 5), and the two models are never mixed.

Which host an environment *is*, is inventory, not convention: `main`→prod and `develop`→staging name deploy targets, and the binding, which VM, which inventory record, which domain, lives in the platform repo's inventory ([§ 3 PLX-Platform](platform.md)), where the deploy mount reads it.
The platform repo itself needs no environment branches because it has no release cycle of its own to promote: staging and prod are two inventory groups in one file, and a playbook run targets one of them.

The model: **the unit of deployment is the app; the unit of promotion is the repo.**
A merge to an environment branch releases into that environment exactly the apps whose sources changed in the merge: a docs-only merge deploys nothing, a `packages/ui` change redeploys its dependents, unchanged apps are neither rebuilt nor redeployed.
The changed set is derived from the push event's `before..after` diff, one definition that covers merge commits, squash merges, and multi-commit direct pushes identically; stateless, no bookkeeping.
A promotion carries every commit since the last one, so the changed set on `main` is the union of everything promoted, not the last commit alone.
Path-scoping is itself a mounted verb, not YAML logic: `changed-apps` reads git and the workspace graph and prints the apps whose sources changed, dependents included.

Promotion is the whole repo: `develop → main` asserts *everything on `develop` is prod-ready*, and selective promotion would put on prod a repo state that never existed on staging, destroying the one guarantee environment branches exist to give.

Two boundaries of the model.
The platform repo has no release cycle: its ops side is not an app and the deploy verb never touches it; applying it is a playbook run, its own mount, on its own occasions.
Third-party apps hosted in the platform repo are the exception that proves it: they *are* apps, so the deploy verb does touch them, mounted on the platform repo's `main` and fanned out by the same `changed-apps` verb over its `apps/`, which without a workspace graph reduces to a plain path diff.
And the escape valve is a repo split, not a process patch: if two products in one tenant *persistently* need independent release cadences, move one into its own repo (still inside the tenant's org and access boundary, still on the same contract).
Granularity problems are solved by moving a product into a release cycle of its own, never by making promotion partial.


## § 4 Releasing an image

> - An app's image MUST be built hermetically from its Dockerfile and pushed to the tenant's registry tagged with the git SHA it was built from.
> - The image MUST be pushed under the tenant's own organisation, with the repo's own forge token, never with a token that crosses an organisation.

This section binds app repos.
`release` for an app is one image per changed app: build from the Dockerfile the app contract asks for ([§ 7 PLX-App](../contracts/app.md)), push to GHCR under the tenant's organisation, tagged with the SHA.
The build is hermetic: it runs inside the Dockerfile, so the artifact is correct from any host, and what *build* means is encoded once, in the repo's task graph, which the Dockerfile invokes exactly as the `build` verb does.
The image reference is the release's one output, and the deploy job of the same pipeline leg takes it as its input.

Caching is the one place the mount knows about the machine it runs on.
A GitHub-hosted runner is destroyed after the job, so the layer cache has to be exported to the forge's cache service and imported again, through a builder container that can do so.
A runner that keeps its disk needs neither: the daemon's own build cache survives between jobs, and shipping it to the forge and back was the slowest part of the job.
The mount takes the difference as one input and the tenant sets it once, in a repo variable.

SHA-tagged images accumulate in the registry unboundedly, which rollback and re-deploys rely on; retention is untouched (§ 6.7 PLX).
Publishing for one platform (amd64) is the default; multi-arch is a deferred decision with a trigger, stated in the app contract.


## § 5 Releasing a package

This section binds package repos.
Packages release into a registry keyed by semver, and that different physics wants a different branch model from the apps': a package repo is trunk-based on a single `main`, versioned and published by **changesets**.
Why trunk-based: changesets accumulates changeset files on one branch, bumps them in one PR on that branch, and publishes from it.
A second long-lived branch forces reconciling version numbers between branches on every release, a perpetual back-merge tax; changesets is a trunk-based tool, and pairing it with environment branches fights it.
Concurrency is not a reason to avoid this: changeset files have random names and the bump is deferred to one central step, so simultaneous feature branches never conflict and never double-publish.

How a release runs:

- **Two phases.** Changesets accumulate on `main`; `changesets/action` opens a "version packages" PR that bumps versions and writes changelogs; merging it publishes.
  The only manual step is recording a changeset with each publishable change; versioning and publishing run in CI, never locally.
  `verify.yml` runs the contract verb plus a `changeset status` guard that fails when a publishable change ships without a changeset; an empty changeset records a no-release change.
- **Token-less via OIDC.** Publishing authenticates through GitHub OIDC *trusted publishing* (`id-token: write`), not a stored npm token, which also makes provenance automatic.
  *Bootstrap caveat:* a package cannot be registered as a trusted publisher until it exists, so each package's **first** publish is a one-time manual `npm publish`, token-authenticated and therefore *without* provenance; the attestation chain starts at the second release, and CI takes over after.
- **Tags and GitHub Releases are automatic:** `changeset publish` tags each `@plexus-ms/<pkg>@x.y.z`, the action pushes them and cuts a Release from the changelog.
  The release branch (`main`) is protected by a ruleset requiring the verify check; keep it that way, since this is what stands behind the upstream guarantees (§ 1.6 PLX).

A `@plexus-ms/*` package is tenant-neutral methodology, never substance; this is the standard's guardrail and it binds every publish.
A tenant publishing packages of its own to a private registry ([§ 1 PLX-Updates](updates.md)) takes the same shape.
Code utilities start in `@plexus-ms/std`, the standard *library* ("the standard" alone always names PLX itself, never this package), the default home for any small shared concern, and a concern graduates to its own package once it has its own audience or its own release cadence: a consumer should not take updates because an unrelated helper changed.
Tool configs are the one deliberate exception to per-concern packages: they bundle into `@plexus-ms/config` as subpath exports (`@plexus-ms/config/biome`, `/tsconfig`, …), each still a one-line `extends` target, but sharing one package because they share one audience and one release cadence (and each separate package costs a manual bootstrap publish).
A config splits out only if it ever grows its own cadence.
Packages follow semver, enforced by changesets: a breaking change is a major bump, and its changeset carries a migration note so the changelog doubles as the upgrade guide.

Application plumbing, the "standardize boundaries" edges (framework glue, common auth concerns, repeatable non-domain features), is extracted into a package when a second app needs the same plumbing, never speculatively from the first; until then it lives in the app that needs it (§ 4.6 PLX).


## § 6 Deploy semantics

This section binds every repo that deploys: app repos through their pipeline, the platform repo for the third-party apps under its `apps/`.
It describes what the shared deploy verb (`plexus-ms/ci-cd`, `scripts/deploy.sh`) does, so the contract requirements riding on it ([§ 5 PLX-App](../contracts/app.md), [§ 2 PLX-AppStateful](../contracts/app-stateful.md)) make sense.
The verb's behaviour is documented here rather than required; the contracts it serves are what carry requirements.

```
deploy(host, tenant, app, image_ref):
  render compose.yaml from the invoking checkout, pinning image_ref
  → ssh → stage the rendered file next to the one currently serving
        → docker compose pull                # against the staged file
        → docker compose run --rm migrate   # only if the file declares it;
                                            # same image, idempotent, roll-forward-only
        → swap the staged file into place, keeping the previous one
        → docker compose up -d
        → poll /healthz
        → on failure: restore the previous file, docker compose up -d, alert
```

A failure anywhere before the swap, a pull or a migrate, leaves the host exactly as it was, so the previous release keeps serving from its own compose file; the failing job is the alert.

The verb reads everything from git (the compose file) and from the host (`docker ps` is runtime truth) and stores nothing.
"Which version is live" is the running container's image, queryable from reality, and equally the image pinned in the compose file the host serves from.
Rollback needs no memory across runs: the verb keeps the previous compose file until the run ends, and the image it pins is still in the host's cache.
The rollback path never pulls: it has to work while the registry is down or a tag has been pruned, so it re-launches the cached image under the compose file it was serving from.

The healthcheck poll is deadline-based, not one-shot: the verb retries `/healthz` until it answers 200 or a deadline expires (reference: ~60 s).
A transient blip inside the window is absorbed; only sustained not-ready fails the deploy.
Because `/healthz` carries readiness semantics including hard dependencies, a down database fails the deploy, correctly, since the new code cannot serve, and the ensuing rollback is harmless by idempotence.
The verb never needs to diagnose *why* readiness failed; it only ever acts on *whether*.

The alert is deliberately minimal: hand-run, it is the verb's nonzero exit and its stderr; mounted in CI, the failing job *is* the alert, surfaced however the forge notifies.
A richer channel is an observability concern (§ 12.4 PLX).

Rollback's limit: it re-ups the previous image; it never reverses a migration.
By the time the healthcheck fails, `migrate` has already run, and the old code comes back up against the new schema.
That is sound only because the stateful profile makes it sound: every migration is backward-compatible with the release currently in production.
For the rare deploy that deliberately breaks that discipline, reverting is a restore from backup, not a re-up.

Two more edges, named rather than implied.
A *first* deploy has no previous compose file: if the poll fails, the verb simply fails loudly; nothing was serving before, so nothing is lost, and bringing a new app up is the operator's supervised act.
And `compose up -d` re-creates containers in place, so every deploy buys its simplicity with a few seconds of downtime, the accepted trade at this scale; zero-downtime choreography is a deferred decision with a trigger (§ 6.9 PLX), not an ambient expectation.

The verb renders the app's `compose.yaml` from the invoking checkout onto the host, pinning the image ref in place of `${PLEXUS_DEPLOYMENT_IMAGE}`.
That is inside the fence: the file is read from git, the ref is the verb's own argument, and nothing is stored anywhere else.

The verb has one name and three callers.
An app repo's pipeline runs it per changed app after the image is released (§ 4).
The platform repo's `deploy.yml` runs it for the third-party apps under its `apps/`, from `main`, with the image already pinned in the committed file, each app's target looked up in the inventory by the `deploy-targets` verb.
Hand-run, it is `./scripts/deploy.sh deploy@host tenant app image` from any checkout that has the compose file, which is what makes a forge-less deploy possible.
The deploy host is substance: a repo variable, or the inventory record's `plexus_deploy_target` where the platform repo has one, reachable over the tenant's overlay network or a public forward, whichever the tenant's platform provides.


## § 7 Failed deploys and recovery

> - While a staging deploy is red, `develop → main` MUST NOT be merged.
> - Recovery MUST be a re-run of the failed job or a hand-run deploy of the same artifact, never an empty commit.

A failed deploy parks promotion, and recovery is named, not improvised.
The changed set carries no memory, so the pipeline never *rediscovers* a failed deploy: after the rollback and alert (§ 6), the environment branch is ahead of what actually runs, and the next unrelated merge will not close the gap.
Closing it is the operator's move, using mechanisms that already exist: re-run the failed job (same SHA, same artifact) once the cause is fixed, or invoke the hand-runnable deploy verb directly.
A red staging deploy directly falsifies `develop`'s prod-readiness, hence the promotion freeze.


## Maintaining

The module folds what were four pages, PLX-CI, PLX-Release, PLX-Deploy and PLX-Packages, into one, because a reader of any of them needed the other three; the section numbers of the old pages are retired with their codes, and a citation of one of them is rewritten to the section here that carries the same content.

`plexus-ms/ci-cd` ships the ops verbs and the reusable workflows and tags them together, so a workflow always checks out its verb at the same tag.
The layering is load-bearing:

- **Verbs** are portable bash scripts in `scripts/` that contain *all* the logic and stay hand-runnable: `git clone && ./scripts/deploy.sh deploy@host tenant app image` works with no forge at all.
  This is what passes the degradation test.
  `changed-apps.sh <from-sha> [<to-sha>]` prints the apps whose sources changed since a ref, dependents included, reading only git and the workspace graph; it is the one encoding of the changed set, and the definition in § 3 and the verb change together.
  `deploy-targets.sh` prints each app's deploy target from a platform repo's inventory.
  Bash's native failure modes (unset variables expanding to nothing, pipelines failing silently) are second-reader traps, so a safety baseline applies to every verb: strict mode (`set -euo pipefail` or equivalent) and shellcheck-clean, enforced mechanically at the repo boundary by `mise :verify`, never the honor system.
  A verb's remote half is a quoted heredoc that ssh feeds to `bash`; the check runs shellcheck over that too, and the heredoc can be extracted and run against a scratch directory with fake `docker` and `curl` scripts on `PATH` to exercise failure and rollback paths offline.
- **Reusable workflows** are thin mounts of one verb each, with the job key equal to the verb, plus `_pipeline.yml` as the one composition.
  Logic never lives in the YAML.
  GitHub's workflow format is not an open standard and the runner is self-hostable but GitHub remains the scheduler, so a workflow is forge-specific and disposable, while a verb is portable and permanent.
- **Tenant workflows** are generated by the presets, `verify.yml` and `deploy.yml` by the web preset, `verify.yml` and `deploy.yml` by the platform preset, `verify.yml` and `release.yml` for a package repo, and reference the reusable workflows by the train tag, so the update bot ([PLX-Updates](updates.md)) carries each train to every tenant as a reviewed PR.
  A file the preset stops generating is removed by hand on that train; copier does not delete.

**The deploy verb has a fence**, and crossing it takes a deliberate, documented decision: no persistent state, no daemon, no UI, no reconciliation loop, no provisioning of platform resources at deploy time.
Inside the fence, invest freely: logging, clean rollback, good error messages.
Outside it, it is either an existing tool's job or an architecture change, not feature creep.
Zero-downtime deploys (blue-green, rolling) stay outside until an app has traffic for which a blink is a real cost; whatever the answer, it stays a verb, not a reconciler.

A web repo's deploy target is one `DEPLOY_HOST` variable for all its apps, while the platform repo looks each app's target up in its inventory (§ 3 PLX-Platform).
Publishing the inventory's targets into the app repos as a variable was designed and deliberately not built; the trigger that reopens it is a tenant whose runners sit on its overlay network, where the target stops being a public forward and could stop being a forge variable altogether.

Preview environments per PR are deliberately absent: a single staging per app covers most of the value, and the decision is revisited when a product has real customers (§ 6.8 PLX).

`plexus-ms/packages` rides outside the train (§ 1.5 PLX): npm semver via changesets is its versioning, and the train number says nothing about it.
It hand-maintains the monorepo arrangement the presets ship to tenants; a library-monorepo template is extracted when a second package monorepo appears, never speculatively from the first.
§§ 5 and 6 carry no requirements yet: one package repo and one deploy verb are their consumers, and they gain requirements when a second consumer of each exists.
