---
title: PLX-Environment – the environment record
short_title: PLX-Environment
description: The record of one app in one environment, written by the platform's operator in the tenant's inventory, that tells the platform what to provide and the deployer where to deploy; the contract at the seam between the deployer and the platform.
code: PLX-Environment
maturity: candidate
binds: organisation
depends: [PLX-Tenancy]
order: 6
---

The environment record sits at the seam between the deployer and the platform.
On one side, the platform's operator writes the record into the tenant's platform inventory and the configure playbook renders the app's environment from it ([§ 3 PLX-Platform](../approaches/platform.md)).
On the other side, a deploy, run by an app repo's pipeline or by hand, reads the record to learn where an app's environment lives ([§ 3 PLX-Delivery](../approaches/delivery.md)).
The app itself never learns where it runs; what it is handed is the subject of [PLX-App](app.md).
This is why the record is not PLX-App: the two contracts have different pairs of sides, and the deployer needs exactly what the app never sees, the host, the user, and which environment a branch maps to.

The contract is written informatively for now: it has one deployer and one platform, and no requirement has had to be argued yet.
The maturity rule (§ 1.3 PLX) promotes it when a second tenant declares it.


## § 1 The record

A record describes one deployment: one app in one environment.
It names the app, the app's source repo, the environment (`production` when absent), the public host the deployment answers on, the loopback port it publishes, the non-secret values it is given, and the secrets it is given as `op://` pointers into the tenant's vault, never as values ([PLX-Secrets](../approaches/secrets.md)).
It lives in the inventory file of the VM that runs the deployment, and that file names where a deploy reaches the VM, `plexus_deploy_target`, as `ssh://<deploy user>@<address>[:<port>]`.

One app has at most one record per environment, and as many records as it has environments.
The environment names are those the pipeline asks for, `production` and `staging` today; a further name, such as a preview, is a further record.
The deployment's slug on the host is the app name in `production` and `<app>-<environment>` otherwise, so that a tenant with production alone never meets the rule.

The principle behind the record is one index in git, each value where it can live.
Sensitivity is the one property that forces a value out of git; every other fact of an environment, host, port, domain, values, is better held in the record, diffed, greppable, propagated by the train, and readable when the vault is not.
The vault holds only what git cannot, and the record points at it.


## § 2 What each side owes

The platform's operator owes a record for every deployment the tenant runs, kept current, and a `plexus_deploy_target` on every file that holds records; the configure playbook renders exactly what the record says, nothing more, and re-creates the containers whose environment changed.

The deployer owes to read the record and nothing else for its target: `plx deploy-targets --environment <name>` on a checkout of the tenant's platform repo, which [PLX-Tenancy](tenancy.md) fixes as the one platform repo of the organisation, prints each app's target in that environment; an app without a record there has no deployment there, and the deployer deploys nothing for it rather than inventing a target.
The deployer never writes to the record, never holds a copy of it, and never carries a target of its own once it reads the record.


## Maintaining

`configure_apps`, `configure_secrets` and `configure_ingress` provide the platform's side and `plx deploy-targets` and `plx deploy --environment` the deployer's; all ship from `plexus-ms/primitives` on the train.
The record's shape is the one § 3 PLX-Platform requires; this page owns the seam and names the sides, and a guarantee one side relies on from the other moves here when it is argued.
Decided 2026-11-04 in the CI trial of the first tenant (`damage`), where one deploy host per app repo and non-secret facts in the vault were the two things that did not scale to a second environment; 1Password Environments was considered as a store for the record and rejected, since it would be a second database of intent beside the inventory and fail the degradation test.
Promotion to standard, with the requirements of §§ 1 and 2 as blockquotes, waits for the second tenant; the branch names of an app repo matching the environment names is a deferral of PLX-Delivery decided together with it.
