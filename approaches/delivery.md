---
title: PLX-Delivery – from a verified commit to a running or published artifact
short_title: PLX-Delivery
description: The two phases verify and release and the verbs inside them (check, build, test, publish, deploy); the workflows that mount them on the forge; environment branches and promotion; how an image and a package are released; what the deploy verb does; where the jobs run; and what happens when a deploy is red.
code: PLX-Delivery
maturity: standard
binds: repo
changed: 0.111.0
depends: [PLX-Repo]
consumes: [PLX-App, PLX-Host, PLX-Environment]
order: 17
---

A CI/CD system needs state (what exists), events (something changed), and procedures (make it so).
Plexus puts state in git, takes events from a forge someone else operates, and runs only stateless procedures.
This module is everything between a verified commit and a running container or a published package: two phases made of five verbs, the workflows that mount them, the branch model that decides what runs where, where the jobs run, and the recovery when a deploy fails.

It binds a repo.
Which sections bind which kind of repo is said at each section: an app repo releases images and deploys them, a package repo releases packages, the platform repo deploys third-party apps and releases nothing.
The app's side of being deployed, the compose file, the readiness endpoint, the Dockerfile, is [PLX-App](../contracts/app.md); the host's side is [PLX-Host](../contracts/host.md).


## § 1 The verbs and the two phases

> - Every repo MUST answer `verify`: perform every automated step that ascertains code quality (§ 3 PLX-Repo), as `check`, the steps that need no machine in particular, and, in a repo that builds images, `build` and `test` on the image that would ship.
> - A repo that publishes or runs an artifact MUST do so through `release`: `publish`, a versioned artifact from verified code into a registry, and `deploy`, a published artifact launched into an execution environment.
> - `release` MUST act only on content that `verify` has passed, in the same run or in an earlier one whose result the registry holds; `deploy` MUST launch only an artifact so published; neither verb re-verifies.
> - Whatever operates on a repo without having written it MUST reach it only through these verbs; the incantations behind them are the repo's own.

Two phases, asked on two occasions: `verify` answers "is this sound", `release` answers "may this ship".
Every repo answers the first; the second is answered by the repos that produce and run artifacts.
Inside the phases are the verbs, each one job.
`check` is lint, typecheck and the pure tests, repo-wide, the part of `verify` that needs no machine in particular and gates everything after it: a commit that fails here builds and launches nothing.
`build` makes an app's image hermetically from its Dockerfile and pushes it to the registry as a candidate; `test` brings the app's own compose file up on that candidate and runs the app's tests against it, so a pull request is verified against the image that would ship.
`publish` puts a tested candidate under its commit in the tenant's forge registry; `deploy` launches it where the platform repo's inventory places the app in the branch's environment.
`deploy` never builds: the platform repo deploys images it never built, a rollback re-launches an image that was published long ago, and a re-run deploys the same artifact again.

The verbs are of two kinds, and the difference is where their logic lives.
`check` is the contract verb's own decomposition: a root mise task of the repo, with whatever `lint`, `check` and `test` mean in its toolchain (§ 3 PLX-Repo), and a repo without images to build runs its whole `verify` there.
`build`, `test`, `publish` and `deploy` are ops verbs: they run outside the repo, on the forge, and are the same for every repo of their kind; the first three are commands of `plx-ci`, the last of `plx` ([PLX-CLI](cli.md)), and every one is hand-runnable from a checkout with the same keys in the environment.
A package repo's `publish` is the one exception in shape, an arrangement of forge steps around changesets (§ 5), hand-runnable all the same.

What `verify` has passed is decided by content, never by a diff.
A build is keyed by Turbo's hash of the app's `build` task over its inputs, a test by the hash of its `test` task, and the registry holds the result under those hashes (§ 4): the same inputs are built once and tested once, whatever branch or run asks, and a run whose hashes all hit builds and launches nothing.
The guarantee "from verified code" is therefore the registry's record rather than the run's order: an artifact that exists for a hash was built and tested for it, and a later run that finds it, a promotion of `main` to a `develop` tip among them, publishes and deploys it without verifying the same content again.
Hand-run, `publish` publishes what it is pointed at.


## § 2 Workflows and the pipeline

> - A tenant MUST NOT operate its own CI control plane.
> - The forge SHOULD be GitHub; a tenant SHOULD NOT self-host a forge.
> - Every repo MUST run `check` on every pull request, tested as the merge result, in a workflow `on_pr`; a change to nothing but Markdown SHOULD start no run.
> - An app repo MUST carry `on_commit` (`check` on a push to any branch but its environment branches), `on_pr` (`check`, then `verify`) and `on_push` (`check`, `verify`, `release` on a push to an environment branch); a package repo MUST carry `on_pr` (`check`) and `on_push` (`check`, `publish` on its trunk); the platform repo MUST carry `on_commit` and `on_pr` (`check`) and `deploy`.
> - A repo whose CI holds instances or a registry of the tenant's own MUST carry `housekeeping`, the daily retention of what its runs leave behind.
> - A newer run for the same ref MUST cancel a `check` or `verify` still going for an older commit, and MUST NOT cancel a `release` once started.
> - A job MUST be named after the verb it mounts; a workflow is named after the occasion it mounts the verbs on.
> - Reusable workflows live in `plexus-ms/primitives`, named with a leading underscore; a tenant repo SHOULD carry only the generated workflows and MUST NOT carry logic in workflow YAML.
> - A tenant repo's workflows MUST reference the reusable ones by the train tag.

