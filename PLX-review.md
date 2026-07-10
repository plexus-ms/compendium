---
title: Peer review of PLX.md (v0, plx-wip @ a491a21)
description: Manuscript-style review — conceptual, structural, and stylistic comments, individually addressable.
timestamp: 2026-07-09
---

# Peer review: "PLX — The Plexus.ms Standard" (v0)

**Reviewed revision:** `plx-wip` @ `a491a21` ("manual revision up to and including section 4").
**Reviewer recommendation (manuscript-speak):** *Accept with major revisions.* The document is unusually good for a v0: the core ideas (fog as a structure problem; decide-once-encode-propagate; methodology vs. substance; verbs and mounts; the two litmus tests; the fence around the deploy verb) are genuinely load-bearing and mostly well-argued. The major revisions requested are not about the ideas — they are about closing a handful of real specification gaps (migration/rollback ordering, port allocation, secrets rotation, backup-restore verification), resolving an internal contradiction in the conformance machinery (reference-stack convention vs. keyword-bearing tool names), and disciplining where normative statements live so the standard is checkable.

Comments are numbered and individually addressable: **C** = conceptual (the initiative itself), **B** = structural (how the document conveys), **S** = stylistic (the spec/rationale balance), **N** = nits. Line numbers refer to `PLX.md` on `plx-wip`.

---

## A. Conceptual — the initiative itself

**C1. Migration/rollback ordering is unspecified, and the deploy verb's rollback path is unsound without it.** (§ 6 l. 245, § 7 l. 292–301) `mise :migrate` MUST be idempotent, and the deploy verb runs `migrate` before `up -d`; on failed healthcheck it "re-ups the previous tag." But by then the migration has run — the old code is relaunched against the new schema. This is the classic expand/contract problem and the standard is silent on it. Since the deploy verb's rollback is a headline feature ("Rollback needs no memory"), the contract needs one of: (a) migrations MUST be backward-compatible with the previous release (expand/contract discipline), or (b) an explicit statement that rollback is best-effort and unsafe across schema changes. Also specify what "idempotent" covers: concurrent invocation? partial failure mid-migration?

**C2. Host port allocation is unowned bookkeeping — the exact kind of state the standard exists to eliminate.** (§ 6 l. 248, § 7 Ingress l. 312) The contract bakes `127.0.0.1:<port>:<port>` into the app's `compose.yml`, implying host port = container port, chosen in the app repo. Two apps on one VM claiming the same port collide, and cross-app port uniqueness becomes coordination state living in someone's head — fog by the document's own definition. Meanwhile § 7 says the domain→port map is deployment substance in `infra/`. Resolve the tension: either the host port is assigned by the platform (inventory) and injected at deploy time, or the standard must define a port-allocation convention. Either way, say who owns the number.

**C3. Secrets rotation as described doesn't actually rotate the running process.** (§ 7 Secrets l. 315–320) "Rotation is changing the vault item and re-running the playbook" — but the playbook writes `secrets.env`; the running container keeps its old environment until re-created. An operator following the text verbatim has rotated a file, not a credential. State the full loop (playbook + re-up / redeploy), and consider whether the deploy verb's "secret-unaware" stance needs a documented interaction here. Related minor: `secrets.env` at rest on the host has unspecified ownership/permissions.

**C4. The backup-verification MUST violates the document's own autopilot mechanism.** (§ 7 Backups l. 323; cf. § 1 insight 2) "A backup path MUST be verified by an end-to-end restore… SHOULD be re-verified periodically" is precisely a decision that has been made but not encoded and not propagated — the failure mode insight 2 warns about. There is no restore verb, no scheduled restore-test, no dead-man's-switch on restores. Either specify the primitive (a `restore` verb is also what makes backups pass the degradation test) or add it to § 9 with a trigger. As written, this MUST will rot into aspiration.

**C5. The reference-stack convention and § 5.1's keyword-bearing tool names contradict each other.** (Preamble l. 41–44 vs. § 5.1 l. 200–206) The preamble establishes: concrete tools named *without* a conformance keyword = reference stack, substitutable. § 5.1 then says "Every Plexus JS/TS repo MUST use this toolchain," naming mise, pnpm, biome, tsc, `node --test`, hk, changesets — concrete tools *with* MUST force. So are these substitutable or not? I believe the intent is "normative within JS/TS, and mise is normative cross-stack (§ 6)" — which is a defensible decision, but it must be stated as one, because right now the preamble's escape hatch and § 5.1's MUSTs give a conformance-minded reader two contradictory readings. One sentence establishing precedence ("a keyword-bearing tool name is normative and overrides the reference-stack convention") fixes it.

