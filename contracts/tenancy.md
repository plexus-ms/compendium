---
title: PLX-Tenancy – trust domains and tenants
short_title: PLX-Tenancy
description: How an organisation becomes a Plexus tenant — one trust domain sharing methodology and never substance, a slug threaded through every layer, one platform repo and N app repos, and written arrangements between tenants that share hardware.
code: PLX-Tenancy
maturity: standard
binds: organisation
depends: []
order: 15
---

A **tenant** is one trust domain in the federation: its own forge org, repos, hosts, secrets vault, backups.
Nominally a distinct legal person or organisation, but the boundary that matters is *access*, not legal personality; `plexus` itself is a tenant without being a distinct legal person.
This module is the contract at the seam between a tenant and the federation: what the upstream's primitives assume of a tenant, with what the tenant may assume of the upstream stated in § 1.6 PLX.
It binds the organisation, and the tenant's platform repo declares it.
The sections bind the tenant; the upstream's side stays prose in the map, since it binds the maintainers and not a consumer.

What spans the tenants is separate trust domains sharing a *methodology*, not a *runtime*: federation under a common standard, not multi-tenancy.
Nothing federates at runtime.
Tenants never talk to each other, no shared identity, no inter-instance protocol; what travels is versioned methodology from one upstream, hub-and-spoke (§ 1.6 PLX).


## § 1 Trust domain

> - All tenants MUST share the methodology: the modules of this standard and the primitives they ship.
> - Tenants MUST NOT share substance: hosts and root access, forge org and repo access, secrets vaults, databases, backups, domains.

Methodology is knowledge and code-shaped-as-knowledge; no tenant owns it.
Substance stays partitioned because the tenant is the trust boundary.


## § 2 Slug and labels

> - Every tenant MUST have a short slug (e.g. `acme`, `initech`, `plexus`).
> - Every deployed service MUST carry the label `plexus.tenant=<slug>`.
> - The slug SHOULD additionally appear consistently in the tenant's forge org name, VM hostnames, Ansible inventory groups, and vault name.

One greppable name threads through every layer.
The label makes the boundary visible exactly where it otherwise blurs: staring at a host wondering whose service this is.


## § 3 Forge layout

> - Tenant repos SHOULD be partitioned by separate forge orgs.
> - A tenant MUST hold its ops side (inventory, host definitions, playbooks, deployment configs) in exactly one repo, the platform repo; every other tenant repo is an app repo.
> - The platform repo MUST NOT hold the source of an app the tenant builds itself; it MAY hold third-party apps the tenant merely operates ([§ 2 PLX-App](../contracts/app.md)).
> - App repos SHOULD use the monorepo pattern: one repo holding `apps/` and `packages/` for one web ecosystem; a tenant SHOULD start with a single web monorepo and add a further app repo only for a product that persistently needs its own release cadence.
> - The platform repo SHOULD be named `platform` and the default web monorepo `web`; further app repos are named after their product.
> - App repos SHOULD be generated from `plexus-ms/preset-repo-web`, apps within them from `plexus-ms/preset-app-nextjs`, and the platform repo from `plexus-ms/preset-repo-platform`.

Org membership governs code access; a person in tenant A's org is simply not in tenant B's.
Inside the org, the layout follows three cardinalities: one trust domain, N release trains, one platform repo.
A **repo** is one release train and one toolchain contract ([PLX-Repo](../contracts/repo.md)) inside a tenant.
The ops side gets a repo of its own because everything about it is repo-level and unlike an app's: it rides no release train ([PLX-Train](train.md)), it is applied by playbook runs on its own occasions ([PLX-Platform](platform.md)), its dependency bumps are human-reviewed because they run as root ([PLX-Updates](updates.md)), and it holds the root playbooks and the vault pointers, so its access list is naturally the shortest in the org.
Co-locating it in one arbitrary app repo would be an asymmetry every second reader has to be told about.

Within an app repo, the monorepo's benefits remain direct: apps and the packages they share version together, cross-cutting changes land as one atomic commit, and it is safe because a repo is one access boundary.
With several apps in one repo, deploys are per-app and promotion is repo-wide; a product that persistently needs its own release cadence is the one reason to give it its own repo within the tenant's org.
Adding an app to the tenant therefore touches two repos: the app itself lands in its source repo, and its host, loopback port, and env values land as one inventory record in the platform repo ([PLX-Ingress](ingress.md)).
That is the design working, not friction: the ops-side act of binding an app to a host is explicit and reviewed.


## § 4 Arrangements between tenants

> - Tenants sharing physical hardware MUST be separated by hypervisor virtualization; two tenants MUST NOT co-mingle inside one VM.
> - Platform concerns (ingress, secrets, backups, monitoring) SHOULD be kept per-tenant as well.
> - Distinct legal persons sharing platform root access or further platform concerns MUST document the arrangement in writing: e.g. a one-page document defining the relationship, plus a data-processing agreement where applicable.

At small scale, pooling workloads on one physical host is the correct economics, and virtualization draws the boundary.
The common form is one tenant obtaining its infrastructure from another: the second tenant runs the hypervisor ([PLX-Infrastructure](infrastructure.md)), and the first tenant's VM is one of its guests.
Be clear about what that buys and what it does not: virtualization solves performance and fault isolation, but it *centralizes* access rather than partitioning it.
The hypervisor side sees everything, a hypervisor has unrestricted control over every VM, so the host is a critical attack vector, and it does nothing for legal controllership; hence the written arrangement.
Where the guest's backups ride along on the hypervisor's backup path, or its local mail goes through the relay of the tenant that runs the hypervisor, the guest tenant's platform marker records the deviation from § 4 with its reason.
Sharing ingress, networking, or secrets across tenants beyond that is a red flag: if the economics seem to force it, file an issue against the standard rather than normalizing the exception.


## Maintaining

The module introduces no role for the providing side of an arrangement; "the tenant that runs the hypervisor" is said in those words.
A term like "operator" would name a relationship the standard has exactly one instance of, and the instance is covered by § 4 as written.
The ambition of customer-1001 economics is measured here: whenever onboarding a tenant seems to force two tenants to share substance, that is a bug to file against this module, not an exception to normalize.

Approaches on the tenant's side: [PLX-Platform](../approaches/platform.md), [PLX-Infrastructure](../approaches/infrastructure.md).
On the upstream's side: the presets, `ship`, and the guarantees of § 1.6 PLX.
