---
title: PLX-Delivery – from a verified commit to a running or published artifact
short_title: PLX-Delivery
description: The two phases verify and release and the verbs inside them (check, build, test, publish, deploy); the workflows that mount them on the forge; environment branches and promotion; how an image and a package are released; what the deploy verb does; where the jobs run; and what happens when a deploy is red.
code: PLX-Delivery
maturity: standard
binds: repo
depends: [PLX-Repo]
consumes: [PLX-App, PLX-Host, PLX-Environment]
order: 17
---

A CI/CD system needs state (what exists), events (something changed), and procedures (make it so).
Plexus puts state in git, takes events from a forge someone else operates, and runs only stateless procedures.
This module is everything between a verified commit and a running container or a published package.
That is two phases made of five verbs, the workflows that mount them, the branch model that decides what runs where, where the jobs run, and the recovery when a deploy fails.

It binds a repo.
Each section says which kind of repo it binds: an app repo releases images and deploys them, a package repo releases packages, the operations repo deploys third-party apps and releases nothing.
The app's side of being deployed, the compose file, the healthcheck, the Dockerfile, is [PLX-App](../contracts/app.md); the host's side is [PLX-Host](../contracts/host.md).


## § 1 The verbs and the two phases

> - `PLX-Delivery/ReleaseVerified`: A release, run by the pipeline or by hand, MUST publish only content that `verify` has passed and deploy only an artifact so published.

Every repo answers `verify`, every automated step that ascertains code quality (`PLX-Repo/VerbSemantics`).
That is `check`, the steps that need no machine in particular, and, in a repo that builds images, `build` and `test` on the image that would ship.
A repo that publishes or runs an artifact does so through `release`: `publish`, a versioned artifact from verified code into a registry, and `deploy`, a published artifact launched into an execution environment.
`release` acts on content that `verify` has passed, in the same run or in an earlier one whose result the registry holds, and neither verb re-verifies.
Whatever operates on a repo without having written it reaches it only through these verbs (`PLX-Repo/OperatorBoundary`); the incantations behind them are the repo's own.

Two phases, asked on two occasions: `verify` answers "is this sound", `release` answers "may this ship".
Every repo answers the first; the repos that produce and run artifacts answer the second.
Each verb is a job of its own, except `build` and `test`, which share one machine and are therefore the two steps of one job (§ 2).
`check` is lint, typecheck and every other static check, repo-wide.
It needs no machine in particular and gates everything after it: a commit that fails here builds and launches nothing.
`build` makes an app's image hermetically from its Dockerfile and pushes it to the registry as a candidate.
`test` brings the app's own compose file up on that candidate and runs the app's tests against it, so a pull request is verified against the image that would ship.
`publish` puts a tested candidate under its commit in the tenant's forge registry; `deploy` launches it where the operations repo's inventory places the app in the branch's environment.
`deploy` never builds: the operations repo deploys images it never built, a rollback re-launches an image that was published long ago, and a re-run deploys the same artifact again.

The verbs are of two kinds, and the difference is where their logic lives.
`check` is the contract verb's own decomposition: a root mise task of the repo, with whatever `lint`, `check` and `test` mean in its toolchain (§ 3 PLX-Repo).
A repo without images to build runs its whole `verify` there.
`build`, `test`, `publish` and `deploy` are ops verbs: they run outside the repo, on the forge, and are the same for every repo of their kind.
The first three are commands of `plx-ci`, the last of `plx` ([PLX-CLI](cli.md)), and every one is hand-runnable from a checkout with the same keys in the environment.
A package repo's `publish` is the one exception in shape, an arrangement of forge steps around changesets (§ 5), hand-runnable all the same.

What `verify` has passed is decided by content, never by a diff.
A build is keyed by Turbo's hash of the app's `build` task over its inputs, a test by the hash of its `test` task, and the registry holds the result under those hashes (§ 4).
The same inputs are therefore built once and tested once, whatever branch or run asks, and a run whose hashes all hit builds and launches nothing.
The guarantee "from verified code" is the registry's record rather than the run's order: an artifact that exists for a hash was built and tested for it.
A later run that finds it, a promotion of `main` to a `develop` tip among them, publishes and deploys it without verifying the same content again.
Hand-run, `publish` publishes what it is pointed at.


## § 2 Workflows and the pipeline

> - `PLX-Delivery/NoControlPlane`: A tenant MUST NOT operate its own CI control plane.
> - `PLX-Delivery/Forge`: The forge SHOULD be GitHub, used as the hosted service and not self-hosted.
> - `PLX-Delivery/GeneratedWorkflows`: A tenant repo SHOULD carry only the workflows its template generates.
> - `PLX-Delivery/NoWorkflowLogic`: A tenant repo MUST NOT carry logic in workflow YAML.

The templates generate the workflows, and the reusable workflows they call live in `plexus-ms/tooling`, named with a leading underscore and referenced by the version tag.
With them every repo runs `check` on every pull request, tested as the merge result, in a workflow `on_pr`, and a change to nothing but Markdown starts no run.

