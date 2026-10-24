---
title: PLX-Host – the host contract
short_title: PLX-Host
description: What the operations platform assumes of a host before its first playbook run — a Debian machine an operator can reach over SSH, with an address the world or an ingress can reach.
code: PLX-Host
kind: contract
maturity: approach
binds: host
depends: []
order: 14
---

The host contract sits at the seam between the infrastructure layer and the operations platform.
Below it, something makes a machine exist, reachable, and restorable: a provider's cloud, or a tenant's own hardware run with [PLX-Infrastructure](infrastructure.md).
Above it, the platform playbooks ([PLX-Platform](platform.md)) turn the machine into a tenant's app host.
The contract is what the upper side assumes of the lower, and it is written informatively for now: it has one implementation on each side and no requirement has had to be argued yet.
The maturity rule (§ 1.3 PLX) promotes it the day one does.


## § 1 What the platform assumes

A host is a Debian machine, the current stable release, with a stock kernel and no configuration management of its own.
It is reachable over SSH on an address the operator's machine can connect to: a public one, an overlay network's, or an internal one through a jump host the operator can also reach.
It is reached once as root with the operator's key, after which the provision playbook creates personal admin accounts and closes root logins; nothing on the host is set up by hand before that first run.
It has a stable hostname that the platform treats as the host's name in the inventory.
It has outbound internet access for packages, container images, and the overlay or vault endpoints the roles talk to.
Inbound, ports 80 and 443 reach it from the public internet, directly on a public address or through a layer-4 ingress that routes by SNI and Host header and announces the real peer with the PROXY protocol ([PLX-Ingress](ingress.md) believes that announcement only from configured sources).
Its disk holds the container images, the app directories, and whatever data the apps keep on the host; sizing is the tenant's call, and the standard says nothing about it.

Everything else is the platform's job and belongs to no contract: the roles install the container engine, the proxy, the firewall, the admins and the deploy user, and they are the single encoding of a host's setup.
A machine image carries only what has to exist before the first SSH login.


## § 2 What the infrastructure layer is told

The platform asks nothing of how the host came to be, and the infrastructure layer asks only two things back: which guests to create and how to reach them.
Both are inventory, in the tenant's platform repo.
A host that stops meeting § 1, a release upgrade or a changed address, is a infrastructure-layer change first and a platform re-run second, in that order.


## Maintaining

Keep this page a list of assumptions the platform roles actually make, verified against them when a role changes what it needs; an assumption no role relies on is deleted, not kept for completeness.
A requirement arrives here when two implementations of the lower side disagree about something the roles depend on, and the page is promoted to standard maturity in that train.
