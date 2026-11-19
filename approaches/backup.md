---
title: Backups per service
short_title: Backups
description: The label-driven backup job that is not yet shipped — per-service dumps discovered from plexus.backup labels, an off-site repository, a hand-runnable restore verb, and a scheduled restore test; what covers the gap meanwhile.
maturity: note
binds: host
depends: [PLX-Platform]
consumes: [PLX-App]
order: 23
---

This page is a note: written knowledge about a path Plexus intends to ship, with no primitives behind it yet and therefore no requirements and no code.
It is here so the design is a decision, not drift, and so the stateful profile's `plexus.backup` label ([`PLX-App/Stateful/BackupLabel`](../contracts/app.md)) has the home it points at.


## § 1 The intended path

Backup schedule and retention live as code in the tenant's operations repo.
Ansible installs a nightly unit per VM: `pg_dump`/`mongodump` per labelled data service, then restic to an off-site repository (e.g. a Hetzner Storage Box).
The job discovers what to dump by reading the `plexus.backup` labels, so a newly deployed app is automatically backed up, with zero bookkeeping.
A `plexus.backup` value is valid exactly when the collection ships a handler for it, and extending the vocabulary means adding one handler upstream.
A nightly unit that fails or never runs raises an alert ([the scheduling note](scheduling.md)).

Untested backups are not backups, and the rule is to be encoded rather than aspirational.
A `restore` verb (a command of `plx`, [PLX-CLI](cli.md), not yet shipped) restores hand-runnably with no platform present.
A scheduled restore test exercises it at least monthly: it restores the latest snapshot of each labelled data service into a scratch container, runs a sanity check, and raises its own missed-job alert separate from the backup job's.
Its first run against a new backup path *is* the first-use verification, and the path is re-verified after any material change to it.
A backup without a hand-runnable restore is write-only storage; a restore test that silently stops running alerts exactly like a backup that silently stops running.


## § 2 Meanwhile

Until the label-driven path ships, a tenant whose infrastructure layer backs up whole VMs ([PLX-Infrastructure](infrastructure.md)), encrypted, copied off-site, and restored end to end on a schedule, meets what this page is for.
Schedule and retention live as code in the operations repo, and the restore is proven rather than assumed.
The two paths are complements, not rivals: a VM backup restores a host, a per-service dump restores one app's data onto any host.
An app whose state is not a separate data service (an SQLite file inside the app's volume) is outside the label vocabulary either way and records its interim arrangement in its marker's body.


## Maintaining

This note graduates to an approach when the handlers, the nightly unit, the restore verb, and the restore test ship together and one tenant runs them; it graduates to standard maturity when a second tenant does.
The backup vocabulary is deliberately not frozen before a handler exists: a label value nothing reads is bookkeeping, not a backup.
