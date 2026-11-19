---
title: PLX-Ingress – ingress
short_title: PLX-Ingress
description: One inventory record per app binds host, loopback port, and non-secret values; the platform playbook renders the proxy's routes and the app's .env from it.
code: PLX-Ingress
maturity: standard
binds: host
depends: [PLX-Platform]
consumes: [PLX-App]
order: 21
---

A reverse proxy per VM terminates TLS and maps domains to app ports.
This module is how a tenant tells the platform which app answers under which name, and how that one fact reaches both the proxy and the app's compose interpolation ([§ 4 PLX-App](../contracts/app.md)) without being stated twice.


## § 1 What the proxy reads

> - `PLX-Ingress/PrefixInRecord`: An app's path prefix, where it has one (`PLX-App/PathPrefix`), MUST be bound in its app record (`apps[].path`).
> - `PLX-Ingress/OneAppPerPrefix`: A host MUST serve at most one app per prefix and at most one at its root.

The proxy routes each app's public host (`apps[].host`) to the app's loopback port (`apps[].loopback_port`) on the same VM, both read from the app record ([§ 3 PLX-Platform](platform.md)) and stated nowhere else.
The playbook fails on a duplicate loopback port per VM.
Because host→port→app is one line in the operations repo's inventory, per-VM port uniqueness is checkable in a single file instead of being coordination state scattered across app repos.
The platform playbook renders the proxy's routes from that record, and the same record puts the port into the app's `.env` (§ 3 PLX-Platform), which is how one fact reaches both the proxy and the app's compose interpolation without being stated twice.

Apps sharing a host are told apart by path prefix, and stripping it on the way in is what the app contract promises the app (`PLX-App/PathPrefix`).
The proxy config rendered from the record is where the promise is kept, and the public URL the app needs for links reaches it through `apps[].env`.


## § 2 The proxy

The reverse proxy is Caddy, and the platform playbook writes the host's routes into one file imported by the proxy's root config, rendered from every app record of the host.
A host runs one tenant's apps and nothing else ([§ 4 PLX-Tenancy](../contracts/tenancy.md)), so there is no second writer to keep apart.
What sits in front of the VM is a host-level fact, set once in the root config.
A layer-4 ingress that routes by SNI may announce the real peer with the PROXY protocol, and a CDN's forwarded client address is believed only from that CDN's published ranges, so the app sees the actual client, and nothing bypassing the proxy can forge it.

The proxy also refuses `/healthz` from outside, for every app, and the fence is the same everywhere: the inventory has no record field for it and no per-app exception.
It is defence in depth: many apps answer their healthcheck on that conventional path, and such a route often probes a database, which is nothing to expose.
The deploy does not depend on the fence: the app contract fixes no health path, and the deploy waits for the container's health as Docker reports it ([§ 5 PLX-App](../contracts/app.md)).


## Maintaining

Two roles of `plexus.platform` carry this module: `caddy` installs and enables the server, `ingress` renders the routes after it in the platform playbook (`--tags ingress` for the routes alone).
The host-level facts (`ingress_proxy_protocol_from`, `ingress_trusted_proxies`) describe what sits in front of the host and are set per host, not per app.
Caddy is a suggested default, not part of the module's mechanics: a tenant substituting another proxy keeps the inventory record and rewrites the one role that renders routes from it, and says so in the body of its operations repo's marker.