**C6. The paved road defaults to the riskiest supply-chain posture while the risk discussion disclaims it.** (§ 4.2 l. 159–165, § 8 l. 358) § 4.2 says auto-upgrading "must be handled per tenant by risk appetite"; § 8 presents CI-green patch/minor auto-merge as the paved-road default — including for the Ansible collection, which runs with root on tenant hosts. Auto-merging a linting config and auto-merging root-executing roles are different risk classes; the standard should either stratify (auto-merge MAY for packages, SHOULD NOT for the collection, or similar) or explicitly own that the default is trust-maximal. Relatedly, the movable-tag sharp edge is honestly named in § 4.2 (l. 164–165) but § 4.3's "tenants MUST reference `itops` artifacts by tag, never by branch" (l. 183) doesn't cross-reference it — a reader of § 4.3 alone mandates the mutable mechanism without seeing the caveat.

**C7. The bus factor of the standard itself is unaddressed.** (§ 1, § 4.2, § 9) Fog is defined as one operator's head becoming the database; Plexus fixes that for *systems* but concentrates a new single point: one maintainer controls the standard, the packages, the template, and (via the supply chain) code that runs as root everywhere. The degradation test is thoughtfully applied to primitives — apply it to the initiative: what happens to a tenant when `plexus-ms` goes unmaintained? (Answer is probably "pins keep working, verbs stay hand-runnable, drift accumulates slowly" — which is a genuinely good answer, so write it down.) Also missing: license/governance of the shared repos, and a vulnerability-disclosure channel for shared primitives — both prerequisites for the third-party adoption the document's framing assumes.

**C8. In a tenant monorepo with environment branches, deploy granularity is undefined.** (§ 5.3 l. 229–234, § 4.3 l. 186) One monorepo holds many apps plus `infra/`; branches map to environments; merge to `main` deploys… everything? Path-filtered CI per app? Can app A promote to prod while app B stays on staging? "Promote staging to prod is merging `develop → main`" is clean for one app and ambiguous for N. This is a real operational question the target audience will hit in week one.

**C9. `/healthz` semantics are too thin to carry the weight placed on them.** (§ 6 l. 249, § 7 l. 297–298) "Returns 200 when ready" — does readiness include DB connectivity? If yes, a transient DB blip fails deploys and triggers rollbacks; if no, the check can pass while the app cannot serve. The deploy verb makes an automated rollback decision on this endpoint, so its semantics are normative in effect; give them one more sentence (and consider distinguishing readiness from liveness, or explicitly refusing to).

**C10. `node --test` on native type-stripping silently narrows the permitted TypeScript dialect.** (§ 5.1 l. 205) Type-stripping runs only erasable syntax: no `enum`, no parameter properties, no legacy namespaces. Choosing it therefore imposes an unstated language subset on every Plexus package. Fine choice — but make the constraint explicit, or it will be discovered as a mystery test failure (a second-reader failure at the standard level).

**C11. `env.schema` invents a micro-format without specifying it.** (§ 6 l. 247) Annotations `# required`, `# secret`, `# default: <value>` — same line or preceding line? Combinable? Is an unannotated key optional-non-secret? § 7 builds machinery on it (the platform "can diff the schema", `# secret` keys drive `apps[].secrets`), so the format is load-bearing. For a document that hates drift, an ambiguously specified format is an invitation for two parsers to disagree. Specify the grammar in ~5 lines, or adopt an existing convention and cite it.

**C12. "Federation" may promise more than it means.** (§ 2, § 4.2) In common usage federation implies peer-to-peer interop between instances (identity, ActivityPub, etc.); here it is hub-and-spoke distribution of methodology from a single upstream. The banner term works rhetorically ("one cookbook, many kitchens" is exactly right), but consider one sentence saying what it is *not* — tenants never talk to each other, nothing federates at runtime — to preempt the wrong mental model.

