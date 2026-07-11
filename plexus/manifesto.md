---
title: The Plexus Manifesto
short_title: Manifesto
description: Why Plexus exists — the fog problem, and the foundational premises and principles Plexus is built upon.
version: v0
timestamp: 2026-07-11
order: 0
---

Plexus is a comprehensive, opinionated, federated IT initiative: 
A neutral collection of guidelines, tools, and approaches, spanning software development to operations. 
Standardized, boring, yours.

This document, the Plexus Manifesto, or simply "the manifesto", explains why Plexus exists — the fog problem, and the foundational premises and principles Plexus is built upon.
It is aimed at anyone unfamiliar with Plexus who is looking to get started with it.

## The fog problem

When one IT operator, or a small team, runs several projects for several organizations, the surface area grows organically and chaotically, not by design.
As it grows, the dominant felt experience becomes **mental fog**: losing track of what is deployed where, how configuration interacts, how to set up a given environment, and where one was mentally when last touching a project.
Every system is slightly bespoke, every deployment is a unique snowflake, the operator's head quietly becomes the database.
Projects stay half-baked, never brought live properly, never documented enough for handoff.

**Plexus is the response.**
It is neither a single product nor an opaque control plane.
It is a collection of opinionated guidelines, tools, and approaches, intended to make doing the right thing the easy thing, so that each new project adds near-zero overhead.
Except where something *genuinely* demands bespoke config, projects should be boring and identical, and run on autopilot — composed from reusable, ideally stateless primitives with clear interfaces.

## Foundational premises

We, the maintainers, assert these statements as the basis of all Plexus design.
If you reject these at a basic level, keeping in mind the below phrasing is exaggerated for brevity purposes, Plexus might not be for you.

1. **Fog is a structure problem, not a discipline problem.**
   Fog is not fixed by promising to document more; documentation written *next to* a system drifts and rots.
   The fix is making the artifacts *be* the documentation, and making everything as well-structured as possible — **[simple, easy, no magic.](../principles/senom.md)**
   If every project answers *"how do I run you?"* the same executable way, nothing needs to be remembered.

2. **Autopilot has a precise mechanism: decide once, encode the decision in a primitive, and propagate it to every project automatically.**
   Most efforts get the first two steps and skip the third — and the propagation step is the whole game; without it every encoded decision is just another artifact that rots in place.
   Composition follows from it: primitives with clear interfaces get composed instead of reinvented — **[don't repeat yourself.](../principles/dry.md)**

## Core principles

From the foundational premises follow some principles that can be considered Plexus' load-bearing philosophy:
They are the defaults every design starts from.

In real-world application, they will pull against each other — statelessness against convenience, standardized boundaries against a genuinely bespoke need.
When principles conflict, the resolution is a **documented trade-off**: decide, record the assumption that drove the decision where the next reader will meet it, and move on.
A principle set aside with a written reason is the standard working as designed; a principle eroded silently is drift.

As we go along, these principles will evolve and change over time.

- **Have state in Git, runnable, greppable.**
  Git owns *intent and definition*; the runtime owns *current state* — what is live right now is read from the host itself, never from a bookkeeping database.
  *Why:* control planes and other heavyweight ITOps applications routinely create opaque, stateful abstraction layers that are hard to see through and debug — developer-experience gains bought with "magic" — and they typically keep that state in a database of their own, displacing the git repository as the source of truth.
  That is why such tools and managed services (e.g. Coolify, Dokploy, Vercel) are deliberately not part of Plexus.
- **Primitives should rarely remember anything.**
  Primitives are best reused when authored as stateless procedures ("verbs": deploy, backup, CI steps) and conventions (labels, file structures, endpoints), and then mounted on event and state sources that already exist.
- **Standardize boundaries, free the core.**
  Plexus aims to own the edges where apps touch shared components and logic (framework plumbing, common auth concerns, repeatable features that do not relate to the domain model) and shared infrastructure (ingress, secrets, deploy, backup, telemetry).
  The core interior of an application — usually its data model and business logic — is not Plexus's concern.
  That core is an independent layer that can be engineered with test-driven development, and it is surprisingly small once everything that can be shared is lifted up.
- **Prefer "versioned dependency" over "copied scaffold".**
  Publishing and versioning mechanisms beat copying and templating, wherever possible.
  Spending extra time extracting a shared package buys back many future hours of manual template sync.
- **Have methodology cross tenant lines; never substance.**
  Improvements in shared primitives federate to all tenants.
  Root, secrets, and data access stay siloed per tenant.

### Two litmus tests to stay honest over time

- **The second-reader test:** can a competent second person read a Plexus primitive top to bottom in half an hour and understand every line? If not, it is most likely too opaque.
- **The degradation test:** if a primitive vanished tonight, could the job still be done by hand from the same artifacts in git? If yes, it is automation of a procedure that remains manually executable, and it will be less likely to cause trouble. If no, it is a magic automation that strands the operator in its absence.

## One cookbook, many kitchens

What spans Plexus tenants is separate trust domains sharing a *methodology*, not a *concrete substance* — federation under a common standard.
Nothing federates at runtime; what travels is versioned methodology from one upstream, hub-and-spoke.

This ambition has a measurable form: **customer-1001 economics**.
The goal state in which the *marginal* tenant, project, or app costs near-zero to onboard and operate — everything it needs has already been decided once, encoded in a primitive, and propagated, so the 1001st lands as cheaply as the 11th.
Every mechanism in the standard exists to move the marginal cost toward zero; whenever the economics seem to force tenants to share substance instead, that is a bug to file against the standard, not an exception to normalize.

## Edges of this initiative

We will state two considerations explicitly:

**This initiative itself is a trust channel.**
Whoever controls `plexus-ms` ships code and knowledge-shaped-as-code that reaches deep into every tenant's hosts, inside every tenant's CI, and inside every tenant's apps.
Adopting the standard means trusting its maintainers.
The mitigations we set in place are structural: public repos, reviewable changes, provenance-attested packages, update flows stratified by blast radius — and stated as guarantees in the standard itself.

**This initiative itself has a bus factor.**
Plexus aims to standardize IT end to end, and in exchange concentrates a new single point: the maintainers control the doctrine, the packages, the template, and thus, the supply chain.
The question that matters is not "will the maintainers stay responsive" but "what happens to a tenant the day `plexus-ms` goes unmaintained".
Nothing breaks on day one: published npm versions are immutable, tags keep resolving, and the repos are public and GPLv3-licensed.
The real cost is slow drift and a standard that no longer advances, mandating a migration elsewhere on some timescale — but not an urgent outage.

## Next steps

To *implement Plexus* as a tenant, read [PLX, the Plexus Standard](standard.md).

To *work on Plexus itself* or understand the inner workings of the `plexus-ms` repositories, read the [Plexus Manual](manual.md).
