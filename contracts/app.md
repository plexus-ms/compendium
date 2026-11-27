---
title: PLX-App – the app contract
short_title: PLX-App
description: What the platform asks of every deployable unit — a marker naming its profile, a compose file as run shape, an environment, one HTTP port, a healthcheck, logs on stdout, a pipeline through the verbs — and the two profiles, stateless and stateful.
code: PLX-App
maturity: standard
binds: app
depends: [PLX-Repo]
order: 2
---

The app contract is the seam between dev and ops made explicit: the set of questions the platform asks of an app.
It is small, verb-shaped, and identical for every stack.
A PayloadCMS + MongoDB app, a Prisma + Postgres app, and a non-JS Django + Postgres app all satisfy it identically.
§§ 1 to 7 bind every app, and are what CI and the deploy verb rely on for *every* app.
§§ 8 and 9 are the two profiles, each a named variant of the contract for one recognizable shape of app; every app takes exactly one.
Each requirement says which side it binds: most bind the app, the dev side.
Where the platform or the deployer owes the app something in return, the line names them.

What the contract deliberately does **not** mention: databases, ORMs, frameworks, or anything interior.
The deploy verb only needs *"is there a migration step and how do I invoke it"*, answered by the compose file.
A stateful app declares a one-shot `migrate` service and the verb runs it through docker alone, so the deploy host never needs the app's toolchain.
The backup job only needs *"which services hold state and of what type"*, answered by labels.

An **app** is one deployable unit satisfying this contract.
Its **source repo**, the repo holding its compose file and marker, is an app repo for software the tenant builds, or the tenant's operations repo for third-party software the tenant merely operates (§ 2).
Whether an app is built or third-party follows from where it lives: an app under the operations repo's `apps/` is third-party, every other app is built.
The operations repo is the repo generated from the operations template, `plexus-ms/template-repo-operations` (§ 1.6 PLX).
That is how the tools know it, by the template its answers file names, and so how they know an app under its `apps/` as third-party.
A tenant that replaces the template says in its operations repo's marker body that it is the operations repo, and the tools do not know it.
They take the apps under its `apps/` for built apps, and `plx doctor` holds them to a built app's checks.
The repo answers [PLX-Repo](repo.md); the verbs the pipeline calls on an app are that contract's.


## § 1 The marker

> - `PLX-App/Marker`: Every app MUST carry a `PLEXUS.md` marker at its root, `apps/<app-name>/PLEXUS.md` in its source repo, whose frontmatter sets `profile` to `stateless` or `stateful`.

`plx doctor` checks `PLX-App/Marker`.

The marker's format is the one every marker has (§ 1.4 PLX); an app's alone carries `profile`.
The profile is the app's own fact and no other file states it: the platform treats every app identically through the same verbs and labels, and never needs to know it.
An app that does not meet a requirement of this page lists the requirement's name under `deviations` in its marker and gives the reason in the marker's body.


## § 2 The compose file

> - `PLX-App/Compose`: Every app MUST provide a `docker/compose.yaml` declaring the app service and any app-owned infrastructure.
> - `PLX-App/TenantLabel`: Every service in the app's compose file MUST carry the label `plexus.tenant=<slug>`.
> - `PLX-App/SourceRepo`: Every app MUST have exactly one source repo: an app repo for software the tenant builds, or the operations repo, at `apps/<app-name>/`, for third-party software the tenant merely operates.
> - `PLX-App/ComposeDelivery`: The deployer MUST bring the compose file to the app's host directory through the deploy verb, rendered from the invoking checkout of the source repo at deploy time with the image ref pinned (§ 3), and the platform playbooks MUST NOT copy it.

`plx doctor` checks of `PLX-App/Compose` that `docker/compose.yaml` exists and declares the app service, and of `PLX-App/TenantLabel` that every service carries a `plexus.tenant` label with a value, not that the value is the tenant's slug.

