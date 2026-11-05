---
title: PLX-Delivery – from a verified commit to a running or published artifact
short_title: PLX-Delivery
description: The three delivery verbs verify, release and deploy; the workflows that mount them on the forge; environment branches and promotion; how an image and a package are released; what the deploy verb does; and what happens when a deploy is red.
code: PLX-Delivery
maturity: standard
binds: repo
changed: 0.103.0
depends: [PLX-Repo]
consumes: [PLX-App, PLX-Host, PLX-Environment]
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
> - `release` MUST act only on code that `verify` has passed in the same workflow run, and `deploy` MUST launch only an artifact so released; neither verb re-verifies.
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
Because nothing reaches the registry without that order, the registry is the record of what was verified: an artifact that exists for a commit was verified and released for it, and a later run that finds it deploys it without verifying or building the same commit again.


## § 2 Workflows and the pipeline

> - A tenant MUST NOT operate its own CI control plane.
> - The forge SHOULD be GitHub; a tenant SHOULD NOT self-host a forge.
> - Every repo MUST run a job `verify` that answers the verb repo-wide on every pull request, and on every push to a trunk that takes direct pushes and verifies nothing per app.
> - A push to a branch that is neither the trunk nor an environment branch MUST NOT start a run; a change to nothing but Markdown SHOULD NOT start one.
> - An app repo MUST carry `.github/workflows/pipeline.yml`, which mounts the verbs on pull requests and on pushes to its environment branches; a package repo MUST carry `verify.yml` and `release.yml`, and the platform repo `verify.yml` and `deploy.yml`.
> - A newer run for the same ref MUST cancel a `verify` still going for an older commit, and MUST NOT cancel a `release` or `deploy` once started.
> - A job MUST be named after the verb it mounts; a workflow is named after the occasion it mounts the verbs on.
> - Reusable workflows live in `plexus-ms/ci-cd`, named with a leading underscore; a tenant repo SHOULD carry only the generated workflows and MUST NOT carry logic in workflow YAML.
> - A tenant repo's workflows reference the reusable ones by the train tag.

A job is a verb; a workflow is a mount: the trigger that runs the verbs on an occasion.
Three verbs therefore do not need three files.
Two questions are asked of a repo, on two occasions.
"Is the repo sound" is asked of a pull request, answered by one repo-wide `verify` and tested as the merge result rather than the branch tip.
"May this ship" is asked of a push to an environment branch, answered per app: verify the app, release its image, deploy it.
The two verifies are not the same thing: one is repo-wide, the other is scoped to one app and is the gate for that app alone.
An app repo asks both in one workflow, `pipeline.yml`, whose jobs are selected by the event: `verify` on a pull request, the per-app chain on a push to `develop` or `main`.
A package repo asks the first in `verify.yml` on pull requests, since its `main` admits nothing but pull requests, and the second in `release.yml` on its trunk: verify, release; a push trigger would in any case never fire for the "version packages" PR, whose branch the release job pushes with the workflow token, and pushes made with that token start no workflow.
The platform repo's `main` takes an operator's direct pushes, so its `verify.yml` runs on those as well as on pull requests, and its `deploy.yml` deploys the third-party apps from `main` (§ 3).

Runs that answer nobody are not started.
A push to a feature branch is verified once it has a pull request, and every later push to it is verified as the pull request's merge result; a pushed branch nobody has opened a pull request for runs nothing.
A change to nothing but Markdown starts nothing, and the next run that does start diffs past it, so its changed set loses nothing.
A newer push to the same ref cancels the `verify` still going for the older commit, whose verdict nobody waits for any more; on an environment branch that is the per-app `verify`, so a burst of merges collapses to the newest commit for each app, and the cancelled runs' releases and deploys, which had not started, never do.
The cancellation sits on the `verify` job and never on the workflow: a `release` or `deploy` already started runs to its end, since a deploy cut off between migrate and up would strand the host, and deploys of one app to one host keep their own queue, at most one running and the newest waiting.
A commit whose image is already in the registry is neither verified nor built again (§ 1): a fast-forward promotion of `main` to a `develop` tip that was built there deploys that image, and a run started by hand on an environment branch redeploys every app from the images it finds.