A job is a verb; a workflow is a mount: the occasion that runs the verbs.
Three occasions ask the two questions of § 1.
A commit pushed to a branch of its own (`on_commit`) asks the cheap half of "is this sound", `check` alone, so that a lint error is known before a pull request exists and nothing is built for work in progress.
A pull request (`on_pr`) asks the whole of it, `check` then `verify`, as the merge result rather than the branch tip; a run that answers nobody is not started, which is why a pushed branch without a pull request gets no build, and why a Markdown-only change starts nothing while the next run that does start loses nothing, since the hashes see past it.
A push to an environment branch (`on_push`) asks "may this ship": `check`, `verify`, then `release` into the branch's environment, `main` into production and `develop` into staging (§ 3).
The chain inside each workflow is a `needs` chain of three reusable workflows, `_check.yml`, `_verify.yml` and `_release.yml`, and `check` gates `verify`: a failed lint launches no instance and builds no image.

`verify` plans once for the whole repo and run.
Its `plan` job computes every app's build and test hashes from one Turbo dry run, looks them up in the registry, reads where each app deploys from the platform repo's inventory when the run is going to release ([PLX-Environment](../contracts/environment.md)), and emits the matrices; `build` and `test` fan out over them, each leg one app and one hash, and `cleanup` deletes whatever `plan` launched for them.
The forge's job graph is static and `needs` connects jobs, never the legs of a matrix, so the legs are independent: a broken app does not hold back a sound one, and a leg whose hash hit is skipped rather than run, which is why the chain's conditions read job results and never `success()`.
`release` takes the plan's output: `publish` per app, then `deploy` per app with a target in the environment, as `_deploy.yml` nested inside it.
A promotion never builds, a run by hand on an environment branch republishes and redeploys every app from the images it finds, and a run by hand on a branch that names no environment releases nothing.

A package repo's `on_push` is `check` then `publish`, the package shape of the verb (§ 5), on its trunk; its `main` admits nothing but pull requests, so `on_commit` has nothing to run there, and the "version packages" branch is pushed with the workflow token, which starts no workflow of its own.
The platform repo's `main` takes an operator's direct pushes, so `on_commit` checks those; its `deploy` workflow deploys the third-party apps under `apps/` from `main`, every app on every push that touches `apps/`, since the deploy verb ends at once where the host already serves the app's file (§ 6), and only a changed app restarts.
`housekeeping` runs daily where the thing kept lives: in the platform repo for the tenant's throwaway instances and the registry buckets, in an app repo for the candidates it holds in the forge's registry (§ 8).

Cancellation sits on `check` and `verify` and never on `release`.
A newer push to the same ref cancels the verify still going for the older commit, whose verdict nobody waits for any more, and a cancelled verify's instances are deleted by its `cleanup`, which runs whatever the legs ended in; a `release` already started runs to its end, since a deploy cut off between migrate and up would strand the host, and deploys of one app to one host keep their own queue, at most one running and the newest waiting.

Every mount is thin: checkout, secrets plumbing, one or two invocations of a verb, and the mount's logic is the strategy expression that says where the job runs (§ 8).
`_check.yml` runs the repo's own tasks; `_verify.yml` is `plan`, `build`, `test` and `cleanup`, each one `plx-ci` invocation; `_release.yml` is `publish` and `deploy`; `_publish-package.yml` is the package shape of `publish`; `_deploy.yml` mounts `plx deploy`, `_deploy-targets.yml` mounts `plx deploy-targets` for the platform repo's `deploy`, `_housekeeping.yml` the retention; `_update.yml` and `_changeset.yml` are the mounts of [PLX-Updates](updates.md) and § 5.
The tenant's own workflows are generated by the presets and shipped on the train; a tenant repo carries no reusable workflow of its own, and the underscore says at a glance which files are triggered and which are called.
A tenant's workflows hold one secret, the CI vault's service account token; everything else a job needs is read from the vault `<owner>-ci` (§ 8, [§ 3 PLX-Secrets](secrets.md)).

GitHub Actions *is* a control plane, but one someone else operates, with git as input; that is the allowed shape.
The forge is tier-0 for deploys either way: CI is the deploy trigger and the registry holds the images, so a forge outage means no automated deploys.
What bounds the damage is the usual pair: running systems keep running and git is distributed, so an outage costs deploy availability, never data; and the verbs stay hand-runnable, so a forge-less deploy remains possible, just not convenient.
Not-self-hosting avoids *operating* tier-0, not *depending* on it; code and CI configs are not personal data, and a self-hosted forge would be a tier-0 dependency the tenant has to secure and back up before it protects anything.
Leaving GitHub means adjusting the mounts, never the logic: a tenant on another forge rewrites a few YAML files and keeps every verb.


