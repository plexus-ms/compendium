---
title: PLX-App – the app contract
short_title: PLX-App
description: What the platform asks of every deployable unit — a declaration marker, a compose.yaml as run shape, an environment, one HTTP port, a readiness healthcheck, logs on stdout, and a CI reference.
code: PLX-App
maturity: standard
binds: app
depends: [PLX-Repo]
order: 11
---

The app contract is the seam between dev and ops made explicit: the set of questions the platform asks of an app.
It is small, verb-shaped, and identical for every stack; a PayloadCMS + MongoDB app, a Prisma + Postgres app, and a non-JS Django + Postgres app all satisfy it identically.
This page is the profile-neutral base, what CI and the deploy verb rely on for *every* app.
A profile module ([PLX-AppStateless](app-stateless.md), [PLX-AppStateful](app-stateful.md)) extends it for the app's actual shape.
The sections bind the app, the dev side; where the platform owes the app something in return, the port value, the two environment files, the bullet says so.

What the contract deliberately does **not** mention: databases, ORMs, frameworks, or anything interior.
The deploy verb only needs *"is there a migration step and how do I invoke it"*, answered by `compose.yaml`: a stateful app declares a one-shot `migrate` service and the verb runs it through docker alone, so the deploy host never needs the app's toolchain.
The backup job only needs *"which services hold state and of what type"*, answered by labels.

An **app** is one deployable unit satisfying this contract.
Its **source repo**, the repo holding its `compose.yaml` and marker, is an app repo for software the tenant builds, or the tenant's platform repo for third-party software the tenant merely operates (§ 2).
The repo answers [PLX-Repo](repo.md); the four verbs the pipeline calls on an app are that contract's.


## § 1 The declaration marker

> - Every app MUST carry a `PLEXUS.md` marker at its root, `apps/<app-name>/PLEXUS.md` in its source repo.
> - The marker MUST carry YAML frontmatter with `plexus` and `modules` as the repo marker does ([§ 1 PLX-Repo](repo.md)), and `modules` MUST list exactly one profile module.
> - An app whose marker is missing or unparsable follows no module.

The repo's marker declares for the repo; the app's declares for the app.
An app's dependencies are satisfied by its own list or its repo's (§ 1.4 PLX), so an app marker typically lists this module, one profile, and the delivery approaches it rides on.


## § 2 compose.yaml

> - Every app MUST provide a `compose.yaml` declaring the app service and any app-owned infrastructure.
> - Every service in it MUST carry the label `plexus.tenant=<slug>` ([PLX-Tenancy](tenancy.md)).
> - Every app MUST have exactly one source repo: an app repo for software the tenant builds, or the platform repo, at `apps/<app-name>/`, for third-party software the tenant merely operates.
> - `compose.yaml` MUST reach the app's host directory through the deploy verb, rendered from the invoking checkout of the source repo at deploy time with the image ref pinned (§ 3); the platform playbooks MUST NOT copy it.

App-owned infrastructure means services that live and die with the app; a database container is the stateful profile's case.
The platform reads runtime truth from the host (`docker ps`, labels), never from a bookkeeping database, which is why the labels matter.

A tenant's platform is its own sovereign Vercel or Railway, and the ownership split follows that analogy exactly.
Such a platform owns env values, domains, routing, and secrets; it does not own the app's run shape, which stays in the app's repo as a Dockerfile or a `railway.toml`.
`compose.yaml` is the run shape: the migrate command, a worker service added in the same commit as the job queue, a new data service, the container port, the backup labels.
Every one of those facts changes with the code, so the file versions with the code, and dev runs the identical file locally.
Because the deploy verb runs from a checkout of the source repo, an app repo's CI or the platform repo for a third-party app, it has the file, and rendering it onto the host before `pull` means the compose file on the host always names the image being deployed.

Third-party software fits without a second mechanism: a third-party app is an app whose source repo is the platform repo.
Its `compose.yaml` and marker live at `apps/<app-name>/` there, its image is someone else's and pinned in the file, and the same deploy verb is mounted on the platform repo instead of an app repo's CI.
Same verb, two mounts.


## § 3 The environment

> - Every value the platform provides to an app MUST reach it as an environment variable, through two files in the app's host directory: `.env` for non-secret values and `.env.secret` for secrets.
> - `compose.yaml` MUST load both files via `env_file`, `.env.secret` marked optional, so the same file runs in development with a local `.env` alone.
> - Deployment values and secrets MUST NOT be committed in the source repo.
> - The `PLEXUS_` prefix is reserved for platform-provided bindings; an app MUST NOT define keys of its own under it.
> - `compose.yaml` MUST reference the app's own image as `${PLEXUS_DEPLOYMENT_IMAGE}`; the deploy verb pins the concrete ref in its place when it renders the file onto the host.

The seam is "the platform hands the app an environment", and nothing more is said about it.
What the app reads is recorded in its code; what the platform provides is recorded on the platform side, one record per app ([§ 3 PLX-Platform](../approaches/platform.md), [PLX-Secrets](../approaches/secrets.md)).
No file in between declares or validates the variables: whether an app checks its environment at startup is its interior, and a process that cannot start fails the readiness poll and is rolled back like any other bad release ([PLX-Deploy](../approaches/deploy.md)).

The reserved vocabulary is small, and each name has one provider:

| Variable | Provided by | When | How it reaches compose |
|---|---|---|---|
| `COMPOSE_PROJECT_NAME` | configure playbook, `<tenant>-<app>` | playbook run | `.env`, read implicitly |
| `PLEXUS_LOOPBACK_PORT` | configure playbook, from the app's inventory record | playbook run | `.env`, read implicitly |
| `PLEXUS_DEPLOYMENT_IMAGE` | deploy verb, from CI | deploy | pinned into `compose.yaml` |

