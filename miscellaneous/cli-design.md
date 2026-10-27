---
title: Best practices and patterns for CLI applications
short_title: CLI Design
description: 
---

- Follow conventions: --help/-h, --version, -v/--verbose, -q, --dry-run, --force
- Config precedence: flags > env vars > config file > defaults
- Secrets via env vars or keychain, never flags (they leak into shell history and ps).
- Don't phone home, auto-update, or print upgrade nags to stdout.

## Architecture

Layer the application into:

- core (pure functions/services, no side effects, no I/O knowledge, testable / dry-runnable with injected or mocked context)
- parser (args, command structure, typed config/interfaces)
- presentation (interactive, non-interactive, human-readable table, JSON, quiet, verbose etc.)

- Inject I/O (stdout/stderr/stdin, filesystem, clock, HTTP) so tests can run without trickery and dry runs cover the same code paths as real runs.
- Validate early, fail fast, then do side effects. Follow a plan->apply pattern.
- Operate on explicit targets (--id, --path), not implicit "current" state

## Dual operation

Build the CLI application for humans and agents i.e. for interactive use and for automation.

- Detect TTY or not and branch into interactive vs non-interactive mode.
- Be safe: confirm destructive ops, support --yes to skip in scripts, never prompt when stdin is not interactive.
- Discovery: Make --help complete, machine-parseable, and consistent.
- Offer --json structured output everywhere.
- Keep outputs small by default to save tokens. Never dump hundreds of log lines without explicitly turned on.
- Be explicit about pagination and truncation ("showing 10 of 100 results, use --page=N to see more").
- Offer cheap status/doctor sanity checks to keep agents on track.
- Stateless design wherever possible. If you need state: Explicit state (pending → running → succeeded/failed/cancelled) persisted locally or server-side, with status/wait/cancel commands reading them. Avoids ad-hoc polling logic scattered across commands.

## Delivery

- Package the CLI application as a single binary, or a single script with no dependencies.