## § 3 Environment branches and promotion

> - App repos MUST use environment branches: `main`→`production`, `develop`→`staging`; `production` and `staging` are the environment names a deploy asks the platform inventory for ([PLX-Environment](../contracts/environment.md)).
> - The platform repo SHOULD have a single `main`; environments are inventory groups, never branches.
> - Apps MUST NOT use changesets.
> - A hotfix branches from `main` and merges to `main`; it MUST be back-merged `main → develop` immediately.
> - Promotion MUST be a fast-forward of `main` to `develop`; `main` MUST NOT carry merge commits of its own.
> - A release MUST act per app and on content: an app whose inputs, its own directory plus every workspace package it depends on, did not change is neither built nor redeployed.
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

Which host an environment *is*, is inventory, not convention: `main`→`production` and `develop`→`staging` name environments, and the binding, which VM, which inventory record, which domain, lives in the platform repo's inventory ([§ 3 PLX-Platform](platform.md)), one record per app and environment, where `plan` reads it from a checkout of the tenant's platform repo made with the tenant's GitHub App ([PLX-Environment](../contracts/environment.md)).
An app without a record in an environment has no deployment there, and a push to that environment's branch releases its image and deploys nothing.
The platform repo itself needs no environment branches because it has no release cycle of its own to promote: staging and prod are two inventory groups in one file, and a playbook run targets one of them.

The model: **the unit of deployment is the app; the unit of promotion is the repo.**
A merge to an environment branch releases into that environment every app, and builds exactly the ones whose inputs changed: a docs-only merge builds nothing, a `packages/ui` change rebuilds its dependents, an unchanged app is published from the candidate the registry holds and left running where the host already serves it.
The decision is a content hash per app, Turbo's hash of the app's `build` task over its own directory and every workspace package it depends on (§ 4), one definition that covers merge commits, squash merges, multi-commit direct pushes and force-pushes identically; stateless, no bookkeeping.
Promotion builds nothing that `develop` built: an app whose candidate exists for the promoted tree is published and deployed from it (§ 2), and only an app whose inputs on `main` differ from everything the registry has seen is built again.
The hashing is the verb's, not YAML logic: `plx-ci plan` reads the workspace graph through Turbo and the registry, and prints what the run owes.

Promotion is the whole repo: `develop → main` asserts *everything on `develop` is prod-ready*, and selective promotion would put on prod a repo state that never existed on staging, destroying the one guarantee environment branches exist to give.

Two boundaries of the model.
The platform repo has no release cycle: its ops side is not an app and the deploy verb never touches it; applying it is a playbook run, its own mount, on its own occasions.
Third-party apps hosted in the platform repo are the exception that proves it: they *are* apps, so the deploy verb does touch them, mounted on the platform repo's `main` and fanned out over every app under `apps/` with a target in the inventory, the verb itself telling an unchanged app from a changed one.
And the escape valve is a repo split, not a process patch: if two products in one tenant *persistently* need independent release cadences, move one into its own repo (still inside the tenant's org and access boundary, still on the same contract).
Granularity problems are solved by moving a product into a release cycle of its own, never by making promotion partial.


## § 4 Releasing an image

> - An app's image MUST be built hermetically from its Dockerfile and pushed to the tenant's registry tagged with the git SHA it was built from.
> - The image MUST be pushed under the tenant's own organisation, with the repo's own forge token, never with a token that crosses an organisation.

This section binds app repos.
An app's image is built once per content, in `verify`, and published under its commit in `release`.
`build` builds from the Dockerfile the app contract asks for ([§ 7 PLX-App](../contracts/app.md)) and pushes the candidate to the registry (§ 8) as `build-<hash>`, Turbo's hash of the app's `build` task, which is also the build ID inside the image; `test` adds `test-<hash>`, the hash of its `test` task, to the manifest when the tests passed on it; `publish` copies the tested manifest to the tenant's forge registry under `<sha>`, which remains the reference a deploy takes, with the two hash tags beside it.
The hashes are what `plan` looks up, so a lockfile change or a force-push rebuilds nothing whose inputs did not change, and a change to specs alone re-runs the tests on the existing image.
The build is hermetic: it runs inside the Dockerfile, so the artifact is correct from any host, and what *build* means is encoded once, in the repo's task graph, which the Dockerfile invokes exactly as the `build` verb does.
It is reproducible as far as the stack allows: the context is `turbo prune --docker`, so an app's image is independent of the other apps' dependencies; the base image is pinned by digest; the build ID and the app's server-actions key are fixed from outside, the key read from the vault item `app_<name>`; timestamps are zeroed; what still drifts is measured and listed (Next's preview-mode keys, a package installed at build time), never gated.
Publishing for one platform (amd64) is the default; multi-arch is a deferred decision with a trigger, stated in the app contract.

