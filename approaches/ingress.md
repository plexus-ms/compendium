---
title: PLX-Ingress – ingress
short_title: PLX-Ingress
description: One inventory record per app binds host, loopback port, and non-secret values; the configure playbook renders the proxy's routes and the app's .env from it, and fences /healthz at the edge.
code: PLX-Ingress
maturity: standard
binds: host
depends: [PLX-Platform, PLX-App]
order: 21
---

A reverse proxy per VM terminates TLS and maps domains to app ports.
This module is how a tenant tells the platform which app answers under which name, and how that one fact reaches both the proxy and the app's compose interpolation ([§ 4 PLX-App](../contracts/app.md)) without being stated twice.


## § 1 The inventory record

> - Each app's loopback port MUST be assigned in the tenant's inventory (`apps[].loopback_port`), in the same record that binds its public host (`apps[].host`) and names its source repo (`apps[].repo`).
> - App names MUST be unique per tenant, across all of its repos.
> - Non-secret values the platform provides to an app MUST be declared in the same record (`apps[].env`) and written to `.env`; secret values follow [PLX-Secrets](secrets.md).
> - The playbook SHOULD fail on a duplicate loopback port per VM.
> - An app MAY be served under a path prefix (`apps[].path`) of a host it shares with other apps of the same tenant; the proxy MUST strip the prefix before the request reaches the app, and a host MUST serve at most one app per prefix and at most one at its root.

Because host→port→app is one line in the platform repo's inventory, per-VM port uniqueness is checkable in a single file instead of being coordination state scattered across app repos.
The app name is the join key across repos: the inventory record, the compose project, and the host directory all key on it, which is why it is unique per tenant rather than per repo.
From that one record, the configure playbook renders the ingress config *and* injects the port into the app's compose interpolation: it writes the value to `<app_dir>/.env` on the host, the per-app directory the playbook lays out as `<deploy root>/<tenant>/<app>` (e.g. `/opt/stacks/plexus/website`), which compose reads implicitly, so the deploy verb stays port-unaware.
The same file pins the compose project name to `<tenant>-<app>`: container and network names all derive from the project name, and its directory-basename default would collide the moment two co-hosted tenants deploy an app with the same name.

Apps sharing a host are told apart by path prefix, and the prefix is stripped on the way in, so an app stays as deployable under any prefix as under any hostname: it serves from its own root and learns the public URL it needs for links from its environment (`apps[].env`).


## § 2 The proxy

> - The reverse proxy SHOULD be Caddy.
> - The proxy SHOULD refuse external requests for `/healthz`.
> - A third-party app's readiness path (`plexus.healthz`, [§ 5 PLX-App](../contracts/app.md)) MUST be mirrored as `apps[].healthz` in the inventory so the proxy can fence it.

Each tenant's configure playbook writes its routes into its own file, a per-tenant fragment imported by the proxy's root config, so tenants co-hosted on one VM never touch each other's routes.
What sits in front of the VM is a host-level fact, set once in the root config: a layer-4 ingress that routes by SNI may announce the real peer with the PROXY protocol, and a CDN's forwarded client address is believed only from that CDN's published ranges, so the app sees the actual client, and nothing bypassing the proxy can forge it.

The `/healthz` fence exists because the endpoint probes hard dependencies: routing it publicly would publish a database-status oracle.
The proxy has no compose file to read, which is why a third-party app's path is the one fact declared twice, once in the label and once in the record.
A tenant that points an external uptime monitor at `/healthz` does so as an owned deviation, recorded in its platform marker, knowing what it reveals.


## Maintaining

Two roles carry this module, split by cadence: `install_caddy` in the provision playbook, `configure_ingress` in the configure playbook.
The host-level facts (`configure_ingress_proxy_protocol_from`, `configure_ingress_trusted_proxies`) describe what sits in front of the host and are set per host, not per app.
Caddy is a suggested default, not part of the module's mechanics: a tenant substituting another proxy keeps the inventory record and rewrites the one role that renders routes from it, and records the substitution in its platform marker.
