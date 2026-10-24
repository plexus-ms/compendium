---
title: PLX Contracts
description: Contracts are essential modules that glue two sides of a seam together. Like a shared interface, they define the expectations and guarantees of both sides.
order: 2
---

A contract is the module written at a seam, the place where two sides owned by different people or tools meet ([§ 1.3 PLX](../essentials/standard.md)).

| Seam and Contract | Below, providing | Above, consuming |
|---|---|---|
| Tenant to federation: [PLX-Tenancy](tenancy.md) | the tenant: [PLX-Platform](../approaches/platform.md), [PLX-Infrastructure](../approaches/infrastructure.md) | the Plexus upstream and all of its primitives |
| Repo to its operators: [PLX-Repo](repo.md) | the authors: [PLX-JS](../approaches/js.md), [PLX-Packages](../approaches/packages.md), [PLX-Updates](../approaches/updates.md) | [PLX-CI](../approaches/ci.md), the hooks, the staleness check (§ 13.4 PLX) |
| Platform to app: [PLX-App](app.md) | [PLX-Platform](../approaches/platform.md), [PLX-Ingress](../approaches/ingress.md), [PLX-Secrets](../approaches/secrets.md), [PLX-Deploy](../approaches/deploy.md), [backups per service](../approaches/backup.md) | [PLX-CI](../approaches/ci.md), [PLX-Release](../approaches/release.md), the app preset |
| Infrastructure to platform: [PLX-Host](host.md) | [PLX-Infrastructure](../approaches/infrastructure.md), a provider's cloud, or another tenant's hypervisor ([§ 4 PLX-Tenancy](tenancy.md)) | [PLX-Platform](../approaches/platform.md), [PLX-Deploy](../approaches/deploy.md) |

