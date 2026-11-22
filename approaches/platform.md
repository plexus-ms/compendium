---
title: PLX-Platform – the operations platform
short_title: PLX-Platform
description: A tenant's hosts as code — the plexus.host baseline and the plexus.platform roles, mounted as one tagged playbook the collection ships and the tenant's operations repo imports, and the app record that binds an app to a host.
code: PLX-Platform
maturity: standard
binds: host
depends: [PLX-Tenancy]
consumes: [PLX-Host, PLX-App, PLX-Environment]
order: 20
---

A CI/CD system needs state (what exists), events (something changed), and procedures (make it so).
Plexus puts state in git and in tools it does not author, takes events from systems someone else operates, and runs only stateless procedures.
The platform layer is the part of that model that touches hosts: the `plexus.host` and `plexus.platform` Ansible collections as the shared logic core, playbook included.
Each tenant's operations repo is the mount, holding only the binding: one line importing the collection's playbook, the inventory, group vars, the committed `op://`-pointer env files.
A tenant's playbook file is to the collection's playbook what a workflow wrapper is to a verb: a mount, not logic.

The platform starts on top of a host that exists ([PLX-Host](../contracts/host.md)).
How it comes to exist is the infrastructure layer's business ([PLX-Infrastructure](infrastructure.md) for tenants on hardware of their own), and this module is the same either way.
The playbook, the host baseline, and the app record with the app lifecycle are this module.
Ingress ([PLX-Ingress](ingress.md)) and secrets delivery ([PLX-Secrets](secrets.md)) are the two substitutable pieces on top of it, each a module of its own, and the stances on [scheduled jobs](scheduling.md) and [host lifecycle](host-lifecycle.md) are notes.


## § 1 The playbook

> - `PLX-Platform/OwnPlays`: A tenant's own plays MUST follow the import of the collection's playbook in the same file, tagged the same way, and MUST NOT re-run or reorder the collection's.

The operations template mounts the platform layer as the playbook the `plexus.platform` collection ships (`plexus.platform.playbook`), imported into a playbook file of the repo's own and run against the inventory group `platform`.
The playbook is re-runnable in whole at any time against any host of the group, and every play carries its layer as a tag and every role its own name, so that a part of it is run with `--tags` and `--limit`.

One playbook per layer: `plexus.platform.playbook` for the app hosts, and beside it `plexus.infrastructure.playbook` ([PLX-Infrastructure](infrastructure.md)) and `plexus.ci.playbook` ([§ 8 PLX-Delivery](delivery.md)) for a tenant that has those layers.
Each targets fixed inventory groups, so that the playbook can be shipped rather than templated.
The platform playbook has four plays on the group `platform`:

- the host baseline (§ 2, tagged `host`);
- the platform roles (tagged `platform`: `deploy_user`, `caddy`, `ingress`, `secrets`, `apps`);
- the lock-down roles that have to run after everything that opens a port (`firewall`, `sshd`, tagged `host`);
- a report that fails the host for every app that did not start (tagged `platform` and `apps`), after the lock-down, so that a failed start never leaves a host without its firewall and sshd settings.

`--tags apps,secrets` is the everyday pass, `--tags platform` the layer without the baseline, `--limit <host>` one host; `--list-tags` prints the rest.
The tags give the selectivity of separate playbooks with one order of roles, and the order lives upstream.

The playbook is deliberately not called a deploy.
Deploying is the verb's act ([§ 6 PLX-Delivery](delivery.md)), keyed by an image, while the playbook binds apps to a host and hands them their environment.
A fresh host is reached as root once (`mise platform -- -u root --limit <host>`), which creates the admins; every later run connects as an admin, and the first of those closes root logins.
Ops changes are applied by `mise platform` in the tenant's operations repo, dry-run first with `-- --check --diff`.
No playbook of any layer is mounted on CI: the playbooks act as root on every host, so an operator applies them.
Ansible skips `command` tasks in check mode, so pull, up, and login only show in the real run.
The opt-in roles of the baseline (`hostname`, `netbird`, `alloy`) run where the inventory sets `<role>_enabled`, and `mail` where `mail_smtp` is set.
The shipped playbook therefore lists them unconditionally and the tenant decides per group or host.


## § 2 The host baseline

Every host the collections touch gets the same baseline from the `plexus.host` collection, whichever layer's playbook mounts it:

- packages and a local record of system activity (`base`);
- personal admin accounts with key-only SSH and passwordless sudo (`iam`);
- unattended security upgrades (`upgrades`);
- a default-drop firewall assembled from fragments the other roles hand it (`firewall`);
- sshd closed to root and passwords once an admin has logged in (`sshd`).

The opt-in roles add a hostname (`hostname`), an overlay network (`netbird`), local mail to a mailbox (`mail`), the container engine (`docker`) and an observability agent (`alloy`).
`hostname` names the host after `hostname_fqdn`, the FQDN the host reports unless the inventory sets it; where the role is off, a provider-named host keeps the name its image gave it.
`netbird` joins a host to the overlay with a setup key from the playbook's environment (`NETBIRD_SETUP_KEY`), needed only on the run that joins it.
An app host adds the deploy user and the container engine (`plexus.platform.deploy_user`, `plexus.host.docker`); the proxy is [PLX-Ingress](ingress.md)'s.
Every deploy pulls an image and none removes one, so `docker` removes them daily: an image goes once no container has used it at two consecutive daily runs.
The image a deploy has just replaced therefore stays for a day at least, in the host's cache for the deploy's rollback ([§ 6 PLX-Delivery](delivery.md)) and for one by hand; volumes and the build cache are left alone.
On a CI runner host the role's removal is off, since the runners' housekeeping owns the images there.
A host that runs the tenant's own CI runners instead of apps takes the baseline, the container engine, and `plexus.ci.actions_runners`, through the CI playbook ([§ 8 PLX-Delivery](delivery.md)).
`plexus.host` has no playbook of its own: it is the layer every other layer stands on, and each layer's playbook lists its roles in the order that layer needs.
The roles are the one encoding of how a host is set up; nothing is done by hand before the first run, and a machine image carries only what has to exist before the first SSH login.

