---
title: PLX-Platform – the operations platform
short_title: PLX-Platform
description: A tenant's hosts as code — the plexus.platform Ansible collection mounted as two playbooks split by change cadence, provision and configure, and the roles that make a Debian machine a tenant's app host.
code: PLX-Platform
maturity: standard
binds: host
depends: [PLX-Host, PLX-Tenancy]
order: 20
---

A CI/CD system needs state (what exists), events (something changed), and procedures (make it so).
Plexus puts state in git and in tools it does not author, takes events from systems someone else operates, and runs only stateless procedures.
The operations platform is the part of that model that touches hosts: the `plexus.platform` Ansible collection as the shared logic core, and each tenant's platform repo as the mount, holding only the binding (playbooks as role lists, inventory, group vars, the committed `op://`-pointer env files).
A tenant playbook is to the roles what a workflow wrapper is to a verb: a mount, not logic.

The platform starts on top of a host that exists ([PLX-Host](../contracts/host.md)); how it comes to exist is the infrastructure layer's business ([PLX-Infrastructure](infrastructure.md) for tenants on hardware of their own), and this module is the same either way.
Ingress ([PLX-Ingress](ingress.md)), secrets delivery ([PLX-Secrets](secrets.md)), scheduling ([PLX-Scheduling](scheduling.md)), and host lifecycle ([PLX-HostLifecycle](host-lifecycle.md)) are the roles' concerns a tenant adopts on top of the two playbooks, each a module of its own.


## § 1 The two playbooks

> - The tenant MUST mount the platform, in its platform repo, as two playbooks: a provision playbook (base host setup: packages, hardening, container engine, ingress-server install) and a configure playbook (ingress routes, app configuration, secrets, container re-creation).
> - For any one host, a role MUST belong wholly to one playbook; the configure playbook MUST be re-runnable at any time against a provisioned host.

The split is by change cadence, not by component: the provision playbook is for fresh hosts and deep-reaching changes, the configure playbook is the everyday pass.
Where one component spans both cadences (the ingress server), it is split into two roles rather than sliced with tags.
The configure playbook is deliberately not called a deploy: deploying is the verb's act ([PLX-Deploy](deploy.md)), keyed by an image, while the playbook binds apps to a host and hands them their environment.

A fresh host is reached as root once (`mise provision -- -u root`), which creates the admins; every later run connects as an admin, and the first of those closes root logins.
Ops changes are applied by `mise configure` (or `mise provision`) in the tenant's platform repo, dry-run first with `--check --diff`; Ansible skips `command` tasks in check mode, so pull, up, and login only show in the real run.


## § 2 The host baseline

Every host the collection touches gets the same baseline, whichever playbook mounts it: packages and a local record of system activity (`configure_base`), personal admin accounts with key-only SSH and passwordless sudo (`configure_iam`), unattended security upgrades (`configure_unattended_upgrades`), a default-drop firewall assembled from fragments the other roles hand it (`configure_firewall`), and sshd closed to root and passwords once an admin has logged in (`configure_sshd`).
An app host adds the deploy user, the container engine, and the proxy (`configure_deploy_user`, `install_docker`, `install_caddy`); opt-in roles add a hostname, an overlay network, local mail to a mailbox, and an observability agent.
The roles are the one encoding of how a host is set up; nothing is done by hand before the first run, and a machine image carries only what has to exist before the first SSH login.

Runtime truth is the host, never a file: what runs is what `docker ps` says, and a `.env` on the host can be stale.


## Maintaining

Roles are named for what they do (`configure_sshd`, `install_docker`), each role's variables carry its name as prefix, and `plexus_*` is kept for the facts several roles share (tenant, deploy user, apps).
A role that needs something from another role's territory asks that role: a role that opens a port hands a fragment to `configure_firewall` instead of writing firewall files itself.
A role belongs wholly to one cadence; a component that spans both gets two roles.

`plexus-ms/platform` tags the collection and the Terraform modules together, on the train; `galaxy.yml`'s version mirrors the train tag exactly, because SCM installs record that version and a re-pointed tag alone would not reinstall.
Tenants pin the collection by tag in `requirements.yml` and the update bot proposes each train as a PR a human reads before anything new runs as root ([PLX-Updates](updates.md)).
The collection's own `mise :check` lints the roles; a container-backed role test covers what can be exercised without a host.
Ansible and the vault CLI want a terminal-free invocation in automation: stdin from `/dev/null`, output to a file.
