---
title: PLX-AppStateful – the stateful app profile
short_title: PLX-AppStateful
description: The app contract sharpened for apps backed by data services of their own — backup labels, an idempotent one-shot migrate service, expand/contract migrations, a seed task.
code: PLX-AppStateful
maturity: standard
binds: app
changed: 0.60.0
depends: [PLX-App]
order: 13
---

A profile is a variant of the app contract: it extends and sharpens [PLX-App](app.md) for one recognizable shape of app, the way an interface is taken by a concrete type.
Every app takes exactly one profile and lists it in its marker; the platform treats every app identically through the same verbs and labels, and never needs to know the profile.

This profile is for apps backed by one or more data services of their own, the common case.


## § 1 Data services

> - Data services MUST carry the labels `plexus.tenant=<slug>` and `plexus.backup=<type>`; a `plexus.backup` value is valid exactly when the `plexus.platform` collection ships a backup handler for it.
> - The app SHOULD default to one database container of its own: full isolation, dies with the app.

The backup job discovers what to dump by reading the labels ([backups per service](../approaches/backup.md), still a note), so a newly deployed app is covered with zero bookkeeping once the handlers ship.
Extending the backup vocabulary means adding one handler upstream, after which every app using that data-service type is covered.


## § 2 Migration

> - `compose.yaml` MUST declare a one-shot `migrate` service: the app's own image, its migration command, and `profiles: ["migrate"]` so a plain `up` never starts it.
> - `migrate` MUST be idempotent: already-applied steps are skipped, and running it against a fully-migrated schema is a no-op.
> - A `migrate` failure partway through MUST leave the schema in a state from which re-running `migrate` can complete, each step applied atomically where the database supports it.
> - Concurrent `migrate` invocations MUST NOT corrupt the schema; `migrate` SHOULD serialize itself via a lock.
> - Every migration MUST be backward-compatible with the release currently in production: expand/contract discipline, roll-forward only.
> - A genuinely breaking migration, one that cannot honor expand/contract, MUST be deployed as a deliberate act: fresh backup taken first, and the operator aware that reverting means restoring, not re-upping the previous tag.

`migrate` is the one contract step the deploy pipeline invokes against production data, hence the precision.
It runs as a container from the very image being deployed (`docker compose run --rm migrate`, [PLX-Deploy](../approaches/deploy.md)): the image carries its own migration tooling, dev runs the identical step with the identical command, and the deploy host needs docker and nothing else.
The deploy flow has no down-migration step, and its rollback path re-launches the *previous* image against the *already-migrated* schema.
That is sound only if additive changes (new tables, nullable columns, backfills) ship first and destructive ones (drops, renames, constraint tightening) ship only in a later release, once no deployed code depends on the old shape.
Mainstream migration tools provide locking out of the box, so that requirement is usually just *don't disable it*.

A third-party image that migrates its own schema on startup and offers no separate migrate step does not fit § 2 as written; the gap is known and an app in that position records it in its marker until the profile settles how such an image fits.


## § 3 Seed

> - The app MUST provide a `seed` task, loading development sample data only; it MAY assume a fresh database (right after `migrate`) and MUST NOT be invoked by the deploy verb.

Production data arrives by restore or by real use, never by seed.


## Maintaining

The profile is written against the one migration path the deploy verb has.
A change to how the verb runs `migrate` ([PLX-Deploy](../approaches/deploy.md)) is a change to § 2 here, in the same train.
The approaches on each side are those of [PLX-App](app.md).