The **app service** is the service of the compose file named `web`; wherever this page says the app service, the deploy verb and `plx doctor` mean that service.
The compose file and the Dockerfile of a built app (§ 7) sit side by side in the app's `docker/` directory.
App-owned infrastructure means services that live and die with the app; a database container is the stateful profile's case (§ 9).
The platform reads runtime truth from the host (`docker ps`, labels), never from a bookkeeping database, which is why the labels matter.
`PLX-App/TenantLabel` is the one home of the tenant label; the slug it carries is the tenant's ([PLX-Tenancy](tenancy.md)).

A tenant's platform is its own sovereign Vercel or Railway, and the ownership split follows that analogy exactly.
Such a platform owns env values, domains, routing, and secrets; it does not own the app's run shape, which stays in the app's repo as a Dockerfile or a `railway.toml`.
The compose file is the run shape: the migrate command, a worker service added in the same commit as the job queue, a new data service, the container port, the backup labels.
Every one of those facts changes with the code, so the file versions with the code, and dev runs the identical file locally.
The deploy verb runs from a checkout of the source repo, an app repo's CI or the operations repo for a third-party app, so it has the file.
Rendering it onto the host before `pull` means the compose file on the host always names the image being deployed.

Third-party software fits without a second mechanism: a third-party app is an app whose source repo is the operations repo.
Its compose file and marker live at `apps/<app-name>/` there, its image is someone else's and pinned in the file, and the same deploy verb is mounted on the operations repo instead of an app repo's CI.
Same verb, two mounts.


## § 3 The environment

> - `PLX-App/EnvFiles`: The platform MUST provide every value it gives an app as an environment variable, through two files in the app's host directory: `.env` for non-secret values and `.env.secret` for secrets.
> - `PLX-App/EnvFileLoad`: The app's compose file MUST load both files via `env_file`, `.env.secret` marked optional.
> - `PLX-App/NoCommittedValues`: The app's source repo MUST NOT hold deployment values or secrets.
> - `PLX-App/ReservedPrefix`: The app MUST NOT define keys of its own under the prefix `PLEXUS_`, which is reserved for the bindings the platform provides.
> - `PLX-App/ImageRef`: A built app's compose file MUST reference the app's own image as `${PLEXUS_DEPLOYMENT_IMAGE}`.

`plx doctor` checks `PLX-App/EnvFileLoad` on the app service, `PLX-App/ImageRef` for a built app, and of `PLX-App/NoCommittedValues` that the source repo tracks no `.env` and no `.env.secret`.

With `.env.secret` optional, the same compose file runs in development with a local `.env` alone.
The seam is "the platform hands the app an environment", and nothing more is said about it.
What the app reads is recorded in its code; what the platform provides is recorded on the platform side, one record per app ([§ 3 PLX-Platform](../approaches/platform.md), [PLX-Secrets](../approaches/secrets.md)).
No file in between declares or validates the variables: whether an app checks its environment at startup is its interior.
A process that cannot start never turns healthy and is rolled back like any other bad release ([§ 6 PLX-Delivery](../approaches/delivery.md)).

The reserved vocabulary is small, and each name has one provider:

| Variable | Provided by | When | How it reaches compose |
|---|---|---|---|
| `COMPOSE_PROJECT_NAME` | platform playbook, the deployment's slug (§ 3 PLX-Platform) | playbook run | `.env`, read implicitly |
| `PLEXUS_LOOPBACK_PORT` | platform playbook, from the app's inventory record | playbook run | `.env`, read implicitly |
| `PLEXUS_DEPLOYMENT_IMAGE` | deploy verb, from CI | deploy | pinned into the compose file |
| `PLEXUS_DISPLAY_VERSION` | deploy verb, from CI, in a repo with display versions | deploy | pinned into the compose file, where it uses the placeholder |
| `PLEXUS_COMMIT_SHA` | deploy verb, from CI, for a built app | deploy | pinned into the compose file, where it uses the placeholder |

The one asymmetry is ownership: the port has a file with an owner on the host, the image ref does not; it is the release itself, known only at deploy time.
The deploy verb pins the concrete ref in place of `${PLEXUS_DEPLOYMENT_IMAGE}` when it renders the file onto the host, the way a third-party app's image is pinned in git.
That makes the on-host file the complete run shape: a human, the rotation handler, and the verb all run a bare `docker compose up -d`, and compose finds everything it needs in the directory.
`${PLEXUS_DEPLOYMENT_IMAGE:?rendered by the deploy verb}` is the recommended spelling: standard compose interpolation, and anyone running the unrendered file gets that message instead of a silent empty image.