The per-app chain is `_pipeline.yml`, a reusable workflow with the jobs `verify`, `release` and `deploy` for one app, which the tenant's `pipeline.yml` fans out over the changed set.
It exists because the forge's job graph is static and `needs` connects jobs, never the legs of a matrix: a job after a matrixed job waits for every leg and sees only one leg's outputs.
So the three verbs of one app have to live in one unit, and the only unit the forge can nest inside a matrix leg is a reusable workflow.
The same shape keeps a broken app from holding back a sound one on a push to `develop`: each leg fails on its own.
Under the cloud strategy (§ 8) the unit is the whole run instead: `_pipeline-cloud.yml` plans once for every app, from content hashes rather than a diff, and fans build, test, release and deploy out as matrices of its own, which the forge allows inside one reusable workflow; the tenant's `pipeline.yml` is then one job calling it.
The preset asks which shape a repo takes (`ci_strategy`, `forge` or `cloud`) and generates the matching `pipeline.yml`; both answer the two questions above on the same two occasions.

Every mount is thin: checkout, secrets plumbing, one invocation of a verb.
`_changed-apps.yml` mounts `plx changed-apps` and emits the matrix; `_deploy-targets.yml` mounts `plx deploy-targets`; `_verify.yml` runs the contract verb; `_release-image.yml` and `_release-package.yml` are the two shapes of `release`; `_deploy.yml` mounts the deploy verb.
The tenant's own workflows are generated by the preset and shipped on the train; a tenant repo carries no reusable workflow of its own, and the underscore says at a glance which files are triggered and which are called.
Where the jobs run is the tenant's choice, made in repo variables: a label selects GitHub's runners or a runner of the tenant's own, and a second variable says whether that runner keeps its disk between jobs, so caches stay local instead of round-tripping through the forge.

GitHub Actions *is* a control plane, but one someone else operates, with git as input; that is the allowed shape.
The forge is tier-0 for deploys either way: CI is the deploy trigger and GHCR holds the images, so a forge outage means no automated deploys.
What bounds the damage is the usual pair: running systems keep running and git is distributed, so an outage costs deploy availability, never data; and the verbs stay hand-runnable, so a forge-less deploy remains possible, just not convenient.
Not-self-hosting avoids *operating* tier-0, not *depending* on it; code and CI configs are not personal data, and a self-hosted forge would be a tier-0 dependency the tenant has to secure and back up before it protects anything.
Leaving GitHub means adjusting the mounts, never the logic: a tenant on another forge rewrites a few YAML files and keeps every verb.


## § 3 Environment branches and promotion

> - App repos MUST use environment branches: `main`→`production`, `develop`→`staging`; `production` and `staging` are the environment names a deploy asks the platform inventory for ([PLX-Environment](../contracts/environment.md)).
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

Which host an environment *is*, is inventory, not convention: `main`→`production` and `develop`→`staging` name environments, and the binding, which VM, which inventory record, which domain, lives in the platform repo's inventory ([§ 3 PLX-Platform](platform.md)), one record per app and environment, where the deploy mount reads it through `plx deploy-targets --environment` from a checkout of the tenant's platform repo ([PLX-Environment](../contracts/environment.md)).
An app without a record in an environment has no deployment there, and a push to that environment's branch releases its image and deploys nothing.
The platform repo itself needs no environment branches because it has no release cycle of its own to promote: staging and prod are two inventory groups in one file, and a playbook run targets one of them.

The model: **the unit of deployment is the app; the unit of promotion is the repo.**
A merge to an environment branch releases into that environment exactly the apps whose sources changed in the merge: a docs-only merge deploys nothing, a `packages/ui` change redeploys its dependents, unchanged apps are neither rebuilt nor redeployed.
The changed set is derived from the push event's `before..after` diff, one definition that covers merge commits, squash merges, and multi-commit direct pushes identically; stateless, no bookkeeping.
A promotion carries every commit since the last one, so the changed set on `main` is the union of everything promoted, not the last commit alone.
Promotion builds nothing that `develop` built: an app whose image exists for the promoted commit is deployed from it (§ 2), and only an app whose last change on `develop` lies behind the promoted tip is built again, under the tip's SHA.
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
The image reference is the release's one output, and the deploy job of the same pipeline leg takes it as its input; when the image already existed, the leg resolves the same reference without releasing.