**C13. The forge is already tier-0 for deploys despite the rationale for not self-hosting it.** (§ 7 Forge l. 287) Self-hosting is rejected partly because it would create a tier-0 dependency — but GitHub already is one: CI is the deploy trigger and GHCR holds the images, so a forge outage means no deploys (and depending on host image cache, possibly no rollbacks). That's an acceptable trade — most shops accept it — but the honest move, in a document this honest elsewhere, is to name it as accepted rather than imply the dependency was avoided.

**C14. Host lifecycle (OS patching, reboots, firewall, hardening) is conspicuously absent.** (§ 7, § 9) The standard spans "dev to ops" and covers ingress, secrets, backups, scheduling — but never mentions unattended upgrades, kernel reboots, or the host firewall, even at reference-stack level. Perhaps the `plexus.itops` roles handle it; the standard should at least name the concern and point there, or defer it in § 9 with a trigger. Right now the reader can't tell whether it's covered elsewhere or forgotten.

**C15. Deploy-failure "alert" has no defined channel today.** (§ 7 l. 298 vs. § 9 l. 369–370) The verb sketch says "on failure: re-up previous tag, alert," but alerting/observability is deferred and the dead-man's-switch service is undecided. Internal inconsistency: the shipped verb references a capability the standard says doesn't exist yet. Either define the minimal alert channel now (even "exit non-zero and let CI notify" would do) or mark the alert step as deferred alongside § 9.

**C16. Bash verbs: specify a safety baseline.** (§ 7 l. 282) Verbs are "portable bash," ~150 lines. Reasonable — but bash's failure modes (unset vars, silent pipeline failures) are exactly second-reader traps. One normative line (`set -euo pipefail` or equivalent, shellcheck-clean) would cost nothing and harden every verb.

---

## B. Structural — how the document conveys

**B1. Define conformance targets (classes).** The RFC-2119 keywords bind, variously: an app repo (§ 6), a tenant monorepo (§ 4.3, § 5.3), a tenant platform/organization (§ 4.2 virtualization, secrets), the shared repos, and the maintainers themselves (§ 5.2's release process is self-directed — no tenant can conform to it). The preamble speaks only of "a repo conformant to v1.0." A short conformance section naming the classes (app, tenant monorepo, tenant platform, the standard's own repos) and attaching each requirement to a class would make the whole document checkable and would resolve recurring "who is this MUST for?" ambiguity (e.g., § 5.2 l. 216 "the release branch is protected by a ruleset" — description of plexus-ms's setup, or a requirement?).

**B2. Normative statements are scattered inside rationale prose; provide an extractable requirements view.** The tenant-label MUST lives mid-paragraph in § 4.2 (l. 176); the hooks requirement inside a dense bullet in § 5.1 (l. 206); the legal-documentation MUST inside the bare-metal discussion (l. 174). An implementer cannot extract a checklist without re-reading everything. Suggest an appendix that collects every MUST/SHOULD with its section anchor — ideally *generated* from the source, not hand-maintained, in keeping with the document's own anti-drift doctrine.

**B3. Number the subsections of § 6 and § 7.** § 5 has § 5.1–5.3; § 7 uses unnumbered headings (Forge, CI, Ingress, Secrets, Backups, Scheduling), which forces cross-references like "§ 7 Ingress" (l. 248) and "see Scheduling below" (l. 323). Uniform numbering (§ 7.1 …) makes every cross-reference precise and stable.

**B4. Add one figure.** The architecture is extremely diagrammable — three tenant-neutral repos, the seam, tenants instantiating downward, methodology flowing across, substance staying siloed — and the document is entirely figure-free. A single diagram after § 4.1 would halve the number of forward references a first-time reader must hold in their head.

**B5. The abstract assumes vocabulary it hasn't earned yet.** (l. 15–24) "Stateless verbs," the seam, second-reader and degradation tests, "customer-1001 economics," "the fog lifts" — all pre-definition. As a recap for re-readers it's excellent; as a first contact it's a wall. Either simplify it to plain language, or keep it dense and let § 2 carry more: notably, define **customer-1001 economics** in Terminology (it's used twice and never defined) and consider whether the abstract's single nine-line architecture sentence should be three sentences.