The last two are optional on both sides: they say what a deployment is, its display version and the commit it was started from ([PLX-Releases](../approaches/releases.md)).
An app that wants one passes it on in its compose file, `PLEXUS_COMMIT_SHA: ${PLEXUS_COMMIT_SHA:-}`, and finds it empty where nothing hands it over, as in development.
A compose file without the placeholder is deployed as it is.


## § 4 One HTTP port

> - `PLX-App/SinglePort`: The app MUST serve plain HTTP on exactly one container port.
> - `PLX-App/LoopbackPort`: The app's compose file MUST publish that port as `127.0.0.1:${PLEXUS_LOOPBACK_PORT:?<message>}:<container-port>`, MUST publish any port of another service on `127.0.0.1` only, and MUST NOT fix a host port of its own.
> - `PLX-App/PathPrefix`: Where an app is served under a path prefix of a host it shares with other apps of the same tenant, the platform MUST strip the prefix before a request reaches the app, and the app MUST serve from its own root.

`plx doctor` checks of `PLX-App/SinglePort` that the app service publishes exactly one port, not that it speaks plain HTTP, and checks `PLX-App/LoopbackPort`.

The host side of the binding is not the app's to choose: the loopback port is assigned by the platform and written to the app directory by the platform playbook ([§ 3 PLX-Platform](../approaches/platform.md)).
TLS, hostnames, and the host→port binding are likewise the platform's job.
Public host and loopback port alike are deployment substance, so the app stays deployable under any hostname and next to any neighbour.
The binding reaches compose through the platform's `.env` in the app directory, which compose reads implicitly; the app never reads it.
The `:?` makes compose refuse the file when the variable is unset or empty: without it compose only warns and publishes on a random loopback port, where the app turns healthy and the proxy finds nothing.
`${PLEXUS_LOOPBACK_PORT:?set by the platform playbook}` is the spelling the app template renders.
A data service may publish a port for a tool on the host, on loopback and on a port compose picks, so that the proxy stays the only way in from outside.
A path prefix is the platform's promise in the other direction: an app stays as deployable under any prefix as under any hostname because it never sees the prefix.
It takes the public URL it needs for links from its environment; where the prefix is bound (`apps[].path`) and how the proxy strips it are the platform's business ([§ 1 PLX-Ingress](../approaches/ingress.md)).


## § 5 Healthcheck

> - `PLX-App/Healthcheck`: The app service MUST declare a `healthcheck` in the compose file that is cheap, free of side effects, and healthy only when the app can serve real requests.

`plx doctor` checks of `PLX-App/Healthcheck` that the app service declares a `healthcheck` with a test of its own that is not disabled.
The deploy verb applies the same test and refuses a compose file that fails it, before it reaches the host.

The deploy verb's rollback decision rides on the healthcheck: after `up` it waits for the app service's container to report `healthy`, and rolls back when it does not ([§ 6 PLX-Delivery](../approaches/delivery.md)).
Declared in the compose file, the healthcheck is part of the run shape and versions with the code.
It names no path the platform has to know, and a third-party image is checked the same way, with whatever command its image allows.

The deploy's wait is bounded, so the healthcheck's timing matters as much as its command.
Docker probes every five seconds inside the start period unless told otherwise, and every `interval` after it, so an app ready a moment after a fresh start can be seen healthy only many seconds later, or not before the wait runs out.
A `start_period` at least as long as the deploy's wait, with a short `start_interval` such as `1s`, brings the first probes within a second of a fresh start, and `interval` stays as long as the steady state wants.
`start_interval` needs Docker Engine `25.0` and Docker Compose `2.20.2` or later on the host.