The layer cache lives in the registry beside the candidates (`<app>:cache`), so a build on a fresh machine, the forge's runner or an instance launched for it, starts from the last build's layers and never round-trips a cache through the forge.
SHA-tagged images accumulate in the forge's registry unboundedly, which rollback and re-deploys rely on; the candidates are the retention's (§ 8).


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
An app repo's `release` runs it per app with a target in the environment, after `publish` (§ 4), from the target `plan` read in the inventory.
The platform repo's `deploy` runs it for the third-party apps under its `apps/`, from `main`, with the image already pinned in the committed file, each app's target looked up in the inventory by the `deploy-targets` verb.
Hand-run, it is `plx deploy deploy@host tenant app --image <ref>` from any checkout that has the compose file, and `plx -n deploy …` prints every ssh line it would run, which is what makes a forge-less deploy possible, with or without the tool.
The deploy host is substance: the inventory record's `plexus_deploy_target` ([PLX-Environment](../contracts/environment.md)), reachable over the tenant's overlay network or a public forward, whichever the tenant's platform provides (§ 8).
The verb ends without pulling or restarting when the host already serves the app from the same rendered file, healthy, so a promotion restarts only the apps whose image changed, and the platform repo's deploy of every app on every push restarts only the one that changed.


## § 7 Failed deploys and recovery

> - While a staging deploy is red, `develop → main` MUST NOT be merged.
> - Recovery MUST be a re-run of the failed job or a hand-run deploy of the same artifact, never an empty commit.

A failed deploy parks promotion, and recovery is named, not improvised.
The changed set carries no memory, so the pipeline never *rediscovers* a failed deploy: after the rollback and alert (§ 6), the environment branch is ahead of what actually runs, and the next unrelated merge will not close the gap.
Closing it is the operator's move, using mechanisms that already exist: re-run the failed job (same SHA, same artifact) once the cause is fixed, or invoke the hand-runnable deploy verb directly.
A red staging deploy directly falsifies `develop`'s prod-readiness, hence the promotion freeze.


## § 8 Where the jobs run

> - A repo MUST answer where its jobs run with one strategy, `github`, `on-prem` or `hybrid`, as the preset answer `ci_strategy`; the repo variable `CI_STRATEGY` MAY override it for the next run, and `github` MUST remain a working answer for every repo.
> - Every job MUST declare a size, `small`, `medium` or `large`, and ask for its runner by it: the label `ci-<size>` where the tenant's own runners serve the size, `ubuntu-latest` where the forge's do.
> - A runner of the tenant's own MUST serve only that tenant's private repos.
> - CI's credentials MUST live in the vault `<owner>-ci` ([§ 3 PLX-Secrets](secrets.md)), read with one service account token, the one CI secret a repo holds; a workflow MUST NOT be handed a secret any other way.

This section binds every repo that mounts a verb on the forge.
Three questions decide it, each a preset answer per repo and a fact rather than a secret: the **strategy**, where a job of each size runs; the **registry**, where the candidates of § 4 live; the **overlay**, how a deploy reaches the app hosts.

**Sizes.**
Every job has a size that says what machine it wants, and the sizes are the labels a job asks for: `check` is medium, since lint, typecheck and the pure tests want cores and a few gigabytes; `build` and `test` are large, a machine with Docker and the memory for an image build or a browser; `plan`, `publish`, `deploy`, `cleanup` and `housekeeping` are small, a shell with a token.
The size is the job's, and the strategy maps it to a machine.

**Strategies.**

| Strategy | small, medium | large | Registry default | What the tenant operates |
|---|---|---|---|---|
| `github` | the forge's runners (`ubuntu-latest`) | the forge's runners | `ghcr` | nothing |
| `on-prem` | container slots on a runner host of the tenant's own | a privileged slot with a Docker daemon of its own | `own` | the runner host |
| `hybrid` | container slots on a runner host of the tenant's own | a throwaway cloud instance per leg, launched by `plan` and gone after it | `own` | the runner host and a cloud account |

`github` is the default and the answer with nothing to operate: a fresh machine per job, destroyed afterwards, minutes billed beyond the free allowance, and the forge's largest machine on the free plan being `ubuntu-latest`, that is what `large` is there.
`on-prem` is a tenant with hardware to spare: every size is a slot of a runner host, and a large slot is the one container of the host that runs privileged, with a Docker daemon inside it whose state dies with the job, so the job meets an empty machine with Docker.
`hybrid` is a tenant with a small runner host and a cloud account: the small and medium jobs run on the host's slots, which cost nothing per job and pick a job up within seconds, and each large job runs on an instance of its own, launched by `plan` for that one job and deleted by `cleanup`, so no build contends with another and no large machine idles.
The strategy is the generated workflows' expression `${{ vars.CI_STRATEGY || '<answer>' }}`, so the way back while a runner host or the cloud is down is one repo variable, `CI_STRATEGY=github`, and the next run is on the forge's runners without a commit; deleting it is the way forward again.