**B6. Purge repo-state and instance-specific facts from the standard; they rot on contact.** "*First instance:* `plexus-website`" (l. 268–269), "(Not yet created — § 9)" (l. 342), "the itops `alloy` role points this way" (l. 369), "Any pre-existing, semi-dormant orchestrator instance in a tenant is fog" (l. 332 — this reads as autobiography). The document's own thesis is that documentation written next to a system drifts; status-of-the-world notes inside the standard are exactly that. Move exemplars and work-item status to a companion doc or tracker; keep § 9 strictly for *decisions with triggers* (the dead-man's-switch entry is the model — the renovate-config entry is a TODO wearing a decision's clothes).

**B7. § 6 restates § 5.1 (toolchain pinning) instead of referencing it.** (l. 245) "Toolchain pinned in `mise.toml` (the single authority — never in `package.json`)" duplicates § 5.1's rule. Two statements of one rule is the "two pins for one fact is drift" problem the document itself names at l. 202. State once, reference elsewhere.

**B8. The versioning/conformance machinery deserves a real section, and `PLEXUS.md` a format.** The versioning policy lives as italic preamble text (l. 34–39); `PLEXUS.md` is defined parenthetically at l. 252 yet referenced from the preamble; and § 8 tier 3 wants machine-checkable drift detection against it — impossible until its format (one line? frontmatter? key names?) is specified. Promote versioning + conformance + `PLEXUS.md` format into one numbered section.

**B9. There is no mechanism for recording tenant divergence.** The preamble says a tenant substituting a reference-stack tool "owns the divergence" — but owns it *where*? Given the ethos (state greppable, decisions written down), divergences should be recorded artifacts, e.g. a Deviations block in `PLEXUS.md`. This also gives § 8 tier 3's drift check something honest to report against.

**B10. Standards boilerplate is missing.** Status-of-this-document; how and where to send comments (l. 11 says "comments welcome" — no channel); the change process for the standard itself (who decides a major revision?); license. All become necessary the moment a second party adopts.

---

## C. Stylistic — the specification/rationale balance

**S1. The balance is the document's signature strength — protect it by separating registers, not by cutting rationale.** The RFC-2119 preamble plus "everything else is informative" is exactly the right frame, and the best passages (the fence, l. 303; the dependency-mechanics rule, l. 355; the § 5.3 table+why structure; the root-`package.json` exception with its documented cause, l. 204) show the house style at its best: crisp rule, honest reason, named exception. The weakness is drift from *informative* into *persuasive*: manifesto cadence ("the propagation step is the whole game," "the fog lifts") is perfect in § 1 and increasingly competes with precision by § 7–8. Recommendation: keep the manifesto voice in § 1 and in clearly-marked rationale, and let normative sections cool down.

**S2. Untestable and hedged MUSTs dilute the keyword.** Every MUST should be verifiable by a second reader. Offenders: the tenant slug "MUST … thread[] through **as consistently as possible**" (l. 176 — as-possible cannot fail a check); "some sort of dead-man's-switch / smoke-test monitor" carrying a MUST (l. 329); "Every primitive is as stateless as possible" (Abstract); § 3's lowercase-but-spec-toned "trade-offs must be considered and a balance must be struck" (l. 101). Make each testable or downgrade to informative.

**S3. The legal-compliance MUST oversteps the standard's authority.** (l. 174) "Distinct legal persons sharing one box … MUST document the arrangement in writing **in order to stay compliant in most jurisdictions**" — PLX can require the document (defensible, keep the MUST scoped to that); it cannot make jurisdictional compliance a conformance requirement, and "most jurisdictions" is a legal claim the standard shouldn't underwrite. Split: MUST document the arrangement; informative note on why (GDPR/AVV example is good).

**S4. Sentence density: several bullets fail the second-reader test applied to the document itself.** The § 5.1 mise bullet (l. 202) is ~90 words with four parentheticals, an embedded competitor comparison ("not justfiles"), and monorepo path syntax — three concerns in one breath. Same for § 5.2's opening sentence (l. 210). The fix is mechanical: one requirement sentence, then rationale sentences. The competitor comparisons (justfiles, Coolify/Dokploy/Vercel at l. 109) are valuable — give them room as rationale asides rather than mid-sentence payloads.

