---
title: PLX-JS – the JS/TS toolchain
short_title: PLX-JS
description: The one toolchain arrangement for JS/TS repos — pnpm workspace plus Turborepo behind the standard verbs, node pinned once in .node-version, dev tools as devDependencies, Biome for format and lint.
code: PLX-JS
maturity: standard
binds: repo
changed: 0.60.0
depends: [PLX-Repo]
order: 16
---

[PLX-Repo](../contracts/repo.md) names four verbs and says nothing about what runs behind them.
This module is the arrangement behind them for one stack, JS/TS, the first toolchain the standard has specified.
A Python or Go repo takes the same repo contract with a toolchain module of its own, when one is written.


## § 1 The toolchain

> - Every Plexus JS/TS repo MUST use the toolchain of this module.
> - JS/TS app repos MUST use the monorepo pattern: pnpm workspace plus Turborepo.
> - Turborepo owns the task graph: leaf tasks are `package.json` scripts, `turbo.json` states the task rules (`build`, `typecheck`, and `test` depend on `^build`), and the workspace edges are read from each `package.json`; the graph MUST NOT be re-encoded in mise tasks or CI configuration.
> - Leaf projects MUST NOT carry a `mise.toml`; the root verbs delegate to turbo.
> - mise MUST install only node for the JS/TS toolchain; the package manager arrives through node itself: a `postinstall` hook enables corepack, which installs the pnpm version pinned in the root `package.json` `packageManager` field, the single pnpm pin (Turborepo requires the field anyway).
> - The node version MUST be pinned exactly once: a `.node-version` file at the repo root, read by mise natively (`idiomatic_version_file_enable_tools`), by CI as a plain file, and by the image build as a build arg.
> - JS-ecosystem dev tools (turbo, biome, …) MUST be devDependencies, on the PATH via mise's `_.path`, never mise `[tools]` entries; a `package.json` MUST NOT carry `engines`.

Each fact sits in its canonical home ([§ 2 PLX-Repo](../contracts/repo.md)): the pnpm version where pnpm itself and every update bot reads it, dev tools where npm's ecosystem versions them, the task graph where turbo reads it, and the node version in `.node-version`, the file the node ecosystem's own version managers converged on, which any consumer can read without a toolchain (`cat` in CI, an `ARG` in the Dockerfile, mise natively).
`pnpm-workspace.yaml` (`packages:` globs plus a `catalog:` pinning shared dev-tool versions) owns install and linking; turbo owns ordering and caching on top of it.
The division of labor is exact: pnpm knows the package graph but not tasks, mise knows tasks but not the graph, turbo knows both.
`dependsOn: ["^build"]` says once, for every consumer present and future, that internal packages build before their dependents typecheck, test, or build.
That single rule is what makes every verb answerable from a fresh checkout: a workspace package's `dist/` is a build product, never a commit.
Formatting and linting is Biome, invoked repo-wide by `check` and on staged files by the pre-commit hook, per the repo contract's hook discipline.
The concrete arrangement, the `mise.toml`, `turbo.json`, root `package.json`, hook config, Dockerfile, is not specified here: the preset ships it ([PLX-Updates](updates.md)), and staying current with the template *is* the conformant arrangement.


## Maintaining

`plexus-ms/preset-repo-web` is the arrangement authority for this module: the template's `mise.toml`, `turbo.json`, `biome.json`, root `package.json`, and `hk.pkl` are the one encoding of § 1, and a change to the requirements here is a change to the template in the same train.
The shared configs a generated repo extends (`@plexus-ms/config/biome`, `/tsconfig`) are published from `plexus-ms/packages` ([PLX-Packages](packages.md)); the template carries only the one-line `extends`.
