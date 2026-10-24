---
title: PLX Contracts
description: One page per seam — what the two sides owe each other, so that either side can be replaced without the other noticing; the profiles sharpen the app contract.
order: 2
---

A contract is the module written at a seam, the place where two sides owned by different people or tools meet ([§ 1.3 PLX](../essentials/standard.md)).

| Seam | Contract | Below, providing | Above, consuming |
|---|---|---|---|
| Infrastructure to platform | [PLX-Host](host.md) | [PLX-Infrastructure](../approaches/infrastructure.md), a provider's cloud, or another tenant's hypervisor ([§ 4 PLX-Tenancy](tenancy.md)) | [PLX-Platform](../approaches/platform.md), [PLX-Deploy](../approaches/deploy.md) |
| Platform to app | [PLX-App](app.md), with one profile per app: [PLX-AppStateless](app-stateless.md) or [PLX-AppStateful](app-stateful.md) | [PLX-Platform](../approaches/platform.md), [PLX-Ingress](../approaches/ingress.md), [PLX-Secrets](../approaches/secrets.md), [PLX-Deploy](../approaches/deploy.md), [backups per service](../approaches/backup.md) | [PLX-CI](../approaches/ci.md), [PLX-Release](../approaches/release.md), the app preset |
| Repo to its operators | [PLX-Repo](repo.md) | the authors: [PLX-JS](../approaches/js.md), [PLX-Packages](../approaches/packages.md), [PLX-Updates](../approaches/updates.md) | [PLX-CI](../approaches/ci.md), the hooks, the staleness check (§ 13.4 PLX) |
| Tenant to federation | [PLX-Tenancy](tenancy.md) | the tenant: [PLX-Platform](../approaches/platform.md), [PLX-Infrastructure](../approaches/infrastructure.md) | the upstream: the presets, `ship`, and the guarantees of § 1.6 PLX |

