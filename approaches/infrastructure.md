---
title: PLX-Infrastructure – the infrastructure layer
short_title: PLX-Infrastructure
description: Hosts on hardware of a tenant's own — a Proxmox hypervisor, guests created from stock Debian, a backup server for them, and an ingress VM sharing one public address — as roles in a third playbook of the platform repo.
code: PLX-Infrastructure
maturity: candidate
binds: host
depends: [PLX-Tenancy]
order: 26
---

The **infrastructure layer** is what makes a tenant's hosts exist, reachable, and restorable: bought from a provider, or built by the tenant on hardware of its own.
A tenant on a provider's cloud has nothing to do here; the operations platform ([PLX-Platform](platform.md)) starts on top of a host that exists either way.
This module is the second case: the roles the `plexus.platform` collection ships for a hypervisor, its guests, a backup server for them, and an ingress VM, and the third playbook of the platform repo that mounts them.
It is an approach at candidate maturity: one tenant runs it, which is one short of the bar for requirements.


## § 1 The playbook

`plexus-ms/preset-repo-platform` generates `infrastructure.yml` on request, off by default.
It runs before the other two playbooks and targets different hosts, the inventory groups `proxmox`, `pbs`, `haproxy`, and `guests` for every VM on the hypervisor, the ingress VM included.
Its plays are the host baseline on the infrastructure layer's own hosts (the same roles the provision playbook uses, which is why they appear in both), the hypervisor (`configure_proxmox`, `configure_guests`), the backup server (`configure_pbs`), the ingress VM (`configure_haproxy`), and what the infrastructure layer itself needs from every guest (the guest agent that lets a backup freeze the file systems, the overlay network the guest is reached over from then on).

A fresh infrastructure host is reached as root once and joins the overlay with a use-once setup key from the environment.
A new guest takes two runs: the first creates it on the hypervisor, the second reaches it as its first admin on the address it was given and joins it to the overlay; a guest without a public address is reached through the ingress VM as jump host.
During an outage run only the play that is needed, never the whole playbook against the hypervisor.


## § 2 The hypervisor and its guests

The hypervisor is Proxmox VE on Debian: web UI and API bound to the overlay interface, root disabled for the UI in favour of the admins' own accounts, a datacenter-level default-drop firewall whose management rules are pinned to the overlay network rather than the hoster's public neighbourhood, storage, a guest bridge, and the backup jobs that push every guest to the backup server.

Guests are created from the stock Debian cloud image: no template VM and no image of the tenant's own.
Proxmox's built-in cloud-init gives a new guest its name, its network, and one admin account; everything else is the roles' job, on the first playbook run against the guest.
The guest list is inventory (`configure_guests_list`: id, name, cores, memory, disk, networks), and a guest that exists is left alone.

That last sentence is the one trade-off this layer makes against the principle that state lives in git: the hypervisor's control plane keeps the runtime state of its guests, what exists, what is running, where the disks are, below the platform, and the roles read it from there rather than reconciling it.
The guest list in git is intent; `qm list` is truth, exactly as `docker ps` is truth above the platform.
A guest destroyed on the hypervisor without purging drops out of the backup job the role configured and the role does not put it back, which is why deletion is a supervised act.


## § 3 The backup server and the ingress VM

Proxmox Backup Server runs on a plain Debian host, the server package only.
It listens on every address and cannot be bound to one, so the host firewall keeps it off the public interface and admits its port only on trusted interfaces; the hypervisor pushes guest backups to it, into one datastore with a namespace per tenant whose guests land there.
Pruning, garbage collection, and verification run on the server's own schedule; the clients may only add.
Together with an off-site copy, this is the whole-machine backup path that covers a tenant's data until [backups per service](backup.md) ship.

The ingress VM holds the one public IPv4 address, routes inbound TCP to the tenant VMs on an internal bridge, and is their gateway and NAT for outbound traffic.
It terminates nothing: 443 is routed by TLS SNI and 80 by the Host header, so every tenant VM keeps its own Caddy and certificates ([PLX-Ingress](ingress.md)), and the PROXY protocol carries the real peer to them.
A public port per VM forwards to its SSH for deploys.

A guest of another tenant on the same hypervisor is an arrangement between tenants ([§ 4 PLX-Tenancy](../contracts/tenancy.md)): the hypervisor side sees everything, so the arrangement is written down, and the guest tenant's marker records what rides along.


## Maintaining

Known debts, to be paid in this module: the backup-server and notification resources are created and never updated by the roles; the backup token and encryption key are made by hand; the local-mail role mails on every failed unit; one deploy host serves all third-party apps of a platform repo.
The roles stay the single encoding of the hosts: no image, no template, no hand step before the first run.
Field notes on Proxmox on Debian live in the compendium's miscellaneous section; what applies generally moves into the roles, what is one host's history stays in that tenant's repo.