**S5. `mise :verb` vs. `mise verb` is used inconsistently at the exact places a reader needs it most.** § 5.1 (l. 202) defines the syntax carefully (colon = task path, bare = standalone `mise.toml`), but § 6 writes `mise :migrate` at l. 245 and `mise migrate` at l. 263/271, and the § 7 verb sketch uses `mise migrate` (l. 295) without noting that the bare form is deliberate (deploy host context). Either normalize or annotate at the point of use; as written it reads as sloppiness rather than the intentional distinction it is.

**S6. Recurring verbal tics.** "Honest/honestly" appears four times in load-bearing positions ("Scope, honestly:", "the one honest exception", "honest answer" energy throughout) — endearing once, a mannerism by the third. "God-mode" (l. 173) is fine in rationale but sits inside a security-critical paragraph that deserves plainer language. Person drifts among "we, the maintainers" (preamble), "you" (§ 8 l. 350), and impersonal spec voice — acceptable if "we/you" is confined to informative text; currently it isn't consciously confined.

**S7. § 3's opening undermines the principles before stating them.** (l. 98–102) "Load-bearing philosophy" followed immediately by "not to be seen as non-negotiable" (a double negative meaning *negotiable*) reads as pre-emptive surrender. The intended nuance — principles conflict and require trade-offs, deviations should be documented — is right; invert the framing: state the principles with confidence, then one sentence on how conflicts are resolved (documented trade-off), which also dovetails with B9's deviations mechanism.

**S8. A few rationales assert connections they don't establish.** (a) § 4.3 l. 186: "Because this standard is somewhat web-focused, the monorepo pattern has several benefits" — web-focus is not why monorepos help; the actual reasons (atomic commits, one access boundary, apps+platform versioning together) follow, so the causal opener is both wrong and unnecessary. (b) § 5.3 l. 222: conflating the models "generates dead-end 'extra work' in the design" — the scare-quoted "extra work" is unexplained; the excellent back-merge-tax paragraph below it is the real argument, so let it carry the claim. (c) § 4.2 l. 171: "Feeling the need to deviate … might be acceptable under certain conditions but must also be interpreted as a sign of a deeper structural problem" — grammatically tangled and hedged three ways; say it straight: sharing ingress/secrets across tenants is a red flag; if the economics force it, the standard has failed its goal — file an issue against the standard.

---

## D. Nits (typos, mechanics)

**N1.** l. 26: "It intended for Plexus contributors" → "It **is** intended…". Also "for Plexus contributors, and anyone" — drop the comma.

**N2.** l. 80: "`plexus` itself is a tenant (the initiative dogfooding its own methodology) without being one" — as written, a contradiction ("is a tenant without being one"). Intended: "…without being a distinct legal person." Say that.

**N3.** l. 31: The hand-rolled "when they appear in ALL CAPITALS" clause *is* RFC 8174; cite BCP 14 (RFC 2119 + RFC 8174) and get the clause for free.

**N4.** l. 141: `| **\`preset\`** - uniting` uses a hyphen where the other table rows use an en dash.

**N5.** l. 9 vs. frontmatter `description`: the italic tagline duplicates the frontmatter verbatim — intentional? If the frontmatter renders, it's a doubled line.

**N6.** l. 206: "no `experimental` needed" — insider reference (mise's experimental flag?) that fails the second reader; gloss or cut.

**N7.** l. 216: "The release branch is protected by a ruleset" — name the branch (`main`).

**N8.** l. 246: `plexus.backup=<postgres|mongo|...>` — say where the value vocabulary is defined/extended (presumably: a backup handler existing in `itops` defines a valid value).

**N9.** l. 196: "JS/TS is simply the first toolchain the standard has decided" → "decided on" (or "specified").

**N10.** l. 359: "this MUST NOT be done for the std" — "the std" reads oddly; "`@plexus-ms/std`" or "the standard library" (and note the unfortunate collision between "the standard" = PLX and "std" = the package — § 2 could disambiguate).

**N11.** Preamble lists SHOULD NOT among the keywords; the body never uses it. Harmless, but either use it where warranted (C6 suggests a spot) or trim the list.

**N12.** § 7 heading (l. 274): "(all stateless, all second-reader-test-passable)" — claims don't belong in headings (and "the backup repo" and `secrets.env` are state the abstract itself admits). The section body already makes the nuanced version of the claim; the heading overclaims.
