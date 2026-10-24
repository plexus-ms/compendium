---
title: PLX-Deploy – deploy semantics
short_title: PLX-Deploy
description: What the shared deploy verb does — render the compose file with the image pinned, pull, migrate, swap, up, poll readiness, roll back on failure — and the fence around it.
code: PLX-Deploy
maturity: candidate
binds: app
depends: []
consumes: [PLX-App, PLX-Host]
order: 19
---

This module describes what the shared deploy verb (`plexus-ms/ci-cd`, `scripts/deploy.sh`) does, so the contract requirements riding on it ([§ 5 PLX-App](../contracts/app.md), [§ 2 PLX-AppStateful](../contracts/app-stateful.md)) make sense.
It is an approach: one verb, shipped and consumed, whose behaviour is documented here rather than required.
The contracts it serves are what carry requirements.

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


## § 1 What the verb does

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

The verb also renders the app's `compose.yaml` from the invoking checkout onto the host, pinning the image ref in place of `${PLEXUS_DEPLOYMENT_IMAGE}`.
That is inside the fence: the file is read from git, the ref is the verb's own argument, and nothing is stored anywhere else.


## § 2 The two mounts

The verb has one name and two mounts.
An app repo's CI runs it per changed app after the image is pushed ([PLX-CI](ci.md)).
The platform repo's workflow runs it for the third-party apps under its `apps/`, from `main`, with the image already pinned in the committed file.
Hand-run, it is `./scripts/deploy.sh deploy@host tenant app image` from any checkout that has the compose file, which is what makes a forge-less deploy possible.


## Maintaining

**The deploy verb has a fence**, and crossing it takes a deliberate, documented decision: no persistent state, no daemon, no UI, no reconciliation loop, no provisioning of platform resources at deploy time.
Inside the fence, invest freely: logging, clean rollback, good error messages.
Outside it, it is either an existing tool's job or an architecture change, not feature creep.

Zero-downtime deploys (blue-green, rolling) stay outside until an app has traffic for which a blink is a real cost; whatever the answer, it stays a verb, not a reconciler.
Registry image retention is likewise untouched by the verb: SHA-tagged images accumulate in GHCR unboundedly, which rollback and re-deploys rely on (§ 6.7 PLX).

The verb's remote half is tested offline: extract the heredoc, prepend strict mode, run it against a scratch directory with fake `docker` and `curl` scripts on `PATH`, and exercise the failure and rollback paths.
`mise :check` in `ci-cd` runs shellcheck over every verb and its remote heredoc.