Runtime truth is the host, never a file: what runs is what `docker ps` says, and a `.env` on the host can be stale.


## § 3 The app record and the app lifecycle

> - `PLX-Platform/AppRecord`: Every deployment a tenant runs, an app in an environment, MUST have one record in the tenant's inventory (`apps[]`) naming the app, its source repo (`apps[].repo`), its host (`apps[].host`), and its loopback port (`apps[].loopback_port`).
> - `PLX-Platform/UniqueAppName`: App names MUST be unique per tenant and environment, across all of its repos.
> - `PLX-Platform/RecordValues`: Non-secret values the platform provides to an app MUST be declared in its record (`apps[].env`).

A record may name its environment (`apps[].environment`), which is `production` when absent, and one app has one record per environment it runs in.
The deployment's slug on the host is the app name in `production` and `<app>-<environment>` in any other environment; the app directory is `<deploy root>/<slug>` and the compose project is named the slug.
The platform playbook writes the record's values to `.env` in the app's directory on the host, and is that file's only writer.

The record is the platform's whole knowledge of a deployment, and the app name is the join key across repos.
The inventory record, the compose project, and the host directory all key on it, which is why it is unique per tenant rather than per repo.
An environment adds a second record for the same app, with its own host, port, values and secret pointers, on the same VM or another.
The slug rule leaves production's names unsuffixed, so a tenant without a staging environment has no environment in any name.
The record is also what the deployer reads: which host an app's environment lives on is this record's `plexus_deploy_target`, read by `plx deploy-targets` ([§ 3 PLX-Delivery](delivery.md)).
The record is the object of [PLX-Environment](../contracts/environment.md), the contract between the deployer and the platform.
From the record the platform playbook lays out the deployment's directory on the host, `<deploy root>/<slug>` (e.g. `/opt/stacks/website`, `/opt/stacks/website-staging`), and writes `.env` there.
It logs the deploy user in to the registry, and pulls and starts the app once the deploy verb has placed its `compose.yaml`; a fresh host stays provisioned-but-empty until the first deploy ([§ 6 PLX-Delivery](delivery.md)).
`.env` is written in three sections, compose's own setting, the reserved `PLEXUS_` bindings, then the values from `apps[].env`.
Each is under a header line naming its origin, so the first file an operator opens explains itself.
The compose setting pins the project name to the slug: container, network and volume names derive from the project name, and pinning it keeps them the same wherever compose is invoked from.
Neither the directory nor the project name carries the tenant slug, since two tenants never share a VM ([§ 4 PLX-Tenancy](../contracts/tenancy.md)).
The `PLEXUS_` bindings carry the loopback port the inventory assigned, interpolated by compose ([§ 4 PLX-App](../contracts/app.md)), so the deploy verb stays port-unaware.
Because the app's compose file lists `.env` under `env_file`, the setting and the bindings also appear inside the container, harmless by construction since the prefix is reserved.
Three files sit in the app directory, and each has exactly one writer: this playbook owns `.env`, the secrets role owns `.env.secret` ([PLX-Secrets](secrets.md)), and the deploy verb owns `compose.yaml`, rendered from the source repo.
Pass `plexus_up=false` to write the directories without re-creating containers.
A VM's record may also carry `plexus_deploy_target`, where the deploy verb reaches it.
The `deploy-targets` verb reads it, per app and environment, so that each deployment goes to the VM that runs it; a deployment whose record names no target is not deployed.


## Maintaining

`plexus.platform.apps` carries § 3; it writes `.env`, never `.env.secret`, and re-creates the containers whose `.env` changed through a handler of its own.
Roles are nouns, the thing a host has (`sshd`, `docker`, `apps`), never verb-object, since every role's verb is the same: make the host match the inventory.
Each role's variables carry the role's name as prefix (`iam_admins`, `guests_list`, `actions_runners_slots`), which is why role names are unique across the four collections.
`plexus_*` is kept for the facts several roles share (deploy user, deploy root, apps).
A role that needs something from another role's territory asks that role: a role that opens a port hands a fragment to `plexus.host.firewall` instead of writing firewall files itself.
A role belongs to the layer whose playbook needs it, and a role two layers need is `plexus.host`'s.

`plexus-ms/tooling` carries the four collections under `ansible/<collection>/`, each with its `galaxy.yml` whose version mirrors the version tag exactly.
It has to, because SCM installs record that version, and a re-pointed tag alone would not reinstall; the collections are installed from the one repo at one tag, so there are no dependencies between them for galaxy to resolve.
Tenants pin all four by tag in `requirements.yml`, and the pull request that takes a version moves the pins, a PR a human reads before anything new runs as root ([PLX-Updates](updates.md)).
The `check-ops` task of `tooling` lints the roles, syntax-checks the three shipped playbooks against a fixture inventory of the standard groups, and syntax-checks a playbook that lists every role.
It runs under a project-local collections path, so that a tenant's installed pin never shadows the checkout.
Ansible and the vault CLI want a terminal-free invocation in automation: stdin from `/dev/null`, output to a file.
