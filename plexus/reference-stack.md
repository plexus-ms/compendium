---
title: The reference stack
short_title: Reference stack
description: The module composition each release train is actually tested against — what the dogfood tenant and a second tenant declare, repo by repo.
version: v0
timestamp: 2026-10-23
order: 2
---

The train is the tested set (§ 1.5 PLX): the only combination of modules ever validated is the one running in production when the train is cut.
This page says what that combination is, so a consumer can tell which modules have been exercised together and which of its own compositions nobody has run yet.
It is maintained by hand when a tenant's declarations change, and it names the dogfood tenant; the second tenant is counted and not named, since its substance is its own.

Maturity follows from this page (§ 1.3 PLX): a module two tenants run can carry requirements, a module one tenant runs cannot.


## The dogfood tenant `plexus`

The tenant that runs plexus-ms.org, in its own organisation `plexus-ms-tenant`, on one VM that is a guest of the second tenant's hypervisor under a written arrangement ([§ 4 PLX-Tenancy](modules/tenancy.md)).

| Repo | Declares |
|---|---|
| `platform` | PLX-Repo, PLX-Tenancy, PLX-Platform, PLX-Ingress, PLX-Secrets, PLX-Scheduling, PLX-HostLifecycle, PLX-Updates |
| `web` | PLX-Repo, PLX-JS, PLX-Train, PLX-CI, PLX-Updates |
| `web/apps/website` | PLX-App, PLX-Stateless, PLX-Deploy |

The platform repo holds no third-party app.
The host declares nothing itself; its backups ride along on the hosting tenant's path, recorded as a deviation in the platform marker.


## A second tenant

A company tenant on hardware of its own: a hypervisor with four guests, a backup server, and an ingress VM, run from its platform repo's `hosting.yml`.

| Repo | Declares |
|---|---|
| `platform` | PLX-Repo, PLX-Tenancy, PLX-Platform, PLX-Ingress, PLX-Secrets, PLX-Scheduling, PLX-HostLifecycle, PLX-Hosting, PLX-Updates |
| `platform/apps/<identity provider>` | PLX-App, PLX-Stateful, PLX-Deploy, with the self-migrating image and the SQLite state recorded as deviations ([§ 2 PLX-Stateful](modules/stateful.md)) |
| `web` | PLX-Repo, PLX-JS, PLX-Train, PLX-CI, PLX-Updates |
| `web/apps/<marketing site>` | PLX-App, PLX-Stateless, PLX-Deploy |
| `web/apps/<product site>` | PLX-App, PLX-Stateful, PLX-Deploy |
| `web/apps/<product>` | PLX-App, PLX-Stateful, PLX-Deploy |

Whole-machine backups with hand-drilled restores are what covers this tenant's data until [backups per service](modules/backup.md) ship.


## The maintainers' own repos

The `plexus-ms` organisation consumes the modules that bind its own repos: every release repo and the compendium declare PLX-Repo, `packages` declares PLX-JS and PLX-Packages, and the presets ship the arrangements PLX-JS and PLX-Platform describe.


## What follows from it

| Module | Consumers | Maturity |
|---|---|---|
| PLX-Repo, PLX-App, PLX-Stateless, PLX-Stateful, PLX-Tenancy, PLX-JS, PLX-Train, PLX-CI, PLX-Platform, PLX-Ingress, PLX-Secrets, PLX-Updates | two tenants | standard |
| PLX-Deploy, PLX-Scheduling, PLX-HostLifecycle | two tenants, no settled requirement yet | approach |
| PLX-Hosting | one tenant | approach |
| PLX-Host | one hosting layer on each side | approach |
| PLX-Packages | the maintainers' one package monorepo | approach |
| backups per service | nothing shipped | note |

A module listed at approach maturity with two consumers is one whose requirements have not been argued yet, not one lacking consumers; its page's Maintaining section says what promotes it.