What a healthcheck should cover follows from its meaning.
It includes the hard dependencies the app cannot serve without, such as its own database with a short bounded timeout, and leaves out soft or third-party dependencies the app survives degraded.
A down database fails the deploy, correctly, since the new code cannot serve, while a slow mail provider does not.
Plexus deliberately does not split liveness from readiness: that distinction pays for itself only where a reconciler restarts processes on liveness.
The standard has no reconciler; one healthcheck, one meaning.
Transient dependency blips are the waiting verb's problem, and handled there.


## § 6 Logs

> - `PLX-App/Logs`: The app MUST write its logs to stdout and stderr and MUST NOT manage log files of its own.

Shipping and retention are the platform's job.


## § 7 Pipeline and image

> - `PLX-App/Pipeline`: The app's pipeline MUST verify, then release the image, then deploy it, each stage reaching the app only through its repo's standard verbs.
> - `PLX-App/Dockerfile`: A built app MUST provide a multi-stage `docker/Dockerfile` that builds the app and its workspace dependencies.

`plx doctor` checks of `PLX-App/Dockerfile` that a built app has the file.

In practice the pipeline is the generated `on_push.yml` referencing the shared pipeline ([§ 2 PLX-Delivery](../approaches/delivery.md)).
In a multi-app monorepo the pipeline decides per app by content hash ([§ 3 PLX-Delivery](../approaches/delivery.md)).
A third-party app has no Dockerfile: its image is someone else's, pinned in its compose file.
The image build is hermetic: it runs inside the Dockerfile, so the artifact is correct from any host, macOS included, and a local `docker build --platform` can produce an image for any target.
Hermeticity does not duplicate the build: what *build* means is encoded once, in the task graph.
The Dockerfile's build stage invokes the same entry as the `build` verb, a second invocation context, the same relationship CI has to the verbs.
The release publishes for the deploy hosts' platform (amd64); multi-arch publishing is a deferred decision (§ 6.7 PLX).


## § 8 The stateless profile

> - `PLX-App/Stateless/NoState`: A stateless app's compose file MUST declare no `migrate` service and no `plexus.backup` label.

`plx doctor` checks `PLX-App/Stateless/NoState`.

The stateless profile is for apps holding no state of their own: static and marketing sites, stateless APIs.
Such an app has no data services and needs no seed.
The deploy verb checks the compose file for a `migrate` service, finds none, and moves on: uniform handling, with no knowledge of the profile.
A stateless app degrades gracefully by construction: the host is fully reconstructable from git plus the image registry, with no data to restore.


## § 9 The stateful profile

The stateful profile is for apps backed by one or more data services of their own, the common case.
Its requirements are those of §§ 9.1 to 9.3, in addition to §§ 1 to 7.

### § 9.1 Data services

> - `PLX-App/Stateful/BackupLabel`: Once the `plexus.platform` collection ships per-service backups, a stateful app's data services MUST carry the label `plexus.backup=<type>`, a type being valid exactly when the collection ships a backup handler for it.
> - `PLX-App/Stateful/OwnDatabase`: A stateful app SHOULD default to one database container of its own.

`PLX-App/Stateful/BackupLabel` is not in force while no handler exists: the backup job that reads the labels is still a note ([backups per service](../approaches/backup.md)).
Once the handlers ship, the job discovers what to dump by reading the labels, so a newly deployed app is covered with zero bookkeeping.
Extending the backup vocabulary means adding one handler upstream, after which every app using that data-service type is covered.
A database container of the app's own gives full isolation and dies with the app.

A data service keeps its data in a named Docker volume, not in a bind-mounted directory under the app directory.
The first start of a bind mount has Docker create the directory as root, and an image whose process runs unprivileged (Postgres as its own user, an object store as uid 10001) cannot write it.
Every first start on a host would need a `chown` by hand that the platform playbook would otherwise have to know per image.
A named volume is created with the ownership of the image's mount point, and needs no directory and no chown.
Backups do not care: whole-machine backups take the volumes with the guest ([§ 3 PLX-Infrastructure](../approaches/infrastructure.md)), and the per-service backup dumps through the container, never from the directory.
An app that keeps a data service in a bind directory moves it to a named volume once per host, with the stack stopped.
The move is: create the volume, copy the directory into it with ownership preserved, and bring the stack up on the new file.