Caching is the one place the mount knows about the machine it runs on.
A GitHub-hosted runner is destroyed after the job, so the layer cache has to be exported to the forge's cache service and imported again, through a builder container that can do so.
A runner that keeps its disk needs neither: the daemon's own build cache survives between jobs, and shipping it to the forge and back was the slowest part of the job.
The mount takes the difference as one input and the tenant sets it once, in a repo variable.

SHA-tagged images accumulate in the registry unboundedly, which rollback and re-deploys rely on; retention is untouched (§ 6.7 PLX).

Under the cloud strategy (§ 8) an image carries three tags: `build-<hash>`, Turbo's hash of the app's `build` task, which is also the build ID inside the image; `test-<hash>`, the hash of its `test` task, added to the manifest when the tests passed on it; and `<sha>`, which remains the reference a deploy takes.
The hashes are what the plan looks up, so a lockfile change or a force-push rebuilds nothing whose inputs did not change, and a change to specs alone re-runs the tests on the existing image.
The build is then reproducible as far as the stack allows: the context is `turbo prune --docker`, so an app's image is independent of the other apps' dependencies; the base image is pinned by digest; the build ID and the server-actions key are fixed from outside; timestamps are zeroed; what still drifts is measured and listed (Next's preview-mode keys, a package installed at build time), never gated.
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
  The update bot writes no changesets, so its branches are exempt from the guard and get their changeset from `plx changeset` instead, mounted on the bot's pull requests by `_changeset.yml`: a patch per package whose `dependencies`, `optionalDependencies` or a catalog entry they consume moved, a major when a `peerDependencies` range did, nothing for a devDependency, and a patch per package whose shipped source the branch changed (its `src/`, tests excluded), which on a bot branch only a pin moved by a regex manager does, committed to the bot's branch under an author the bot ignores ([§ 2 PLX-Updates](updates.md)).
  The rule is the ecosystem's, pnpm's `update --changeset` and Renovate's proposed `changesets` option apply the same one, and it holds because a package declares what it ships: nothing is bundled into a published artifact, so a release of a dependency releases its dependents through the declared graph.
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
It describes what the shared deploy verb (`plx deploy`, [PLX-CLI](cli.md)) does, so the contract requirements riding on it ([§ 5 PLX-App](../contracts/app.md), [§ 2 PLX-AppStateful](../contracts/app-stateful.md)) make sense.
The verb's behaviour is documented here rather than required; the contracts it serves are what carry requirements.

```
deploy(host, tenant, app, image_ref):
  render compose.yaml from the invoking checkout, pinning image_ref
  → ssh, one line of shell per step, printed verbatim by --dry-run
        → stage the rendered file next to the one currently serving
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
Hand-run, it is `plx deploy deploy@host tenant app --image <ref>` from any checkout that has the compose file, and `plx -n deploy …` prints every ssh line it would run, which is what makes a forge-less deploy possible, with or without the tool.
The deploy host is substance: a repo variable, or the inventory record's `plexus_deploy_target` where the platform repo has one, reachable over the tenant's overlay network or a public forward, whichever the tenant's platform provides.


## § 7 Failed deploys and recovery

> - While a staging deploy is red, `develop → main` MUST NOT be merged.
> - Recovery MUST be a re-run of the failed job or a hand-run deploy of the same artifact, never an empty commit.

A failed deploy parks promotion, and recovery is named, not improvised.
The changed set carries no memory, so the pipeline never *rediscovers* a failed deploy: after the rollback and alert (§ 6), the environment branch is ahead of what actually runs, and the next unrelated merge will not close the gap.
Closing it is the operator's move, using mechanisms that already exist: re-run the failed job (same SHA, same artifact) once the cause is fixed, or invoke the hand-runnable deploy verb directly.
A red staging deploy directly falsifies `develop`'s prod-readiness, hence the promotion freeze.


## § 8 Where the jobs run

This section binds every repo that mounts a verb on the forge.
By default the jobs run on the forge's own runners: a fresh machine per job, destroyed afterwards, nothing for the tenant to operate, minutes billed beyond the free allowance, and every cache round-tripping through the forge.
A tenant that wants faster or cheaper CI runs a runner of its own, and the choice is two repo variables: a label that selects the runner (`CI_RUNNER`), and whether it keeps its disk between jobs (`CI_RUNNER_PERSISTENT`), which the mounts take as the inputs `runner` and `persistent`.
Unsetting the label moves CI back to the forge's runners at once, without a playbook run, which is also the fallback while the tenant's runner host is down.

Turbo's remote cache is the one cache that crosses machines, and it is optional for either kind of runner.
The tenant names an S3 bucket of its own, in any S3-compatible store, in three repo variables (`TURBO_CACHE_ENDPOINT`, `TURBO_CACHE_REGION`, `TURBO_CACHE_BUCKET`) and grants read and write on it through two repo secrets (`TURBO_CACHE_ACCESS_KEY`, `TURBO_CACHE_SECRET_KEY`); every verify job then starts a cache server on loopback for its own length (`brunojppb/turbo-cache-server`, pinned by commit), with a token minted for the job.
A task whose inputs did not change is replayed from any earlier job on any runner, which on a merge mostly means that the environment branch's verify replays what the pull request's verify computed for the same tree.
The bucket is a cache and nothing else: it holds task outputs and logs, never a secret, nothing reads it but Turbo, and emptying it costs one slow run; a lifecycle rule on the bucket expires old objects, since nothing else prunes them.
Without the bucket variable Turbo keeps its local cache alone.

A runner of the tenant's own is a host of the tenant, set up like every other by the collection ([§ 2 PLX-Platform](platform.md)): the `github_runner` role installs the official runner as N instances, each a systemd service, registered at the tenant's forge organisation with a short-lived token minted from a vault secret at registration time and never stored.
Each instance has a home of its own, because jobs running at the same time must not share what a job writes in place there, a tool's binaries or a registry login; the caches built for concurrent writers, the pnpm store among them, are shared between all instances.
Jobs run directly on the host, with Docker for image builds, so one host serves one tenant and runs nothing else: a runner holds job secrets in flight, and the docker group is root on that machine.
Only the tenant's private repos use it, since a public repo lets a stranger's pull request run on it.
What a job expects of the forge's runners beyond its own toolchain is on the host as well: the system libraries Playwright's Chromium links against, while the browsers themselves are fetched by the jobs into a shared cache.
What jobs leave behind is bounded on both ends.
The release job removes the image it built once it is pushed, and a hook after every job prunes the anonymous volumes the runner leaves when it removes a job's service containers.
A nightly housekeeping timer removes stale working directories, every container older than a few hours (a job's containers live as long as the job), unused volumes and pulled images, and caps the build cache by size, since on a persistent runner that cache is the layer cache; it fails loudly, into the host's mail, when the disk fills regardless.

Three trade-offs are named rather than implied.
The runner persists between jobs, against "primitives should rarely remember anything": the caches are the speed gain, and the housekeeping bounds what jobs leave behind.
The runner binary updates itself, the one unpinned executable on a tenant host, because the forge stops scheduling onto a runner that falls far behind.
And where the runner host shares a hypervisor with production, CI is down whenever production is, and the fix that would rescue production cannot pass it; the deploy verb being hand-runnable and the fallback being one variable away is what makes that acceptable.

A runner inside the tenant's network reaches the app hosts by their overlay names, so the deploy target stops being a public forward; the overlay's policy has to allow the runner host to reach the app hosts on SSH.
A deploy job on the forge's runners reaches them the same way by joining the overlay itself for the length of the job, as an ephemeral peer with a setup key whose policy allows the app hosts' SSH and nothing else (`_deploy.yml`, `overlay: netbird`); the key sits in the CI vault, and the peer is gone when the job is.

The third place is throwaway cloud instances, the **cloud strategy**, chosen in the preset (`ci_strategy: cloud`) and mounted as one reusable workflow, `_pipeline-cloud.yml`, for the whole repo and run.
The forge's runners decide and copy, the instances build and test, and nothing runs while no pipeline runs: every instance is created for one job and deleted after it, and there is no persistent instance at all, not even for the registry.
Its jobs: `plan` computes every app's build and test hashes from one Turbo dry run, looks them up as image tags, and launches one builder per image to build and one test runner per test to run, all at once, hidden behind `check`; `check` is lint, typecheck and the pure tests, repo-wide, through the Turbo remote cache; `build` builds the image from the pruned context with `BUILD_HASH` and the app's fixed keys as BuildKit secrets (§ 4) and pushes it to the registry as `build-<hash>` and `<sha>`; `test` brings the app's own compose file up on the candidate with a CI override (`docker/compose.ci.yaml`: throwaway values in place of the two env files, the database published to the runner and kept in RAM), runs the app's `test` script against the stack, and marks the manifest `test-<hash>`; `release`, on an environment branch, copies the tested manifest to the tenant's forge registry under `<sha>`; `deploy-targets` reads each app's target in the environment from the platform repo's inventory ([PLX-Environment](../contracts/environment.md)) and `deploy` is `_deploy.yml` per app that has one; `teardown` deletes what the run launched, whatever the jobs ended in.
`check` and `test` are the decomposition § 3 PLX-Repo recommends, run as two jobs because they want different machines: the first none in particular, the second Docker and cores.
The registry is a sidecar, not a host: every job that needs it starts the CNCF distribution registry on loopback against a bucket of the tenant's object storage for its own length, as BuildKit's cache, the candidate store and the look-up index.
Retention is rotation: the bucket is named by month, writes go to the current month, reads consult the current and the previous, and the bucket of two months ago is deleted whole, at the cost of one cold build per app a month; the registry's own garbage collection needs no writers and is not used.
The instances tear themselves down in layers, the runner exiting, no job having started by a deadline, a death deadline that mails first, and the run's `teardown` job and a daily `sweep`, mounted in the platform repo (`_sweep.yml`), delete what the layers missed.
CI's own credentials live in a vault of their own, `<tenant>-ci` ([§ 3 PLX-Secrets](secrets.md)), read with one service account token, the one secret an app repo holds; the cloud's keys are three, one that launches and sweeps, one an instance deletes itself with from its user-data, one that reads and writes the buckets, each able to do nothing else.
What the strategy costs is a cloud account billed per second and the setup acts named under Maintaining; what it buys is a builder that never contends with another app's build, a test host with Docker and eight cores, a pull request verified against the image that would ship, and no runner host to operate.
The forge's runners remain the default, and a tenant on the forge strategy moves to the cloud one by answering the preset's question and holding the vault and the keys.


## Maintaining

The module folds what were four pages, PLX-CI, PLX-Release, PLX-Deploy and PLX-Packages, into one, because a reader of any of them needed the other three; the section numbers of the old pages are retired with their codes, and a citation of one of them is rewritten to the section here that carries the same content.

The ops verbs are commands of `plx` ([PLX-CLI](cli.md)) and the reusable workflows that mount them carry no logic of their own; both ship from `plexus-ms/primitives` on the train, the tool at the train number on npm, the workflows by the train tag, so that a tenant's CI runs one number.
The layering is load-bearing:

- **Verbs** contain *all* the logic and stay hand-runnable.
  `plx changed-apps <from> [to]` prints the apps whose sources changed since a ref, dependents included, reading only git and the workspace graph (pnpm answers for the graph); it is the one encoding of the changed set, and the definition in § 3 and the verb change together.
  `plx deploy-targets [inventory]` prints each app's deploy target per environment from a platform repo's inventory, flat for one environment with `--environment`, and refuses an app declared with a target in two files for the same environment.
  `plx deploy <host> <tenant> <app> [--image <ref>]` is § 6: every command it sends to the host is one line of shell over a shared ssh connection, and `--dry-run` prints each line verbatim, so `git clone && plx -n deploy …` hands a stranded operator the exact commands, which is what passes the degradation test.
  All three are tested in `plexus-ms/primitives`, the deploy verb against a fake `ssh` on `PATH` that runs each line locally in a scratch app dir with fake `docker` and `curl`, the offline harness of its bash days.
  A tenant repo pins the tool in its `mise.toml` at the train number, and the train writes that pin together with the workflow refs ([§ 1 PLX-Updates](updates.md)), so the verbs a workflow asks for are the ones the pinned tool has.
- **Reusable workflows** are thin mounts of one verb each, with the job key equal to the verb, plus two compositions, `_pipeline.yml` for the forge strategy and `_pipeline-cloud.yml` for the cloud strategy, and `_sweep.yml`, the cloud strategy's daily sweep; actionlint checks them under `mise :verify`.
  The cloud pipeline's steps are each one `plx-ci` or `plx` invocation; the CI verbs (`plan`, `launch`, `build`, `test`, `release`, `teardown`, `sweep`, `registry`, `inspect`, `probe`) are `@plexus-ms/cli-ci`, a package beside `plx` so that a strategy can change without moving every tenant's `plx` ([PLX-CLI](cli.md)).
  `_deploy.yml` takes its keys either from the caller's secrets or from the CI vault with the service account token, and joins the tenant's overlay on request; the deploy verb itself ends without pulling or restarting when the host already serves the image from the same run shape, healthy, so a promotion restarts only the apps whose image changed.
  `_changeset.yml` is the one mount that writes back to the caller: the changeset `plx changeset` owes, committed to the bot's branch, pushed with a token the caller passes so that its checks run on the new tip.
  Logic never lives in the YAML.
  GitHub's workflow format is not an open standard and the runner is self-hostable but GitHub remains the scheduler, so a workflow is forge-specific and disposable, while a verb is portable and permanent.
- **Tenant workflows** are generated by the presets, `pipeline.yml` by the web preset, `verify.yml` and `deploy.yml` by the platform preset, `verify.yml` and `release.yml` for a package repo (the web preset with `publishes_packages`), plus `update.yml` from both repo presets, the mount that pulls the train ([§ 3 PLX-Updates](updates.md)); all reference the reusable workflows by the train tag, which the train's own pull request moves in every tenant.
  A file the preset stops generating is deleted by the train's `copier update` where the repo left it unchanged, and removed by hand on that train where it did not.

**The deploy verb has a fence**, and crossing it takes a deliberate, documented decision: no persistent state, no daemon, no UI, no reconciliation loop, no provisioning of platform resources at deploy time.
Inside the fence, invest freely: logging, clean rollback, good error messages.
Outside it, it is either an existing tool's job or an architecture change, not feature creep.
Zero-downtime deploys (blue-green, rolling) stay outside until an app has traffic for which a blink is a real cost; whatever the answer, it stays a verb, not a reconciler.

A web repo's deploy target was one `DEPLOY_HOST` variable for all its apps while the platform repo looked each app's target up in its inventory (§ 3 PLX-Platform); publishing the inventory's targets into the app repos as a variable was designed and deliberately not built.
Decided 2026-11-04: the app repo's deploy job reads the inventory itself, from a checkout of the tenant's platform repo (`<owner>/platform`, fixed by PLX-Tenancy) made with the tenant's GitHub App, which therefore holds `Contents: read` on it; the record it reads is the contract object of [PLX-Environment](../contracts/environment.md), and the variable goes with the cut-over to the pipeline that reads it.

Two decisions of 2026-11-05, at the first tenant's cut-over to the cloud strategy, close the deferrals written before it:

- The module keeps its code and § 8 carries the strategies; a split into a PLX-CI with one page per strategy would rename citations for no second reader.
  The two strategies are the preset's question, and the forge's runners stay the default; a tenant moves between them by answering it.
- The environment branches stay `main` and `develop`: the hotfix flow, the promotion task and every page assume them, and the deploy mount maps a branch to an environment name in one place.
  A branch named for its environment is not pursued.

The cloud strategy's setup is a one-time act per tenant, done by hand and recorded here until a second tenant makes a role of it: on the cloud, three IAM roles and keys (launch and sweep: create, list, get, delete instances and read templates, types, security groups and operations; self-delete: list, get, delete instances and read operations; storage: read and write on the buckets), a security group without inbound rules, an SSH key registered once; two buckets, `<owner>-ci-turbo` with a lifecycle rule expiring objects after thirty days and `<owner>-ci-registry-<YYYY-MM>` for the current month, the next month's being the one recurring act; the GitHub App `<owner>-ci` with `Administration: write` on the app repo (for the runners' JIT configs) and `Contents: read` on the platform repo; a relay credential for the mails; and the vault `<owner>-ci` of § 3 PLX-Secrets holding all of it, with its service account token as the app repo's one secret and the platform repo's one secret for the sweep.

Preview environments per PR are deliberately absent: a single staging per app covers most of the value, and the decision is revisited when a product has real customers (§ 6.8 PLX).

`plexus-ms/libraries` rides outside the train (§ 1.5 PLX): npm semver via changesets is its versioning, and the train number says nothing about it.
It is generated from `preset-repo-web` like a tenant's web repo and takes its arrangement from the train; `plx`, `@plexus-ms/lib` and `@plexus-ms/config` left it for `primitives`, where they are versioned by the train (§ 1.6 PLX), because they are arrangement, not application libraries.
§§ 5 and 6 carry no requirements yet: one package repo and one deploy verb are their consumers, and they gain requirements when a second consumer of each exists.
