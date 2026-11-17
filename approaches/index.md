---
title: PLX Approaches
description: One page per opinionated way to live on one side of a seam — providing a contract, consuming it, or doing a side's own job; each with a maturity and what it binds.
order: 3
---

An approach is an opinionated way to provide or consume a contract, or to do one side's own job ([§ 1.3 PLX](../essentials/standard.md)); a tenant can replace one with its own and remain a Plexus tenant as long as it keeps the contracts.
A repo takes an approach by its answers file for the approach's template (§ 1.3 PLX); the map (§ 2 to § 13 PLX) says which concern each one covers.
The columns *Depends on* and *Consumes* repeat each page's frontmatter for the reader; no tool reads them.

| Code | Page | Maturity | Binds | Depends on | Consumes |
|---|---|---|---|---|---|
| PLX-JS | [the JS/TS toolchain](js.md) | standard | repo | PLX-Repo | – |
| PLX-Delivery | [from a verified commit to a running or published artifact](delivery.md) | standard | repo | PLX-Repo | PLX-App, PLX-Host |
| PLX-Platform | [the operations platform](platform.md) | standard | host | PLX-Tenancy | PLX-Host, PLX-App |
| PLX-Ingress | [ingress](ingress.md) | standard | host | PLX-Platform | PLX-App |
| PLX-Secrets | [secrets delivery](secrets.md) | standard | host | PLX-Platform | PLX-App |
| – | [backups per service](backup.md) | note | host | PLX-Platform | PLX-App |
| – | [scheduled jobs and the dead-man's-switch](scheduling.md) | note | host | PLX-Platform | – |
| – | [host lifecycle](host-lifecycle.md) | note | host | PLX-Platform | – |
| PLX-Infrastructure | [the infrastructure layer](infrastructure.md) | candidate | host | PLX-Tenancy | – |
| PLX-Updates | [propagation and the update bot](updates.md) | standard | repo | PLX-Repo | – |
| PLX-CLI | [the Plexus CLI](cli.md) | candidate | repo | PLX-Repo | – |
| – | [Exoscale field notes](exoscale.md) | note | repo | PLX-Delivery | – |

Section numbers inside an approach are append-only within a major version, like the map's; a section is cited by number and code, "§ 2 PLX-Updates".