### § 9.2 Migration

> - `PLX-App/Stateful/MigrateService`: A stateful app's compose file MUST declare a one-shot `migrate` service that runs the app's migration command on the app's own image, under `profiles: ["migrate"]` so that a plain `up` never starts it.
> - `PLX-App/Stateful/MigrateIdempotent`: Running `migrate` against a fully migrated schema MUST be a no-op.
> - `PLX-App/Stateful/MigrateResumable`: A `migrate` that fails partway MUST leave the schema in a state from which re-running `migrate` completes.
> - `PLX-App/Stateful/MigrateConcurrent`: Concurrent `migrate` invocations MUST NOT corrupt the schema.
> - `PLX-App/Stateful/ExpandContract`: Every migration MUST be backward-compatible with the release currently in production.
> - `PLX-App/Stateful/BreakingMigration`: Whoever deploys a migration that cannot be backward-compatible MUST deploy it as a deliberate act, with a fresh backup taken first.

`plx doctor` checks of `PLX-App/Stateful/MigrateService` that a `migrate` service under `profiles: ["migrate"]` runs on the app service's image.

`migrate` is the one contract step the deploy pipeline invokes against production data, hence the precision.
It runs as a container from the very image being deployed (`docker compose run --rm migrate`, [§ 6 PLX-Delivery](../approaches/delivery.md)).
The image carries its own migration tooling, dev runs the identical step with the identical command, and the deploy host needs docker and nothing else.
Idempotence means already-applied steps are skipped, and resumability is easiest where each step is applied atomically, as far as the database supports it.
Concurrency is usually handled by a lock, which mainstream migration tools take out of the box, so that requirement is usually just *don't disable it*.

The deploy flow has no down-migration step, and its rollback path re-launches the *previous* image against the *already-migrated* schema.
That is sound only if additive changes (new tables, nullable columns, backfills) ship first, and destructive ones (drops, renames, constraint tightening) only in a later release, once no deployed code depends on the old shape.
That is expand/contract, roll-forward only.
A migration that cannot honour that discipline is the exception `PLX-App/Stateful/BreakingMigration` names, and whoever deploys it knows that reverting means restoring, not re-upping the previous tag.

A third-party image that migrates its own schema on startup and offers no separate migrate step does not fit § 9.2 as written.
An app in that position lists `PLX-App/Stateful/MigrateService` under `deviations` in its marker until the profile settles how such an image fits.

### § 9.3 Seed

> - `PLX-App/Stateful/Seed`: A stateful app MUST provide a `seed` entry point that loads development sample data, and the deploy verb MUST NOT run it.

`plx doctor` checks of `PLX-App/Stateful/Seed`, where the app is a JS app, that its `package.json` has a `seed` script.

The contract names no stack, so it names no file for the entry point; a JS app spells it as a `seed` script in its `package.json` ([PLX-JS](../approaches/js.md)).
The seed may assume a fresh database, right after `migrate`.
Production data arrives by restore or by real use, never by seed.


## Maintaining

The contract stays interior-blind; a requirement that names a database, a framework, or an ORM has wandered in from an approach and goes back there.
A profile holds what distinguishes its shape; anything true of every app belongs in §§ 1 to 7.
The template `plexus-ms/template-app-nextjs` ships the arrangement that satisfies this page for a Next.js app: the Dockerfile, the compose file with the `web` service, the contract labels and its healthcheck.
When this page changes, the template changes in the same version.
The stateful profile is written against the one migration path the deploy verb has.
A change to how the verb runs `migrate` ([§ 6 PLX-Delivery](../approaches/delivery.md)) is a change to § 9.2 here, in the same version.

Approaches on the platform side: [PLX-Platform](../approaches/platform.md), [PLX-Ingress](../approaches/ingress.md), [PLX-Secrets](../approaches/secrets.md), [§ 6 PLX-Delivery](../approaches/delivery.md), [backups per service](../approaches/backup.md).
On the app side: [PLX-Delivery](../approaches/delivery.md) and the template.
