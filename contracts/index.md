---
title: PLX Contracts
description: One page per seam — what the two sides owe each other, so that either side can be replaced without the other noticing; the profiles sharpen the app contract.
order: 2
---

A contract is the module written at a seam, the place where two sides owned by different people or tools meet ([§ 1.3 PLX](../essentials/standard.md)).
One seam, one contract; the profiles are parts of the app contract, and an app declares exactly one.
A consumer lists the contracts it satisfies in its `PLEXUS.md` marker (§ 1.4 PLX) like any other module.

| Seam | Contract | Below, providing | Above, consuming |
|---|---|---|---|
| Infrastructure to platform | [PLX-Host](host.md) | [PLX-Infrastructure](../approaches/infrastructure.md), a provider's cloud, or another tenant's hypervisor ([§ 4 PLX-Tenancy](tenancy.md)) | [PLX-Platform](../approaches/platform.md), [PLX-Deploy](../approaches/deploy.md) |
| Platform to app | [PLX-App](app.md), with one profile per app: [PLX-Stateless](stateless.md) or [PLX-Stateful](stateful.md) | [PLX-Platform](../approaches/platform.md), [PLX-Ingress](../approaches/ingress.md), [PLX-Secrets](../approaches/secrets.md), [PLX-Deploy](../approaches/deploy.md), [backups per service](../approaches/backup.md) | [PLX-CI](../approaches/ci.md), [PLX-Release](../approaches/release.md), the app preset |
| Repo to its operators | [PLX-Repo](repo.md) | the authors: [PLX-JS](../approaches/js.md), [PLX-Packages](../approaches/packages.md), [PLX-Updates](../approaches/updates.md) | [PLX-CI](../approaches/ci.md), the hooks, the staleness check (§ 13.4 PLX) |
| Tenant to federation | [PLX-Tenancy](tenancy.md) | the tenant: [PLX-Platform](../approaches/platform.md), [PLX-Infrastructure](../approaches/infrastructure.md) | the upstream: the presets, `ship`, and the guarantees of § 1.6 PLX |

For the repo seam, below and above are the authors and the operators: not layers, but two owners all the same.

| Code | Page | Maturity | Binds | Depends on |
|---|---|---|---|---|
| PLX-Repo | [the repo contract](repo.md) | standard | repo | – |
| PLX-App | [the app contract](app.md) | standard | app | PLX-Repo |
| PLX-Stateless | [the stateless profile](stateless.md) | standard | app | PLX-App |
| PLX-Stateful | [the stateful profile](stateful.md) | standard | app | PLX-App |
| PLX-Host | [the host contract](host.md) | candidate | host | – |
| PLX-Tenancy | [trust domains and tenants](tenancy.md) | standard | organisation | – |

Section numbers inside a contract are append-only within a major train, like the map's; a section is cited by number and code, "§ 2 PLX-App".