**The registry** holds the candidates and the layer cache (§ 4).
Under `ghcr` they live beside the published images, in the forge's registry, under the tenant's organisation; the only credential is the job's own token.
Under `own` they live in a registry pair on the tenant's object storage: every job that needs it finds the CNCF distribution registry answering on loopback, the read-write registry of the current month on `:5000` and the read-only one of the previous month on `:5001`, each a container against a bucket `<owner>-ci-registry-<YYYY-MM>`.
On the forge's runners and on an instance the job starts the pair itself for its own length (`plx-ci registry`); on a runner host the host runs it, on the same ports and buckets, and the job finds it answering and starts nothing.
Retention is rotation, never garbage collection: writes go to the current month, reads consult both months, and the daily `housekeeping` creates the next month's bucket and deletes the one from two months ago whole, at the cost of one cold build per app a month.
Under `ghcr` the `housekeeping` of the app repo deletes the package versions whose only tags are candidates older than thirty days; a version carrying a commit is never deleted.
`own` also carries Turbo's remote cache for `check`, in a bucket `<owner>-ci-turbo` with a lifecycle rule, served to the job by a cache server on loopback with a token minted for the job: a task whose inputs did not change is replayed from any earlier job on any runner.

**The overlay** is how `deploy` reaches an app host that has no public SSH.
Under `none` the host is reached as the inventory names it, a public address or a forward.
Under `netbird` a job on the forge's runners joins the tenant's overlay for its length, as an ephemeral peer with a setup key from the vault whose policy allows the app hosts' SSH and nothing else, and leaves with the job; a job on a slot of a runner host joins nothing, since the slot shares the host's network and the host is on the overlay already.

**The runner host** (`on-prem` and `hybrid`) is a host of the tenant like every other, set up by the collection ([§ 2 PLX-Platform](platform.md)), the `ci_runner_host` role: a number of container slots per size, each a systemd unit that mints a just-in-time runner configuration with the tenant's GitHub App and starts a fresh container of the runner image for one job, and the next when that job ends.
Nothing registered outlives its job, no registration token is stored, and the image is the official runner's with the few packages a small or medium job expects, published from `primitives` at the train number and pinned by the role.
A small or medium slot has no Docker socket, which would be root on the host, runs under the container engine's `no-new-privileges` and a memory limit per size, so a job installs what it needs into its own home and never with `sudo`; the one thing the slots share is the host's pnpm store.
The slots register at one repository, or at the organisation in a runner group, so that every repo of the tenant uses them: the platform repo's `deploy` and `housekeeping` need a slot as much as an app repo's jobs do, and on a forge plan without runner groups the organisation's default group serves every private repo.
A change to what a slot runs, its registration, its image, its limits, restarts the slots on the next playbook run, which a job in flight on the host does not survive.
Where the runner host shares a hypervisor with production, CI is down whenever production is, and the fix that would rescue production cannot pass it; the deploy verb being hand-runnable and the fallback being one variable away is what makes that acceptable.

**The instances** of `hybrid` are the one place a job's machine exists for the job alone.
`plan` creates one per build and test leg from a stock Debian image with user-data that installs Docker and the runner, labels each with the run, the attempt and two deadlines, and waits for every runner to register; a leg's job then asks for the instance's unique label.
The instances tear themselves down in layers, so that no layer has to be the last: the runner exits after its job and the instance deletes itself; no job having started by a deadline, it deletes itself; at the death deadline it mails and deletes itself, and five minutes later powers off whatever happened; `cleanup` deletes what the run launched, and the daily `housekeeping` whatever is stopped or past its deadline.
A launched instance sometimes misses its boot; `plan` keeps it stopped under a label of its own, mails the tenant's alerts address, and launches one replacement, and `housekeeping` deletes a kept instance after fourteen days.
Because an instance exists for one job of one attempt, a failed `build` or `test` is re-run only through a re-run of the whole run, which plans and launches afresh; "re-run failed jobs" queues the job for a runner that no longer exists.
The provider's measured behaviour and its IAM are the [Exoscale field notes](exoscale.md).

**The vault** `<owner>-ci` holds what the strategy needs and nothing a workflow is handed otherwise; which items exist follows from the three answers:

| Item | Fields | Read when |
|---|---|---|
| `app_<name>` | `server-actions-key` | every build of the app, so that the candidate is reproducible |
| `github-app` | `client-id`, `private-key` | `plan` reads the platform repo's inventory for a release; the runner host's slots and the instances mint their runner configurations |
| `deploy-ssh` | an SSH key | every deploy |
| `netbird` | `setup-key` | a deploy under `github` with `netbird` |
| `bucket-registry`, `bucket-turbo` | `endpoint`, `region`, `access-key-id`, `secret-access-key` | `own`: the pair and the Turbo cache |
| `exoscale` | `ci-launch/key`, `ci-launch/secret`, `ci-selfdelete/key`, `ci-selfdelete/secret` | `hybrid`: `plan`, `cleanup` and `housekeeping` launch and delete; an instance deletes itself |
| `smtp-relay` | `host`, `port`, `username`, `password`, `from` | `hybrid`: the mails of a missed boot, a deadline, a sweep |

The GitHub App holds `Contents: read` on the platform repo, `Administration: write` on the app repo for runners at the repository or `Self-hosted runners: write` on the organisation for slots there, and is otherwise the tenant's own; a tenant under `github` with `ghcr` and no overlay holds the first three items and nothing else.
The address the strategy mails to is a fact, the preset answer `alerts_email`, passed to the workflows as an input.

