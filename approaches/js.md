---
title: PLX-JS – the JS/TS toolchain
short_title: PLX-JS
description: The one toolchain arrangement for JS/TS repos — pnpm workspace plus Turborepo behind the standard verbs, node pinned in mise.toml and in the image's base, dev tools as devDependencies, Biome for format and lint.
code: PLX-JS
maturity: standard
binds: repo
depends: [PLX-Repo]
order: 16
---

[PLX-Repo](../contracts/repo.md) names three verbs and says nothing about what runs behind them.
This module is the arrangement behind them for one stack, JS/TS, the first toolchain the standard has specified.
A Python or Go repo takes the same repo contract with a toolchain module of its own, when one is written.


## § 1 The toolchain

> - `PLX-JS/TaskGraph`: The task graph MUST stay with Turborepo: leaf tasks are `package.json` scripts and the workspace edges are read from each `package.json`, never re-encoded in mise tasks or CI configuration.
> - `PLX-JS/NoLeafMise`: A leaf project MUST NOT carry a `mise.toml`.
> - `PLX-JS/DevTools`: JS-ecosystem dev tools (turbo, biome, …) MUST be devDependencies, never mise `[tools]` entries.
> - `PLX-JS/NoEngines`: A `package.json` MUST NOT carry `engines`.

A JS/TS repo takes this approach by being generated from the template `repo-turbo`, and the template does the arrangement.
An app repo is a pnpm workspace plus Turborepo, and `turbo.json` states the task rules (`build`, `typecheck`, and `test` depend on `^build`); the root verbs delegate to turbo.
An app's Dockerfile restates no build incantation of its own: its build stage runs the same `build` scripts in the same order as the verb, through pnpm rather than Turbo ([§ 4 PLX-Delivery](delivery.md), `PLX-App/Dockerfile`).
The image runs Next's standalone output, which leaves out the static files and `public/` for a CDN to serve.
Without a CDN of its own, the Dockerfile copies both in beside the standalone server, which then serves them.
mise installs only node for the JS/TS toolchain, and the package manager arrives through node itself.
A `postinstall` hook enables corepack, which installs the pnpm version pinned in the root `package.json` `packageManager` field, the single pnpm pin (Turborepo requires the field anyway).
Node has two homes, one per place it runs.
The toolchain's node is a major in the `[tools]` of the root `mise.toml`, which mise installs for a developer and for CI alike and resolves to a release of that major.
The update bot proposes only a new major.
The image's node is the base image of the app's Dockerfile, a tag of the same major pinned by digest, so that the same inputs give the same image; the update bot moves tag and digest together.
A node major waits for approval on the update bot's dependency dashboard, and moves both homes in one pull request ([§ 2 PLX-Updates](updates.md)).
The root `mise.toml` also lets mise read node's idiomatic version files, though not as a version source, since the pin in `[tools]` decides.
That makes every `package.json` a file mise recognises, which is what lets `[monorepo].config_roots` match a directory under `packages/` or `apps/` that has no mise config of its own (`PLX-JS/NoLeafMise`).
Without it, `mise install --monorepo` fails in a repo whose roots are only packages.
The dev tools are on the PATH through mise's `_.path`.
The four requirements bind the people who add to that arrangement: a new package, a new tool, a new task.

Each fact sits in its canonical home ([§ 2 PLX-Repo](../contracts/repo.md)):

- the pnpm version where pnpm itself and every update bot reads it;
- dev tools where npm's ecosystem versions them;
- the task graph where turbo reads it;
- the toolchain's node among the tools mise installs;
- the image's node in the Dockerfile's `FROM`, where docker and the update bot read it.

The image's node cannot come from the toolchain's pin: with a digest the tag no longer chooses the image, so a version passed in as a build argument would choose nothing.
`pnpm-workspace.yaml` (`packages:` globs plus a `catalog:` pinning shared dev-tool versions) owns install and linking; turbo owns ordering and caching on top of it.
The division of labor is exact: pnpm knows the package graph but not tasks, mise knows tasks but not the graph, turbo knows both.
`dependsOn: ["^build"]` says once, for every consumer present and future, that internal packages build before their dependents typecheck, test, or build.
That single rule is what makes every verb answerable from a fresh checkout: a workspace package's `dist/` is a build product, never a commit.
Formatting and linting is Biome, invoked repo-wide by `check` and on staged files by the pre-commit hook, per the repo contract's hook discipline.
Biome is pinned exactly, because a formatter's minor release can reformat the repo, for instance by formatting a file type it left alone before.
The update bot proposes the bump, and the lint in CI decides whether it merges.
`biome.json` names its schema by the installed package's path, so the schema follows the pin and carries no version of its own.
The app contract names no stack, so where it asks a stateful app for a `seed` entry point (`PLX-App/Stateful/Seed`), this toolchain spells it.
It is a `seed` script in the app's `package.json`, run by a developer against a fresh database and never by the deploy verb.
The concrete arrangement, the `mise.toml`, `turbo.json`, root `package.json`, hook config, Dockerfile, is not restated here.
The template ships it ([PLX-Updates](updates.md)), and staying current with the template *is* the conformant arrangement.


## Maintaining

The template `repo-turbo` in `tooling` is the arrangement authority for this module: the template's `mise.toml`, `turbo.json`, `biome.json`, root `package.json`, and `hk.pkl` are the one encoding of § 1.
A change to § 1 here is a change to the template in the same version.
The shared configs a generated repo extends (`@plexus-ms/config/biome`, `/tsconfig`) are a library, published from `plexus-ms/libraries` on a version line of its own (§ 1.5 PLX); the template carries only the one-line `extends`.
Its range lives in one place, the `plexus` catalog of `pnpm-workspace.yaml`, and every manifest says `catalog:plexus`.
The template states the range once and never rewrites it, the update bot is its one writer ([§ 2 PLX-Updates](updates.md)), and the manifests a tenant writes by hand follow without an edit.
