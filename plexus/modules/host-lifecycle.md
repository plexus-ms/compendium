---
title: PLX-HostLifecycle – host lifecycle
short_title: PLX-HostLifecycle
description: The interim posture on patching — unattended security upgrades on, every other host change a supervised act — until patch drift is visible enough for an honest policy.
code: PLX-HostLifecycle
kind: approach
maturity: approach
binds: host
depends: [PLX-Platform]
order: 25
---

This module is the posture on what happens to a host after its first playbook run: patches, reboots, upgrades, rebuilds.
It is interim by design and says so.


## § 1 The interim posture

Tenant hosts run the distribution's unattended security upgrades, the default of the `configure_unattended_upgrades` role.
Everything beyond that, kernel-update reboots, engine major bumps, release upgrades, host rebuilds, is a supervised operator act for now.
A host that reboots unattended on a schedule is a tenant's choice, recorded in its platform marker; the roles leave the host up by default.

A full patching and lifecycle policy is deliberately deferred until patch drift is observable: visibility first, then an honest policy.
That visibility is an observability concern (§ 12 PLX), and the policy is written when the data exists to write it against.


## § 2 Rebuilding a host

The roles are the single encoding of a host's setup, so a rebuild is a fresh host plus the playbooks, never a restore of the old root.
What has to survive a rebuild is the apps' data ([backups per service](backup.md), [PLX-Hosting](hosting.md) for whole-VM backups) and the inventory; the host itself is reconstructable from git.
Delete something only after checking what still references it; a guest removed from a hypervisor without care drops out of its backup job as well.


## Maintaining

The module is promoted when a policy exists that two tenants follow and a role enforces; until then its one requirement-shaped sentence stays prose.
Engine and distribution majors are handled on the train like any other role change: the role learns the new version, the train ships it, the tenant applies it under supervision.