Three trade-offs are named rather than implied.
The runner host persists between jobs, against "primitives should rarely remember anything": the slots are the speed gain for the small jobs, what they keep is one cache and the registry pair, and an hourly housekeeping timer on the host moves the pair to the new month's buckets and removes what the jobs leave behind.
The runner image updates with the train, since the forge stops scheduling onto a runner that falls far behind, and monthly is the floor.
And the write credentials in an instance's user-data are readable by the job that runs there, which is the same exposure as the secrets that job can read anyway, accepted for a tenant's private repos.


## Maintaining

The module folds what were four pages, PLX-CI, PLX-Release, PLX-Deploy and PLX-Packages, into one, because a reader of any of them needed the other three; the section numbers of the old pages are retired with their codes, and a citation of one of them is rewritten to the section here that carries the same content.
Train 0.111.0 gave the module its present vocabulary, the two phases of § 1 and the three workflows of § 2, and the three strategies of § 8 in one pipeline; before it there were two pipelines, `_pipeline.yml` on the forge's runners and `_pipeline-cloud.yml` on the instances, and the answers were `forge` and `cloud`, which the presets still read as `github` and `hybrid`.

The ops verbs are commands of `plx` and `plx-ci` ([PLX-CLI](cli.md)) and the reusable workflows that mount them carry no logic of their own; both ship from `plexus-ms/primitives` on the train, the tools at the train number on npm, the workflows by the train tag, so that a tenant's CI runs one number.
The layering is load-bearing:

- **Verbs** contain *all* the logic and stay hand-runnable.
  `plx-ci plan [--test] [--deploy --environment <env> --inventory <dir>]` computes the hashes, looks them up, reads the deploy targets, and prints the builds, tests and deploys the run owes, with each leg's `runs-on`; `plx-ci build <app> <hash> <sha>`, `plx-ci test <app> <build> <hash>` and `plx-ci publish <app> <build> <sha>` are the three image verbs; `plx-ci registry` makes the candidates' registry reachable and `registry rotate` is the retention; `plx-ci hybrid create-instances`, `destroy-instances` and `sweep-instances` are the instances' lifecycle; `plx-ci report` compares what the registry holds for a run.
  `plx deploy-targets [inventory]` prints each app's deploy target per environment from a platform repo's inventory and refuses an app declared with a target in two files for the same environment; `plan --deploy` uses the same reader from `@plexus-ms/lib`.
  `plx deploy <host> <tenant> <app> [--image <ref>]` is § 6: every command it sends to the host is one line of shell over a shared ssh connection, and `--dry-run` prints each line verbatim, so `git clone && plx -n deploy …` hands a stranded operator the exact commands, which is what passes the degradation test.
  Every verb reads the three answers as `CI_STRATEGY`, `CI_REGISTRY` and `CI_OVERLAY`, which the reusable workflows set from their inputs, and `--strategy` overrides the first by hand.
  All of them are tested in `plexus-ms/primitives`, the deploy verb against a fake `ssh` on `PATH` that runs each line locally in a scratch app dir with fake `docker` and `curl`, the instance verbs against a fake cloud.
  A tenant repo pins both tools in its `mise.toml` at the train number, and the train writes the pins together with the workflow refs ([§ 1 PLX-Updates](updates.md)), so the verbs a workflow asks for are the ones the pinned tools have.
- **Reusable workflows** are thin mounts: `_check.yml`, `_verify.yml` and `_release.yml`, the three the tenant's `on_*` workflows chain, `_publish-package.yml`, `_deploy.yml`, `_deploy-targets.yml`, `_housekeeping.yml`, `_update.yml` and `_changeset.yml`; actionlint checks them under `mise :verify`.
  Each job is one or two `plx-ci` or `plx` invocations around the mount's plumbing: the checkout, the vault reads for the items § 8 names, the tool installs into the job's home and never with `sudo`, and the strategy expression for `runs-on`.
  A small or medium job runs on `${{ inputs.strategy == 'github' && 'ubuntu-latest' || 'ci-<size>' }}`; a large job takes its runner from `plan`'s matrix, which is the instance's unique label under `hybrid`, `ci-large` under `on-prem` and `ubuntu-latest` under `github`.
  The result conditions of `_verify.yml` read job results and never `success()`, because a leg skipped by its hash is `skipped`, and the test job does not start in a cancelled run.
  `_deploy.yml` is nested inside `_release.yml` by its full name and the train ref, which the bookkeeping moves with every other, never by a relative `uses:`: a tenant calls the chain at a train tag, which is annotated, and the forge resolves a relative nested call to the tag object rather than its commit and fails to start the run (train 0.111.0 shipped the relative form, tried at a branch where it works, and 0.111.1 is its hotfix).
  `_changeset.yml` is the one mount that writes back to the caller: the changeset `plx changeset` owes, committed to the bot's branch, pushed with a token the caller passes so that its checks run on the new tip.
  Logic never lives in the YAML.
  GitHub's workflow format is not an open standard and the runner is self-hostable but GitHub remains the scheduler, so a workflow is forge-specific and disposable, while a verb is portable and permanent.
  The `primitives-ref` input of `_verify.yml`, `_release.yml` and `_housekeeping.yml` builds `plx-ci` from a checkout of `primitives` at that ref instead of the published package, so that a consumer's trial branch can point its `uses:` at an unreleased branch of `primitives` and run the pipeline before the train; a trial commit is marked `TRIAL:` and reverted before the ship.
