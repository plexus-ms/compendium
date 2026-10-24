---
title: PLX-Scheduling – scheduled jobs and the dead-man's-switch
short_title: PLX-Scheduling
description: No workflow orchestrator — scheduled jobs are systemd timers, app pipelines are job queues inside the app, and a job that silently stops is noticed by a dead-man's-switch whose concrete mechanism is still open.
code: PLX-Scheduling
kind: approach
maturity: approach
binds: host
depends: [PLX-Platform]
order: 24
---

This module is the stance on scheduled work: what runs it, and how a run that never happens gets noticed.
It is an approach at approach maturity: the stance is settled and in use, but the dead-man's-switch has no shipped mechanism yet, and a module without its primitive carries no requirements.


## § 1 No orchestrator

Plexus stands up no workflow orchestrator (Kestra, Airflow, …) as platform infrastructure.
The jobs one would do are already covered: deploys by the forge's CI ([PLX-CI](ci.md)), backups by systemd timers (`Restart=on-failure`, journald logging), app-internal pipelines by a job queue *inside* the app (BullMQ, pg-boss), deployed as a worker container in the same compose file, so product logic stays out of platform-level infrastructure.
A tenant that finds itself with an orchestrator that barely runs anything migrates its jobs onto those mechanisms or retires it.

Revisit an orchestrator only when workflows span multiple hosts with inter-step dependencies, human-in-the-loop approvals appear, scheduled-job interrelations become hard to track, or backfill or replay matters; if reached, prefer a single vanilla shared instance over a fork.


## § 2 The dead-man's-switch

A scheduled job that fails or does not run raises an alert.
That answers "did a cron silently stop?", the valuable fraction of an orchestrator at near-zero operating cost.
The mechanism is the tenant's choice for now: a per-job check that each run pings on success, or a watcher on the job's output, a timer that alerts when the newest backup snapshot is older than it should be.
Both notice the job that silently stopped, which a failure notification alone does not.

Which mechanism becomes the shipped default, a ping service self-hosted (e.g. Uptime Kuma) or managed (e.g. Healthchecks.io), or a staleness watcher on the job's output, and which channel carries the alert, is decided together with observability (§ 12 PLX).
The stance stands regardless of the tool.


## Maintaining

The module is promoted to standard maturity when a dead-man's-switch mechanism ships as a role and two tenants run it; § 2 then becomes a requirement, and the orchestrator ban of § 1 with it.
Until then the hosting layer's backup server and the host's local mail on failed units are what a tenant has, and they cover failure, not silence.