| Repo | Workflows |
|---|---|
| App repo | `on_commit` (`check` on a push to any branch but its environment branches), `on_pr` (`check`, then `verify`), `on_push` (`check`, `verify`, `release` on a push to an environment branch) |
| Package repo | `on_pr` (`check`), `on_push` (`check`, `publish` on its trunk) |
| Operations repo | `on_commit` and `on_pr` (`check`), `deploy` |

A repo whose CI holds instances or a registry of the tenant's own also carries `housekeeping`, the daily retention of what its runs leave behind.

A job is a verb, or two that want the same machine one after the other, and is named after the verb or verbs it mounts.
A workflow is a mount, named after the occasion that runs the verbs.
Three occasions ask the two questions of § 1.
A commit pushed to a branch of its own (`on_commit`) asks the cheap half of "is this sound", `check` alone, so that a lint error is known before a pull request exists and nothing is built for work in progress.
A pull request (`on_pr`) asks the whole of it, `check` then `verify`, on the merge result rather than the branch tip.
A run that answers nobody is not started: a pushed branch without a pull request gets no build, and a Markdown-only change starts nothing, while the next run that does start loses nothing, since the hashes see past it.
A push to an environment branch (`on_push`) asks "may this ship": `check`, `verify`, then `release` into the branch's environment, `main` into production and `develop` into staging (§ 3).
Inside each workflow the reusable workflows `_check.yml`, `_verify.yml` and `_release.yml` form a `needs` chain, and `check` gates `verify`: a failed lint launches no instance and builds no image.

`verify` plans once for the whole repo and run.
Its `plan` job computes every app's build and test hashes from one Turbo dry run and looks them up in the registry.
When the run is going to release, it also reads where each app deploys from the operations repo's inventory ([PLX-Environment](../contracts/environment.md)), and it emits the matrix.
`build-and-test` fans out over the matrix, each leg one app and what it owes, and `cleanup` deletes whatever `plan` launched for them.
A leg owes the build where the app's image is missing and the test where its test tag is: both, the test alone on a candidate the registry already holds, or the build alone for an app without tests.
The two verbs are steps of one job because the forge's job graph is static and `needs` connects jobs, never the legs of a matrix.
As steps, an app's test starts when its own build ends and a failed build tests nothing.
The legs stay independent: a broken app does not hold back a sound one, and an app whose hashes both hit has no leg.
`release` takes the plan's output: `publish` per app, then `deploy` per app with a target in the environment, as `_deploy.yml` nested inside it.
A promotion never builds.
A run by hand on an environment branch republishes and redeploys every app from the images it finds, and a run by hand on a branch that names no environment releases nothing.

A package repo's `on_push` is `check` then `publish`, the package shape of the verb (§ 5), on its trunk.
Its `main` admits nothing but pull requests, so `on_commit` has nothing to run there, and the "version packages" branch is pushed with the workflow token, which starts no workflow of its own.
The operations repo's `main` takes an operator's direct pushes, so `on_commit` checks those.
Its `deploy` workflow deploys the third-party apps under `apps/` from `main`, every app on every push that touches `apps/`.
The deploy verb ends at once where the host already serves the app's file (§ 6), so only a changed app restarts.
`housekeeping` runs daily where the thing kept lives: in the operations repo for the tenant's throwaway instances and the registry buckets, in an app repo for the candidates it holds in the forge's registry (§ 8).

Cancellation sits on `check` and `verify` and never on `release`.
A newer push to the same ref cancels the verify still going for the older commit, whose verdict nobody waits for any more, and its `cleanup`, which runs whatever the legs ended in, deletes its instances.
A `release` already started runs to its end, since a deploy cut off between migrate and up would strand the host.
Deploys of one app to one host keep their own queue, at most one running and the newest waiting.

Every mount is thin: checkout, secrets plumbing, one or two invocations of a verb.
The mount's only logic is the strategy expression that says where the job runs (§ 8).
The tenant's own workflows are generated by the templates and carry the Plexus version; a tenant repo carries no reusable workflow of its own, and the underscore says at a glance which files are triggered and which are called.
A tenant's workflows hold one secret, the CI vault's service account token; everything else a job needs is read from the vault `<owner>-ci` (§ 8, [§ 3 PLX-Secrets](secrets.md)).

GitHub Actions *is* a control plane, but one someone else operates, with git as input; that is the allowed shape.
A runner host of the tenant's own (§ 8) is no control plane either: the forge holds the runs and schedules the jobs, and the host executes the job it is handed and keeps no record of it.
`PLX-Delivery/NoControlPlane` forbids operating the scheduler, not the machine a job runs on.
The forge is tier-0 for deploys either way: CI is the deploy trigger and the registry holds the images, so a forge outage means no automated deploys.
What bounds the damage is the usual pair.
Running systems keep running and git is distributed, so an outage costs deploy availability, never data; and the verbs stay hand-runnable, so a forge-less deploy remains possible, just not convenient.
Not self-hosting avoids *operating* tier-0, not *depending* on it.
Code and CI configs are not personal data, and a self-hosted forge would be a tier-0 dependency the tenant has to secure and back up before it protects anything.
Leaving GitHub means adjusting the mounts, never the logic: a tenant on another forge rewrites a few YAML files and keeps every verb.


