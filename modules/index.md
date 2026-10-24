---
title: PLX Modules
description: One page per concern a consumer adopts on its own — contracts at the seams, approaches around them, each with a kind, a maturity, and what it binds.
order: 2
---

A module covers one concern a consumer could adopt or reject on its own ([§ 1.3 PLX](../plexus/standard.md)).
A consumer lists the codes it follows in its `PLEXUS.md` marker (§ 1.4 PLX); the map (§ 2 to § 13 PLX) says which concern each module covers.

| Code | Page | Kind | Maturity | Binds | Depends on |
|---|---|---|---|---|---|
| PLX-Repo | [the repo contract](repo.md) | contract | standard | repo | – |
| PLX-App | [the app contract](app.md) | contract | standard | app | PLX-Repo |
| PLX-Stateless | [the stateless profile](stateless.md) | contract | standard | app | PLX-App |
| PLX-Stateful | [the stateful profile](stateful.md) | contract | standard | app | PLX-App |
| PLX-Host | [the host contract](host.md) | contract | approach | host | – |
| PLX-Tenancy | [trust domains and tenants](tenancy.md) | approach | standard | organisation | – |
| PLX-JS | [the JS/TS toolchain](js.md) | approach | standard | repo | PLX-Repo |
| PLX-Train | [environment branches and the release train](train.md) | approach | standard | repo | PLX-App |
| PLX-CI | [the shared pipeline](ci.md) | approach | standard | repo | PLX-Repo, PLX-App, PLX-Train, PLX-Deploy |
| PLX-Deploy | [deploy semantics](deploy.md) | approach | approach | app | PLX-App, PLX-Host |
| PLX-Platform | [the operations platform](platform.md) | approach | standard | host | PLX-Host, PLX-Tenancy |
| PLX-Ingress | [ingress](ingress.md) | approach | standard | host | PLX-Platform, PLX-App |
| PLX-Secrets | [secrets delivery](secrets.md) | approach | standard | host | PLX-Platform, PLX-App |
| – | [backups per service](backup.md) | approach | note | host | PLX-Platform, PLX-Stateful |
| PLX-Scheduling | [scheduled jobs and the dead-man's-switch](scheduling.md) | approach | approach | host | PLX-Platform |
| PLX-HostLifecycle | [host lifecycle](host-lifecycle.md) | approach | approach | host | PLX-Platform |
| PLX-Hosting | [the hosting layer](hosting.md) | approach | approach | host | PLX-Tenancy |
| PLX-Updates | [propagation and the update bot](updates.md) | approach | standard | repo | PLX-Repo |
| PLX-Packages | [releasing packages](packages.md) | approach | approach | repo | PLX-Repo, PLX-JS |

Section numbers inside a module are append-only within a major train, like the map's; a module section is cited by number and code, "§ 2 PLX-App".
