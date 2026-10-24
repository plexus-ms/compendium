---
title: PLX-AppStateless – the stateless app profile
short_title: PLX-AppStateless
description: The app contract sharpened for apps holding no state of their own — static and marketing sites, stateless APIs.
code: PLX-AppStateless
maturity: standard
binds: app
changed: 0.60.0
depends: [PLX-App]
order: 3
---

A profile is a variant of the app contract: it extends and sharpens [PLX-App](app.md) for one recognizable shape of app, the way an interface is taken by a concrete type.
Every app takes exactly one profile and lists it in its marker; the platform treats every app identically through the same verbs and labels, and never needs to know the profile.

This profile is for apps holding no state of their own: static and marketing sites, stateless APIs.


## § 1 Services

> - `compose.yaml` MUST declare only stateless services: no data services, no `plexus.backup` labels, and no `migrate` service.
> - A `seed` task MAY be omitted.

The deploy verb checks `compose.yaml` for a `migrate` service, finds none, and moves on: uniform handling, with no knowledge of the profile.
A stateless app degrades gracefully by construction: the host is fully reconstructable from git plus the image registry, with no data to restore.


## Maintaining

Keep the profile to what distinguishes the shape; anything true of every app belongs in [PLX-App](app.md).
The approaches on each side are those of [PLX-App](app.md).