## § 3 Environment branches and promotion

> - `PLX-Delivery/EnvironmentBranches`: An app repo MUST use environment branches: `main`→`production`, `develop`→`staging`.
> - `PLX-Delivery/OperationsTrunk`: The operations repo SHOULD have a single `main`, its environments being inventory groups, never branches.
> - `PLX-Delivery/NoAppChangesets`: An app repo MUST NOT use changesets.
> - `PLX-Delivery/HotfixBackMerge`: A hotfix, branched from `main` and merged to `main`, MUST be back-merged `main → develop` immediately.
> - `PLX-Delivery/FastForwardPromotion`: Promotion MUST be a fast-forward of `main` to `develop`, so that `main` carries no merge commits of its own.
> - `PLX-Delivery/PromotableDevelop`: `develop` MUST stay promotable; unfinished or still-soaking work lives on feature branches, never parked on `develop`.
> - `PLX-Delivery/NoSelectivePromotion`: Selective promotion (cherry-picks, path-restricted merges) MUST NOT be used.
> - `PLX-Delivery/SingleMonorepo`: A tenant SHOULD start with a single web monorepo (one repo holding `apps/` and `packages/` for one web ecosystem) and add a further app repo only for a product that persistently needs a release cycle of its own.

This section binds app repos.
`production` and `staging` are the environment names a deploy asks the platform inventory for ([PLX-Environment](../contracts/environment.md)).
Staging and production may share a VM or take one each, since both sit inside one tenant's trust domain and [PLX-Tenancy](../contracts/tenancy.md) partitions tenants, not environments.
An app release has no version number to reconcile: a release is an image keyed by git SHA, and the deploy that follows is keyed by the same SHA.
Branches map to deploy targets.
"Promote staging to prod" is fast-forwarding `main` to `develop` (`git push origin origin/develop:main`, the `promote` task the template ships), never a merge commit.
A merge commit on `main` is a commit `develop` does not know, so the next promotion has to merge again, and `main` becomes a chain of promotion merges that says nothing.
A fast-forward keeps `main` a pointer into `develop`'s history, and git refuses the push when it would be anything else.
The hotfix back-merge is what keeps the fast-forward possible: after it, `main` is an ancestor of `develop` again.
Release tooling built for registries (changesets) has nothing to version in an app repo, which is why it is excluded outright; packages version by different physics (§ 5), and the two models are never mixed.

Which host an environment *is*, is inventory, not convention: `main`→`production` and `develop`→`staging` name environments.
The binding, which VM, which inventory record, which domain, lives in the operations repo's inventory ([§ 3 PLX-Platform](platform.md)), one record per app and environment.
`plan` reads it from a checkout of the tenant's operations repo made with the tenant's GitHub App ([PLX-Environment](../contracts/environment.md)).
An app without a record in an environment has no deployment there, and a push to that environment's branch releases its image and deploys nothing.
The operations repo itself needs no environment branches because it has no release cycle of its own to promote: staging and prod are two inventory groups in one file, and a playbook run targets one of them.

The model: **the unit of deployment is the app; the unit of promotion is the repo.**
A release acts per app and on content: an app whose inputs, its own directory plus every workspace package it depends on, did not change is neither built nor redeployed.
A merge to an environment branch releases every app into that environment and builds exactly the ones whose inputs changed.
A docs-only merge builds nothing, a `packages/ui` change rebuilds its dependents, and an unchanged app is published from the candidate the registry holds and left running where the host already serves it.
The decision is a content hash per app, Turbo's hash of the app's `build` task (§ 4).
That one definition covers merge commits, squash merges, multi-commit direct pushes and force-pushes identically, stateless and without bookkeeping.
Promotion builds nothing that `develop` built: an app whose candidate exists for the promoted tree is published and deployed from it (§ 2).
Only an app whose inputs on `main` differ from everything the registry has seen is built again.
The hashing is the verb's, not YAML logic: `plx-ci plan` reads the workspace graph through Turbo and the registry, and prints what the run owes.

Promotion is the whole repo: `develop → main` asserts *everything on `develop` is prod-ready*.
Selective promotion would put on prod a repo state that never existed on staging, destroying the one guarantee environment branches exist to give.

Two boundaries of the model.
The operations repo has no release cycle: its ops side is not an app and the deploy verb never touches it; applying it is a playbook run, its own mount, on its own occasions.
Third-party apps hosted in the operations repo are the exception that proves it: they *are* apps, so the deploy verb does touch them.
It is mounted on the operations repo's `main` and fanned out over every app under `apps/` with a target in the inventory, the verb itself telling an unchanged app from a changed one.
And the escape valve is a repo split, not a process patch.
If two products in one tenant *persistently* need independent release cadences, one moves into its own repo, still inside the tenant's org and access boundary, still on the same contract.
Granularity problems are solved by moving a product into a release cycle of its own, never by making promotion partial.


## § 4 Releasing an image

This section binds app repos.
An app's image is built hermetically from its Dockerfile and pushed to the tenant's registry, tagged with the git SHA it was built from.
It lives under the tenant's own organisation and is pushed with the repo's own forge token, never with a token that crosses an organisation.
An app's image is built once per content, in `verify`, and published under its commit in `release`:

