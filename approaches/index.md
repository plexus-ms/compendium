---
title: PLX Approaches
description: One page per opinionated way to live on one side of a seam — providing a contract, consuming it, or doing a side's own job; each with a maturity and what it binds.
order: 3
---

An approach is an opinionated way to provide or consume a contract, or to do one side's own job ([§ 1.3 PLX](../plexus/standard.md)); a tenant can replace one with its own and remain a Plexus tenant as long as it keeps the contracts.
A consumer lists the approaches it follows in its `PLEXUS.md` marker (§ 1.4 PLX); the map (§ 2 to § 13 PLX) says which concern each one covers.

| Code | Page | Maturity | Binds | Depends on |
|---|---|---|---|---|
| PLX-JS | [the JS/TS toolchain](js.md) | standard | repo | PLX-Repo |
| PLX-Release | [the release model](release.md) | standard | repo | PLX-App |
| PLX-CI | [the shared pipeline](ci.md) | standard | repo | PLX-Repo, PLX-App, PLX-Release, PLX-Deploy |
| PLX-Deploy | [deploy semantics](deploy.md) | candidate | app | PLX-App, PLX-Host |
| PLX-Platform | [the operations platform](platform.md) | standard | host | PLX-Host, PLX-Tenancy, PLX-App |
| PLX-Ingress | [ingress](ingress.md) | standard | host | PLX-Platform, PLX-App |
| PLX-Secrets | [secrets delivery](secrets.md) | standard | host | PLX-Platform, PLX-App |
| – | [backups per service](backup.md) | note | host | PLX-Platform, PLX-Stateful |
| – | [scheduled jobs and the dead-man's-switch](scheduling.md) | note | host | PLX-Platform |
| – | [host lifecycle](host-lifecycle.md) | note | host | PLX-Platform |
| PLX-Infrastructure | [the infrastructure layer](infrastructure.md) | candidate | host | PLX-Tenancy |
| PLX-Updates | [propagation and the update bot](updates.md) | standard | repo | PLX-Repo |
| PLX-Packages | [releasing packages](packages.md) | candidate | repo | PLX-Repo, PLX-JS |

Section numbers inside an approach are append-only within a major train, like the map's; a section is cited by number and code, "§ 2 PLX-Updates".