- **Tenant workflows** are generated by the presets: `on_commit.yml`, `on_pr.yml`, `on_push.yml` and, under `ghcr`, `housekeeping.yml` by the web preset for an app repo; `on_pr.yml` and `on_push.yml` for a package repo (the web preset with `publishes_packages`), where `on_pr` also carries the `changeset-status` guard and the `changeset` mount; `on_commit.yml`, `on_pr.yml`, `deploy.yml` and, under `hybrid` or `own`, `housekeeping.yml` by the platform preset; plus `update.yml` from both repo presets, the mount that pulls the train ([§ 3 PLX-Updates](updates.md)).
  All reference the reusable workflows by the train tag, which the train's own pull request moves in every tenant.
  A file the preset stops generating is deleted by the train's `copier update` where the repo left it unchanged, and removed by hand on that train where it did not; 0.111.0 removed `pipeline.yml`, `verify.yml`, `release.yml` and `sweep.yml`.
  The upstream repos that are no preset's consumer (`primitives`, `compendium`) mount `_check.yml` with `tasks: verify` on every push by hand.

**The deploy verb has a fence**, and crossing it takes a deliberate, documented decision: no persistent state, no daemon, no UI, no reconciliation loop, no provisioning of platform resources at deploy time.
Inside the fence, invest freely: logging, clean rollback, good error messages.
Outside it, it is either an existing tool's job or an architecture change, not feature creep.
Zero-downtime deploys (blue-green, rolling) stay outside until an app has traffic for which a blink is a real cost; whatever the answer, it stays a verb, not a reconciler.

**Decisions**, in order, each closing a deferral written before it:

- 2026-11-04: an app repo's deploy reads the inventory itself, from a checkout of the tenant's platform repo (`<owner>/platform`, fixed by PLX-Tenancy) made with the tenant's GitHub App, which therefore holds `Contents: read` on it; the record it reads is the contract object of [PLX-Environment](../contracts/environment.md), and the web repo's `DEPLOY_HOST` variable went with the pipeline that reads it.
- 2026-11-05: the module keeps its code and § 8 carries the strategies; a split into one page per strategy would rename citations for no second reader.
  The environment branches stay `main` and `develop`: the hotfix flow, the promotion task and every page assume them, and the mount maps a branch to an environment name in one place.
- 2026-11-06, the shape of 0.111.0: the phases `verify` and `release` with the verbs inside them; one pipeline for the three strategies, with the sizes as labels; `ci_registry` and `ci_overlay` as answers of their own; `CI_STRATEGY` as the escape hatch; the platform repo's `deploy` fans the verb over every app under `apps/` and relies on the verb's no-op, so `changed-apps` is gone; the platform repo's check is `on_commit` and `on_pr` on a small runner of its strategy.
- 2026-11-08, hotfix 0.111.1: the nested `_deploy.yml` ref, above.
- 2026-11-07, at the trials of 0.111.0: `large` under `github` is `ubuntu-latest`, since the forge's larger runners need a paid plan; one role, `ci_runner_host`, serves `on-prem` and `hybrid`, the large slot being the privileged one with a Docker daemon of its own; the slots register at the organisation as soon as a second repo of the tenant needs them, which the platform repo's `housekeeping` and `deploy` do under `hybrid`; `cpu.huge` (16 vCPU) is not used for the large jobs, since it costs twice `cpu.extra-large` and would have to be twice as fast; the GHCR retention deletes versions whose only tags are candidates older than thirty days.

**Setting a tenant up**, once per tenant, by hand and recorded here until a second tenant makes a role of it.
Every strategy: the vault `<owner>-ci` with its service account token as the one CI secret of every repo, the items `app_<name>` per app, `deploy-ssh` and `github-app`, and the App itself with the permissions § 8 names; `plexus_deploy_target` on each host's record in the inventory.
`own`: a storage key with read and write on the buckets plus their creation and deletion, the bucket `<owner>-ci-turbo` with a lifecycle rule expiring objects after thirty days, and the first `<owner>-ci-registry-<YYYY-MM>`.
`on-prem` and `hybrid`: a runner host in the inventory group the role is applied to, on the overlay with a policy that lets it reach the app hosts' SSH, with the App's credentials and, under `own`, the storage key in its playbook environment, and slots by size (`ci_runner_host_slots`); a tenant that wants no upstream registry between it and its runners builds the runner image on the host from the same Dockerfile (`ci_runner_host_image_build`), which is also how an unreleased role is tried.
`hybrid`: on the cloud, two IAM roles and keys (launch: create, list, get, stop and delete instances and read templates, types, security groups and operations; self-delete: list, get and delete instances and read operations), a security group admitting SSH only, for the launch's diagnosis of a missed boot, an SSH key registered once, and a relay credential for the mails.
`netbird`: a setup key whose policy allows the app hosts' SSH and nothing else.

