---
title: Plexus
description: PLX — the Plexus.ms standard — and the artifacts generated from it.
---

This section holds the standard itself. [PLX.md](PLX.md) is the founding doctrine and the single normative
authority — everything else in the compendium, and every `plexus-ms` repo, hangs off it.

Alongside it live the artifacts the standard obligates its own repo to carry (PLX § 10.4):
[PLX-reqlist.md](PLX-reqlist.md), the condensed requirements list, grouped by section and labelled with the
§ 10.2 conformance classes; and `generate-reqlist.sh`, the hand-runnable verb that produces it. The reqlist is
generated, never hand-edited — regenerate it with `mise reqlist` (a pre-commit hook does so automatically
whenever the standard changes).