- `build` builds from the Dockerfile the app contract asks for ([§ 7 PLX-App](../contracts/app.md)) and pushes the candidate to the registry (§ 8) as `build-<hash>`, Turbo's hash of the app's `build` task, which is also the build ID inside the image.
- `test` adds `test-<hash>`, the hash of its `test` task, to the manifest when the tests passed on it.
- `publish` copies the tested manifest to the tenant's forge registry under `<sha>`, the reference a deploy takes, with the two hash tags beside it.

The hashes are what `plan` looks up, so a lockfile change or a force-push rebuilds nothing whose inputs did not change, and a change to specs alone re-runs the tests on the existing image.
The build is hermetic: it runs inside the Dockerfile, so the artifact is correct from any host.
What *build* means is encoded once, in the repo's task graph, which the Dockerfile invokes exactly as the `build` verb does.
It is reproducible as far as the stack allows.
The context is `turbo prune --docker`, so an app's image is independent of the other apps' dependencies, and the base image is pinned by digest.
The build ID and the app's server-actions key are fixed from outside, the key read from the vault item `app_<name>`, and timestamps are zeroed.
What still drifts (Next's preview-mode keys, a package installed at build time) is measured and listed, never gated.
Publishing for one platform (amd64) is the default; multi-arch is a deferred decision with a trigger (§ 6.7 PLX).

The layer cache lives in the registry beside the candidates (`<app>:cache`).
A build on a fresh machine, the forge's runner or an instance launched for it, starts from the last build's layers and never round-trips a cache through the forge.
SHA-tagged images accumulate in the forge's registry unboundedly, which rollback and re-deploys rely on; the candidates are the retention's (§ 8).


## § 5 Releasing a package

This section binds package repos.
Packages release into a registry keyed by semver, and that different physics wants a different branch model from the apps'.
A package repo is trunk-based on a single `main`, versioned and published by **changesets**.
Why trunk-based: changesets accumulates changeset files on one branch, bumps them in one PR on that branch, and publishes from it.
A second long-lived branch forces reconciling version numbers between branches on every release, a perpetual back-merge tax; changesets is a trunk-based tool, and pairing it with environment branches fights it.
Concurrency is not a reason to avoid this: changeset files have random names and the bump is deferred to one central step, so simultaneous feature branches never conflict and never double-publish.

How a release runs:

- **Two phases.** Changesets accumulate on `main`; `changesets/action` opens a "version packages" PR that bumps versions and writes changelogs; merging it publishes.
  The only manual step is recording a changeset with each publishable change; versioning and publishing run in CI, never locally.
  `on_pr` runs the contract verb plus a `changeset status` guard that fails when a publishable change ships without a changeset; an empty changeset records a no-release change.
- **The bot's changesets.** The update bot writes no changesets, so its branches are exempt from the guard.
  They get their changeset from `plx changeset`, mounted on the bot's pull requests by `_changeset.yml` and committed to the bot's branch under an author the bot ignores ([§ 2 PLX-Updates](updates.md)).
  A moved runtime dependency owes a patch, a moved peer range a major, a devDependency nothing; the verb's header in `tooling` states the rule in full.
  The rule is the ecosystem's (pnpm's `update --changeset` and Renovate's proposed `changesets` option apply the same one).
  It holds because a package declares what it ships: nothing is bundled into a published artifact, so a release of a dependency releases its dependents through the declared graph.
- **Token-less via OIDC.** Publishing authenticates through GitHub OIDC *trusted publishing* (`id-token: write`), not a stored npm token, which also makes provenance automatic.
  A package cannot be registered as a trusted publisher until it exists, so each package's **first** publish is a one-time manual `npm publish`.
  That publish is token-authenticated and therefore *without* provenance; the attestation chain starts at the second release, and CI takes over after.
- **Tags and GitHub Releases are automatic:** `changeset publish` tags each `@plexus-ms/<pkg>@x.y.z`, the action pushes them and cuts a Release from the changelog.
  The release branch (`main`) is protected by a ruleset requiring the verify check; keep it that way, since this is what stands behind the upstream guarantees (§ 1.6 PLX).

A `@plexus-ms/*` package is tenant-neutral methodology, never substance; this is the standard's guardrail and it binds every publish.
A tenant publishing packages of its own to a private registry ([§ 1 PLX-Updates](updates.md)) takes the same shape.
Code utilities start in `@plexus-ms/std`, the standard *library* ("the standard" alone always names PLX itself, never this package), the default home for any small shared concern.
A concern graduates to its own package once it has its own audience or its own release cadence: a consumer should not take updates because an unrelated helper changed.
Tool configs are the one deliberate exception to per-concern packages: they bundle into `@plexus-ms/config` as subpath exports (`@plexus-ms/config/biome`, `/tsconfig`, …), each still a one-line `extends` target.
They share one package because they share one audience and one release cadence, and each separate package costs a manual bootstrap publish.
A config splits out only if it ever grows its own cadence.
Packages follow semver, enforced by changesets: a breaking change is a major bump, and its changeset carries a migration note so the changelog doubles as the upgrade guide.

Application plumbing, the "standardize boundaries" edges (framework glue, common auth concerns, repeatable non-domain features), is extracted into a package when a second app needs the same plumbing, never speculatively from the first.
Until then it lives in the app that needs it (§ 4.6 PLX).

The initiative's packages live in `plexus-ms/libraries`, which does not carry the Plexus version (§ 1.5 PLX): npm semver via changesets is its versioning.
It is generated from `template-repo-turbo` like a tenant's web repo and takes its arrangement by taking Plexus versions.
`plx` and `@plexus-ms/lib` live in `tooling` and carry the Plexus version instead, because they run around an app and are never imported by one; `@plexus-ms/config` is a library, since an app's manifests depend on it.


## § 6 Deploy semantics

This section binds every repo that deploys: app repos through their pipeline, the operations repo for the third-party apps under its `apps/`.
It describes what the shared deploy verb (`plx deploy`, [PLX-CLI](cli.md)) does, so the contract requirements riding on it ([`PLX-App/Healthcheck`](../contracts/app.md), [§ 9.2 PLX-App](../contracts/app.md)) make sense.
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
        → wait for the app service's healthcheck
        → on failure: restore the previous file, docker compose up -d, alert
```

The verb renders the app's `compose.yaml` from the invoking checkout onto the host, pinning the image ref in place of `${PLEXUS_DEPLOYMENT_IMAGE}`.
Before staging, it refuses a rendered file whose app service declares no `healthcheck` (`PLX-App/Healthcheck`), which it could never see turn healthy, and never reaches the host.
A failure anywhere before the swap, a pull or a migrate, leaves the host exactly as it was, so the previous release keeps serving from its own compose file; the failing job is the alert.
The verb ends without pulling or restarting when the host already serves the app from the same rendered file, healthy.
A promotion therefore restarts only the apps whose image changed, and the operations repo's deploy of every app on every push restarts only the one that changed.

The verb reads everything from git (the compose file) and from the host (`docker ps` is runtime truth) and stores nothing.
"Which version is live" is the running container's image, queryable from reality, and equally the image pinned in the compose file the host serves from.
Rollback needs no memory across runs: the verb keeps the previous compose file until the run ends, and the image it pins is still in the host's cache.
The rollback path never pulls: it has to work while the registry is down or a tag has been pruned, so it re-launches the cached image under the compose file it was serving from.

The wait is deadline-based, not one-shot: the verb waits until the app service's container reports `healthy` to Docker or a deadline expires (reference: ~60 s).
A transient blip inside the window is absorbed; only sustained unhealthiness fails the deploy.
Because the healthcheck covers the hard dependencies, a down database fails the deploy, correctly, since the new code cannot serve, and the ensuing rollback is harmless by idempotence.
The verb never needs to diagnose *why* the app service did not turn healthy; it only ever acts on *whether*.

The alert is deliberately minimal: hand-run, it is the verb's nonzero exit and its stderr; mounted in CI, the failing job *is* the alert, surfaced however the forge notifies.
A richer channel is an observability concern (§ 12.4 PLX).

Rollback's limit: it re-ups the previous image; it never reverses a migration.
By the time the healthcheck fails, `migrate` has already run, and the old code comes back up against the new schema.
That is sound only because the stateful profile makes it sound: every migration is backward-compatible with the release currently in production (`PLX-App/Stateful/ExpandContract`).
For the rare deploy that deliberately breaks that discipline, reverting is a restore from backup, not a re-up.

Two more edges, named rather than implied.
A *first* deploy has no previous compose file: if the app service does not turn healthy, the verb simply fails loudly.
Nothing was serving before, so nothing is lost, and bringing a new app up is the operator's supervised act.
And `compose up -d` re-creates containers in place, so every deploy buys its simplicity with a few seconds of downtime, the accepted trade at this scale.
Zero-downtime choreography is a deferred decision with a trigger (§ 6.9 PLX), not an ambient expectation.

The verb has a fence, and crossing it takes a deliberate, documented decision: no persistent state, no daemon, no UI, no reconciliation loop, no provisioning of platform resources at deploy time.
Inside the fence, logging, clean rollback and good error messages are invested in freely.
Anything outside it is either an existing tool's job or an architecture change, not feature creep; whatever answers zero downtime, it stays a verb, not a reconciler.

The verb has one name and three callers.
An app repo's `release` runs it per app with a target in the environment, after `publish` (§ 4), from the target `plan` read in the inventory.
The operations repo's `deploy` runs it for the third-party apps under its `apps/`, from `main`, with the image already pinned in the committed file, each app's target looked up in the inventory by the `deploy-targets` verb.
Hand-run, it is `plx deploy deploy@host app --image <ref>` from any checkout that has the compose file.
`plx -n deploy …` prints every ssh line it would run, which is what makes a forge-less deploy possible, with or without the tool.
The deploy host is substance: the inventory record's `plexus_deploy_target` ([PLX-Environment](../contracts/environment.md)).
It is reached over the tenant's overlay network or a public forward, whichever the tenant's platform provides (§ 8).


## § 7 Failed deploys and recovery

> - `PLX-Delivery/PromotionFreeze`: While a staging deploy is red, `develop → main` MUST NOT be merged.
> - `PLX-Delivery/Recovery`: Recovery from a failed deploy MUST be a re-run of the failed job or a hand-run deploy of the same artifact, never an empty commit.

A failed deploy parks promotion, and recovery is named, not improvised.
The changed set carries no memory, so the pipeline never *rediscovers* a failed deploy.
After the rollback and alert (§ 6), the environment branch is ahead of what actually runs, and the next unrelated merge will not close the gap.
Closing it is the operator's move, using mechanisms that already exist: re-run the failed job (same SHA, same artifact) once the cause is fixed, or invoke the hand-runnable deploy verb directly.
A red staging deploy directly falsifies `develop`'s prod-readiness, hence the promotion freeze.


## § 8 Where the jobs run

> - `PLX-Delivery/PrivateRunners`: A runner of the tenant's own MUST serve only that tenant's private repos.
> - `PLX-Delivery/CIVault`: CI's credentials MUST live in the vault `<owner>-ci` ([§ 3 PLX-Secrets](secrets.md)), read with one service account token, the one CI secret a repo holds, and reach a workflow in no other way; the one exception is the credentials of the tenant's GitHub App, which a repo that reads nothing else from the vault MAY hold on the forge instead, as the variable `GH_CLIENT_ID` and the secret `GH_PRIVATE_KEY`.

This section binds every repo that mounts a verb on the forge.
Three questions of the template decide it, each answered per repo and a fact rather than a secret:

- the **strategy** (`ci_strategy`: `github`, `on-prem` or `hybrid`), where a job of each size runs;
- the **registry**, where the candidates of § 4 live;
- the **overlay**, how a deploy reaches the app hosts.

The repo variable `CI_STRATEGY` overrides the strategy for the next run, and `github` remains a working answer for every repo.

**Sizes.**
Every job has a size, `small`, `medium` or `large`, that says what machine it wants, and asks for its runner by it.
The label is `ci-<size>` where the tenant's own runners serve the size, `ubuntu-latest` where the forge's do.
`check` is medium, since lint and typecheck want cores and a few gigabytes.
`build` and `test` are large, a machine with Docker and the memory for an image build or a browser.
`plan`, `publish`, `deploy`, `cleanup` and `housekeeping` are small, a shell with a token.
The size is the job's, and the strategy maps it to a machine.

**Strategies.**

| Strategy | small, medium | large | Registry default | What the tenant operates |
|---|---|---|---|---|
| `github` | the forge's runners (`ubuntu-latest`) | the forge's runners | `ghcr` | nothing |
| `on-prem` | container slots on a runner host of the tenant's own | a privileged slot with a Docker daemon of its own | `own` | the runner host |
| `hybrid` | container slots on a runner host of the tenant's own | a throwaway cloud instance per app that owes a build or a test, launched by `plan` and gone after it | `own` | the runner host and a cloud account |

`github` is the default and the answer with nothing to operate: a fresh machine per job, destroyed afterwards, minutes billed beyond the free allowance.
The forge's largest machine on the free plan is `ubuntu-latest`, so that is what `large` is there.
`on-prem` is a tenant with hardware to spare: every size is a slot of a runner host.
A large slot is the one container of the host that runs privileged, with a Docker daemon inside it whose state dies with the job, so the job meets an empty machine with Docker.
`hybrid` is a tenant with a small runner host and a cloud account.
The small and medium jobs run on the host's slots, which cost nothing per job and pick a job up within seconds.
Each large job runs on an instance of its own, launched by `plan` for that one job and deleted by `cleanup`, so no build contends with another and no large machine idles.
The strategy is the generated workflows' expression `${{ vars.CI_STRATEGY || '<answer>' }}`.
While a runner host or the cloud is down, the way back is one repo variable, `CI_STRATEGY=github`, and the next run is on the forge's runners without a commit; deleting it is the way forward again.
On a web repo of three apps, a pull request that owes every build takes about eight minutes under `hybrid` or `on-prem` and about one minute when every hash hits.

**The registry** holds the candidates and the layer cache (§ 4).
Under `ghcr` they live beside the published images, in the forge's registry, under the tenant's organisation; the only credential is the job's own token.
Under `own` they live in a registry pair on the tenant's object storage, which every job that needs it finds answering on loopback.
The read-write registry of the current month answers on `:5000` and the read-only one of the previous month on `:5001`, each a container against a bucket `<owner>-ci-registry-<YYYY-MM>`.
On the forge's runners and on an instance the job starts the pair itself for its own length (`plx-ci registry`); on a runner host the host runs it, on the same ports and buckets.
Retention is rotation, never garbage collection: writes go to the current month, reads consult both months, and the daily `housekeeping` creates the next month's bucket and deletes the one from two months ago whole.
That costs one cold build per app a month.
Under `ghcr` the `housekeeping` of the app repo deletes the package versions whose only tags are candidates older than thirty days; a version carrying a commit is never deleted.
`own` also carries Turbo's remote cache for `check`, in a bucket `<owner>-ci-turbo` with a lifecycle rule, served to the job by a cache server on loopback with a token minted for the job.
A task whose inputs did not change is then replayed from any earlier job on any runner.

**The overlay** is how `deploy` reaches an app host that has no public SSH.
Under `none` the host is reached as the inventory names it, a public address or a forward.
Under `netbird` a job on the forge's runners joins the tenant's overlay for its length, as an ephemeral peer, and leaves with the job.
Its setup key comes from the vault, and the key's policy allows the app hosts' SSH and nothing else.
A job on a slot of a runner host joins nothing, since the slot shares the host's network and the host is on the overlay already.

**The runner host** (`on-prem` and `hybrid`) is a host of the tenant like every other, set up by the collections ([§ 2 PLX-Platform](platform.md)) through the `plexus.ci` playbook.
Its one role of its own, `actions_runners`, runs a number of container slots per size.
Each slot is a systemd unit that mints a just-in-time runner configuration with the tenant's GitHub App and starts a fresh container of the runner image for one job, and the next when that job ends.
Nothing registered outlives its job, and no registration token is stored.
The image is the official runner's with the few packages a small or medium job expects, published from `tooling` at the Plexus version and pinned by the role.
A small or medium slot has no Docker socket, which would be root on the host, and runs under the container engine's `no-new-privileges` and a memory limit per size.
A job there installs what it needs into its own home and never with `sudo`; the one thing the slots share is the host's pnpm store.
The slots register at one repository, or at the organisation in a runner group, so that every repo of the tenant uses them.
The operations repo's `deploy` and `housekeeping` need a slot as much as an app repo's jobs do, and on a forge plan without runner groups the organisation's default group serves every private repo.
A change to what a slot runs, its registration, its image, its limits, restarts the slots on the next playbook run, which a job in flight on the host does not survive.
Where the runner host shares a hypervisor with production, CI is down whenever production is, and the fix that would rescue production cannot pass it.
The deploy verb being hand-runnable and the fallback being one variable away is what makes that acceptable.

**The instances** of `hybrid` are the one place a job's machine exists for the job alone.
`plan` creates one per leg, from a stock Debian image with user-data that installs Docker and the runner, and waits for every runner to register.
Each carries the run, the attempt and two deadlines as labels, and a leg's job asks for the instance's unique label.
The instances tear themselves down in layers, so that no layer has to be the last: the instance deletes itself after its job, or when no job started by one deadline, and powers off after the other.
`cleanup` deletes what the run launched, and the daily `housekeeping` whatever is stopped or past its deadline.
A launched instance sometimes misses its boot: `plan` keeps it stopped for diagnosis, mails the tenant's alerts address, and launches one replacement, and `housekeeping` deletes a kept instance after fourteen days.
The layers and the trap are stated step by step in the headers of `plx-ci`'s instance verbs and the instance's user-data.
Because an instance exists for one job of one attempt, a failed `build-and-test` is re-run only through a re-run of the whole run, which plans and launches afresh; "re-run failed jobs" queues the job for a runner that no longer exists.
The provider's measured behaviour and its IAM are the [Exoscale field notes](exoscale.md).

**The vault** `<owner>-ci` holds what the strategy needs and nothing a workflow is handed otherwise; which items exist follows from the three answers:

| Item | Fields | Read when |
|---|---|---|
| `app_<name>` | `server-actions-key` | every build of the app, so that the candidate is reproducible |
| `github-app` | `client-id`, `private-key` | `plan` reads the operations repo's inventory for a release; the runner host's slots and the instances mint their runner configurations; `plx-update` and `changeset` push with it ([PLX-Updates](updates.md), § 5) |
| `deploy-ssh` | an SSH key | every deploy |
| `netbird` | `setup-key` | a deploy under `github` with `netbird` |
| `bucket-registry`, `bucket-turbo` | `endpoint`, `region`, `access-key-id`, `secret-access-key` | `own`: the pair and the Turbo cache |
| `exoscale` | `ci-launch/key`, `ci-launch/secret`, `ci-selfdelete/key`, `ci-selfdelete/secret` | `hybrid`: `plan`, `cleanup` and `housekeeping` launch and delete; an instance deletes itself |
| `smtp-relay` | `host`, `port`, `username`, `password`, `from` | `hybrid`: the mails of a missed boot, a deadline, a sweep |
| `1password-connect` | the Connect server's credentials file and access token | a runner host's playbook run |

The GitHub App is the tenant's one App and the tenant's own, installed on every repo that mounts a verb.
It holds `Contents: write`, `Pull requests: write` and `Workflows: write`, for the pull request by which a repo takes a version and for the changeset a bump owes, which covers the read of the operations repo's inventory.
For the runners it holds `Administration: write` on the app repo where they register at the repository, or `Self-hosted runners: write` on the organisation where they register there.
Each job mints a token for the one repo and the permissions it needs, so the App's breadth is never a job's.
The two mounts that only push, `_plx-update.yml` and `_changeset.yml`, take the App's client ID and key from the forge where a repo holds them there (`PLX-Delivery/CIVault`), and from the vault otherwise.
They fail with one line naming both when a repo has neither, so that a tenant whose repos read nothing else from a vault needs none.
A tenant under `github` with `ghcr` and no overlay holds the first three items and nothing else.

A job reads the vault with the service account token, one request per secret reference and more.
1Password limits those requests per token and hour (1,000 on the individual and Teams plans, 10,000 on Business) and per account and day (1,000, 5,000 and 50,000), all service accounts together.
A pull request under `hybrid` costs on the order of a hundred, so a day of two tenants' CI exhausts the individual plan's account, and every later job of the day fails at its first read.
A runner host therefore runs a **Connect server** (`actions_runners_connect`): an encrypted copy of the CI vault, synced by one container and served on loopback by another.
It is created once per tenant in 1Password with access to that vault alone, and the slots carry its address and token in their environment, so the reads of every job on a slot leave the account's budget untouched.
A workflow does not choose between the two.
The first step of every job that reads the vault hands the job the service account token only where the runner carries no Connect server's address and token, since `load-secrets-action` warns on every read when it is given both.
A slot's job therefore never holds the service account token, and a tenant whose jobs all run on slots can leave the secret unset.
A launched instance and the forge's runners cannot reach loopback and keep the service account, so the budget is spent by `build` and `test` under `hybrid` and by everything under `github`.
The address the strategy mails to is a fact, the template answer `alerts_email`, passed to the workflows as an input.

**What a tenant sets up** once, by hand:

- Every strategy: the vault `<owner>-ci`, whose service account token is the one CI secret of every repo, with the items `app_<name>` per app, `deploy-ssh` and `github-app`.
  The App itself, with the permissions above, is installed on every repo, and each host's record in the inventory carries `plexus_deploy_target`.
  A tenant with no app to deploy and no vault sets `GH_CLIENT_ID` and `GH_PRIVATE_KEY` at its organisation instead.
- `own`: a storage key with read and write on the buckets plus their creation and deletion, the bucket `<owner>-ci-turbo` with a lifecycle rule expiring objects after thirty days, and the first `<owner>-ci-registry-<YYYY-MM>`.
- `on-prem` and `hybrid`: a runner host in the inventory group `ci`, applied by the operations repo's `ci.yml` (`plexus.ci.playbook`), on the overlay with a policy that lets it reach the app hosts' SSH.
  Its playbook environment holds the App's credentials and, under `own`, the storage key; its slots are set by size (`actions_runners_slots`).
  A Connect server is created in 1Password (Developer tools, Infrastructure Secrets Management) with access to the CI vault.
  Its `1password-credentials.json` and access token go into the item `1password-connect` and reach the role as `CI_CONNECT_CREDENTIALS` and `CI_CONNECT_TOKEN`.
  A tenant that wants no upstream registry between it and its runners builds the runner image on the host from the same Dockerfile (`actions_runners_image_build`).
- `hybrid`: on the cloud, two IAM roles and keys, a security group admitting SSH only (for the diagnosis of a missed boot), an SSH key registered once, and a relay credential for the mails.
  The launch key may create, list, get, stop and delete instances and read templates, types, security groups and operations; the self-delete key may list, get and delete instances and read operations.
- `netbird`: a setup key whose policy allows the app hosts' SSH and nothing else.

Three trade-offs are named rather than implied.
The runner host persists between jobs, against "primitives should rarely remember anything".
The slots are the speed gain for the small jobs, and what they keep is one cache and the registry pair.
An hourly housekeeping timer on the host moves the pair to the new month's buckets and removes what the jobs leave behind.
The runner image updates with the version, since the forge stops scheduling onto a runner that falls far behind, and monthly is the floor.
And the write credentials in an instance's user-data are readable by the job that runs there, which is the same exposure as the secrets that job can read anyway, accepted for a tenant's private repos.


## Maintaining

The ops verbs are commands of `plx` and `plx-ci` ([PLX-CLI](cli.md)), and the reusable workflows that mount them carry no logic of their own.
Both ship from `plexus-ms/tooling` at the Plexus version, the tools on npm, the workflows by the version tag, so that a tenant's CI runs one number.
A tenant repo pins both tools in its `mise.toml`, and the pins move together with the workflow refs when the repo takes a version ([§ 3 PLX-Updates](updates.md)).
The verbs a workflow asks for are therefore the ones the pinned tools have.
Each verb's source file and each reusable workflow states in its header what it does step by step.
The verbs are tested in `tooling`, the deploy verb against a fake `ssh` and a fake `docker`, the instance verbs against a fake cloud.
A workflow is forge-specific and disposable, while a verb is portable and permanent, which is why logic never lives in the YAML.

The templates generate the tenant's workflows: `plexus-ms/template-repo-turbo` for an app repo and, with `publishes_packages`, a package repo; `plexus-ms/template-repo-operations` for the operations repo.
The upstream repos that are no template's consumer (`tooling`, `compendium`, `template-repo-turbo`) mount `_check.yml` with `tasks: verify` by hand.

§§ 4 to 6 carry no requirements: what they describe is done by the tooling and the templates, and the requirements the deploy verb serves are PLX-App's.
Preview environments per pull request are deliberately absent, a deferred decision with its trigger in § 6.8 PLX.