The one asymmetry is ownership: the port has a file with an owner on the host, the image ref does not; it is the release itself, known only at deploy time.
Pinning it into the compose file, the way a third-party app's image is pinned in git, makes the on-host file the complete run shape: a human, the rotation handler, and the verb all run a bare `docker compose up -d`, and compose finds everything it needs in the directory.
`${PLEXUS_DEPLOYMENT_IMAGE:?rendered by the deploy verb}` is the recommended spelling: standard compose interpolation, and anyone running the unrendered file gets that message instead of a silent empty image.


## § 4 One HTTP port

> - The app MUST serve plain HTTP on exactly one container port, published to loopback only.
> - The app MUST NOT hardcode a host port; `compose.yaml` publishes via interpolation: `127.0.0.1:${PLEXUS_LOOPBACK_PORT}:<container-port>`.
> - An app MAY be served under a path prefix of a host it shares with other apps of the same tenant; the platform MUST strip the prefix before a request reaches the app, and the app MUST serve from its own root and take the public URL it needs for links from its environment.

The host side of the binding is not the app's to choose: the loopback port is assigned by the platform and written to the app directory by the configure playbook ([§ 3 PLX-Platform](../approaches/platform.md)).
TLS, hostnames, and the host→port binding are likewise the platform's job; public host and loopback port alike are deployment substance, so the app stays deployable under any hostname and next to any neighbour.
The binding reaches compose through the platform's `.env` in the app directory, which compose reads implicitly; the app never reads it.
The prefix is the platform's promise in the other direction: an app stays as deployable under any prefix as under any hostname because it never sees the prefix, and where it is bound (`apps[].path`) and how the proxy strips it are the platform's business ([§ 1 PLX-Ingress](../approaches/ingress.md)).


## § 5 Healthcheck

> - The app MUST expose `GET /healthz` with readiness semantics: it MUST return 200 if and only if the process can serve real requests right now.
> - The probe MUST include hard dependencies the app cannot serve without (its own database, with a short bounded timeout) and MUST NOT include soft or third-party dependencies the app survives degraded.
> - The endpoint MUST be cheap, side-effect-free, and unauthenticated.
> - The response SHOULD carry nothing beyond its status code: no version strings, no dependency names, no timings.
> - A third-party app whose image cannot serve `/healthz` MUST declare its readiness path as the label `plexus.healthz=<path>` on its app service in `compose.yaml`, with the same semantics, mirror it in the platform's inventory record so the proxy can fence it, and record the deviation in its marker.

The semantics are pinned because the deploy verb's rollback decision rides on this endpoint, polling it bare over loopback.
The label exists only for images the tenant does not build; absent the label, the verb polls `/healthz`.
The verb reads the label from the running container, but the proxy has no compose file to read, which is why the path is the one fact declared twice: once in the label, once in the inventory record.
Unauthenticated is not the same as private: ingress maps the public domain onto the same single port, so left alone `/healthz` would ride into the open as a free oracle for "is this app's database down".
The platform fences the path at the proxy ([PLX-Ingress](../approaches/ingress.md)), and the empty response is belt and braces.
Plexus deliberately does not split liveness from readiness: that distinction pays for itself only where a reconciler restarts processes on liveness, and the standard has no reconciler; one endpoint, one meaning.
Transient dependency blips are the poller's problem, and handled there.


## § 6 Logs

> - The app MUST write logs to stdout/stderr and MUST NOT manage its own log files.

Shipping and retention are the platform's job.


## § 7 CI reference

> - The app's CI MUST run check, then test, then build and push the image, each stage reaching the app only through its repo's standard verbs.
> - The app MUST provide a multi-stage Dockerfile whose build stage invokes the same task-graph entry as the `build` verb; the Dockerfile MUST NOT restate build incantations of its own.

In practice the first line is a ~5-line reference to the shared reusable workflow ([PLX-CI](../approaches/ci.md)); in a multi-app monorepo the reference is path-scoped per app ([PLX-Release](../approaches/release.md)).
The image build is hermetic: it runs inside the Dockerfile, so the artifact is correct from any host, macOS included, and a local `docker build --platform` can produce an image for any target.
Hermeticity does not duplicate the build: what *build* means is encoded once, in the task graph, and the Dockerfile is a second invocation context, the same relationship CI has to the verbs.
CI publishes for the deploy hosts' platform (amd64 today); multi-arch publishing is a deferred decision with a trigger, an ARM deploy host or the routine need to run production images on ARM laptops, and when triggered it is a workflow change (a per-platform matrix on native runners plus a manifest merge), not an architecture change.


## Maintaining

The contract stays interior-blind; a requirement that names a database, a framework, or an ORM has wandered in from a profile or an approach and goes back there.
The preset `plexus-ms/preset-app-nextjs` ships the arrangement that satisfies this page for a Next.js app: the Dockerfile, `compose.yaml` with the `web` service and the contract labels, the healthz route.
When this page changes, the preset changes in the same train.

Approaches on the platform side: [PLX-Platform](../approaches/platform.md), [PLX-Ingress](../approaches/ingress.md), [PLX-Secrets](../approaches/secrets.md), [PLX-Deploy](../approaches/deploy.md), [backups per service](../approaches/backup.md).
On the app side: [PLX-CI](../approaches/ci.md), [PLX-Release](../approaches/release.md), and the preset.