**How an instance ends.**
The deadlines are decided once, in `create-instances`, and written both into the instance's user-data and into its labels as absolute UTC times, so that the instance and the housekeeping read the same clock.
The layers, from the common case to the last resort:

1. The runner exits after its one job and the instance deletes itself; no mail.
2. No job started within the no-job deadline (five minutes for a builder, longer for a test runner, which waits for the build): the instance deletes itself; no mail.
   The timer is armed at boot and the deadline computed before the create call, so an instance that idles goes a minute or two after the announced time.
3. The death deadline (thirty minutes): a mail through the relay, then self-deletion; five minutes after that, a power-off without network, armed as the first cloud-init step so that it holds even when nothing after it ran.
4. The run's `cleanup` job, after every leg an instance was launched for and whatever they ended in: deletes the instances this run and attempt launched, by their labels, retrying one the cloud refuses to delete while it is still starting, and removes the runner registrations nothing connected with; what it could not delete it names, and layers 2 and 5 take.
5. The daily `housekeeping` in the platform repo: deletes every instance of the strategy that is stopped or past its death deadline, and mails when it removed something.

**The launch and the boot stall.**
A launched instance sometimes never comes online (the field notes, § 4), and a stalled boot arms no timer, so the launch is the one place that can see it in time.
`create-instances` waits 120 s for the runner to register; on a miss it keeps the instance stopped under a label of its own, mails the alerts address with the instance id and the command to inspect it, and creates one replacement from a fresh runner config; a second miss fails the plan.
`cleanup` and `housekeeping` spare a kept instance, the housekeeping mails again after seven days and deletes it after fourteen.
The first kept disk read (2026-11-06) showed a race in the user-data rather than a stalled boot, unattended-upgrades holding the dpkg lock, which the user-data now prevents (the field notes, § 4); the trap stays for whatever else misses; a create whose operation is still pending after three minutes fails the plan, and `cleanup` deletes what was launched.

**Measured**, on the first tenant's web repo (two Next.js apps and a site, 600 integration and 80 end-to-end tests), 2026-11-07:

| Strategy | Pull request, every hash missing | Pull request, every hash hit | Notes |
|---|---|---|---|
| `hybrid`, four small and one medium slot on 8 cores and 20 GB, `cpu.extra-large` instances | about 8 min | about 1 min | `check` 29 s on the medium slot; `plan` launching three instances about 90 s; a slot picks a job up in 1 to 2 s |
| `on-prem`, the same host with one large slot of 12 GB | about 9 min | about 1 min | the builds run one after another on the one large slot (1:40, 1:30, 0:55), the tests 3:07 |
| `github`, the dogfood tenant's one app | 2:30 | 1:07 for an `on_push` whose candidate existed | `check` 30 s, `plan` 16 s, the build 1:42 |

A cancelled pull request run under `hybrid` deleted its four instances within the minute.
The forge-side jobs of a pull request were four to six billed minutes on the forge's runners and are none on a runner host.

**Debts**, open as of train 0.111.0:

- Every small and medium job sets up node, `plx-ci` and the vault's CLI afresh, which is most of the 20-odd seconds a job takes on a slot; an image carrying them would save that at the price of a second pin per tool.
- A slot has twice taken 21 to 27 s to pick a job up after idling for most of an hour, unexplained.
- In a strategy's first month the previous month's registry answers 503, its bucket missing, which the jobs read as no previous cache; nothing to do, noted so that nobody chases it.
- The playbooks of two tenants on one machine install the collection into one `~/.ansible/collections`, so a hook run in one repo replaces the pin the other had installed; a repo on an unreleased collection reinstalls it with `ansible-galaxy collection install -r requirements.yml --force` before a playbook run.
- Whether the provider's IAM can restrict the self-delete key to labelled instances is unverified.
- Layer 1 cannot run when the runner's setup failed before the user `runner` exists: the runner unit's `ExecStopPost` fails on the missing user like its `ExecStart`, and layer 2 deletes the instance in its place, minutes later.
- An App installed on every repo of the organisation holds `Administration: write` wider than the one app repo the design asks for; narrowing it means a second App for CI.
- The overlay join under `github` with `netbird` has no consumer and is untested since the pipeline that carried it was retired.
- The first invoice decides whether object-storage egress and the service account's request limits need attention.
- A release version as a third tag, and where it would come from, is undecided.

Preview environments per PR are deliberately absent: a single staging per app covers most of the value, and the decision is revisited when a product has real customers (§ 6.8 PLX).

`plexus-ms/libraries` rides outside the train (§ 1.5 PLX): npm semver via changesets is its versioning, and the train number says nothing about it.
It is generated from `preset-repo-web` like a tenant's web repo and takes its arrangement from the train; `plx`, `@plexus-ms/lib` and `@plexus-ms/config` left it for `primitives`, where they are versioned by the train (§ 1.6 PLX), because they are arrangement, not application libraries.
§§ 5 and 6 carry no requirements yet: one package repo and one deploy verb are their consumers, and they gain requirements when a second consumer of each exists.
