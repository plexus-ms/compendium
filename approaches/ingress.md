---
title: PLX-Ingress – ingress
short_title: PLX-Ingress
description: One inventory record per app binds host, loopback port, and non-secret values; the configure playbook renders the proxy's routes and the app's .env from it, and fences /healthz at the edge.
code: PLX-Ingress
maturity: standard
binds: host
changed: 0.60.0
depends: [PLX-Platform]
consumes: [PLX-App]
order: 21
---

A reverse proxy per VM terminates TLS and maps domains to app ports.
This module is how a tenant tells the platform which app answers under which name, and how that one fact reaches both the proxy and the app's compose interpolation ([§ 4 PLX-App](../contracts/app.md)) without being stated twice.


## § 1 What the proxy reads

> - The proxy MUST route each app's public host (`apps[].host`) to the app's loopback port (`apps[].loopback_port`) on the same VM, both read from the app record ([§ 3 PLX-Platform](platform.md)) and stated nowhere else.
> - The playbook SHOULD fail on a duplicate loopback port per VM.
> - An app's path prefix, where it has one ([§ 4 PLX-App](../contracts/app.md)), MUST be bound in the same record (`apps[].path`); a host MUST serve at most one app per prefix and at most one at its root.

Because host→port→app is one line in the platform repo's inventory, per-VM port uniqueness is checkable in a single file instead of being coordination state scattered across app repos.
The configure playbook renders the proxy's routes from that record, and the same record puts the port into the app's `.env` (§ 3 PLX-Platform), which is how one fact reaches both the proxy and the app's compose interpolation without being stated twice.

Apps sharing a host are told apart by path prefix, and stripping it on the way in is what the app contract promises the app (§ 4 PLX-App); the proxy config rendered from the record is where the promise is kept, and the public URL the app needs for links reaches it through `apps[].env`.


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
