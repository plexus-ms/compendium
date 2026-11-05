---
title: PLX-Secrets – secrets delivery
short_title: PLX-Secrets
description: Git holds op:// pointers and never values; the configure playbook resolves them from the tenant's vault into .env.secret on the host and re-creates the containers whose environment changed.
code: PLX-Secrets
maturity: standard
binds: host
changed: 0.60.0
depends: [PLX-Platform]
consumes: [PLX-App]
order: 22
---

The app contract says the platform hands the app an environment, through `.env` for values and `.env.secret` for secrets ([§ 3 PLX-App](../contracts/app.md)).
This module is how the secret half gets there: one pointer syntax, resolved by a platform playbook, never by the deploy verb.


## § 1 Where secrets live

> - Secret values MUST live only in the tenant's vault; git holds only references.
> - The vault SHOULD be 1Password.
> - Secrets MUST be resolved when a platform playbook runs, never by the deploy verb.
> - `.env.secret` on the host MUST be owned by the deploy user, mode 0600, never world-readable.

Two flows, both resolved when a platform playbook runs:

- **Platform secrets** (deploy SSH key, registry credentials): the platform repo's committed `secrets.env` is a dotenv file of `op://` pointers, it holds no values, so it is safe in git, and the playbook wrapper (`ansible-playbookw`) runs `op run -- ansible-playbook <playbook>`, which resolves the pointers into env vars either playbook reads.
- **App runtime secrets:** each entry of the app's inventory record `apps[].secrets` is the same kind of `op://` pointer, resolved from the vault by the configure playbook and written to `<app_dir>/.env.secret` on the host; the app's compose file loads it via `env_file`.

One pointer syntax serves both flows, so every vault reference a tenant holds is greppable in one repo, and the inventory record stays free of lookup expressions.
The deploy verb never touches secrets.

Three files sit in the app directory, each with exactly one writer ([§ 3 PLX-Platform](platform.md)); this module's file is `.env.secret`.
No file has two writers.
The app directory is where the two halves of the seam meet: the source repo brings the run shape, the platform brings the environment, and compose joins them by reading the directory.



## § 2 Rotation

> - The playbook MUST re-create the affected containers whenever `.env` or `.env.secret` changed; rotation MUST NOT be left to ride along on whenever the next deploy happens to run.

Rotation is complete only when the running process holds the new value: environment is injected at container *creation*, so rewriting `.env.secret` on its own rotates a file, not a credential.
The full loop, change the vault item → re-run the playbook → re-create the affected containers, closes inside the playbook: the roles that write the two files notify a handler each, and compose re-creates exactly the services whose environment differs.
That handler is a bare `docker compose up -d`, the same invocation the verb and a human use: compose reads `.env` implicitly and the image is pinned in the file, so there is no env-file wiring to encode twice.
A redeploy also picks up the current `.env.secret` as a side effect of re-creating containers, yet the verb itself still never reads, writes, or resolves a secret.

Some images read a credential only when they initialise their data (a database's superuser password); rotating such a value is a two-step act, the running service told first, the vault and playbook second, and the app's marker is where that procedure is written down.


## § 3 Vaults per reader

1Password grants access per vault, so the vaults are cut by who reads them, not by app.
`<tenant>` is read by the platform playbooks and holds the runtime secrets: one item per app with one section per environment (`op://<tenant>/<app>/production/<field>`, `staging` for the second environment, a further section for a further environment), and one item per shared service or host thing.
`<tenant>-ci` is read by the CI's service account and holds CI's own credentials by service (`exoscale/<role>/…`, `bucket-registry`, `bucket-turbo`, `github-app`, `smtp-relay`, `deploy`, `netbird`, the `alerts-email` under `config`) and one item per app for its build-time secrets, `app_<app>`, without an environment dimension, because an image is built once and promoted ([§ 4 PLX-Delivery](delivery.md)).
The repo then holds one Actions secret, the service account token, and every job loads what it needs from the vault by pointer, so a rotation is a change in the vault and nothing in the repo.
Hosts and other non-secret facts never go into a vault: the deploy target of an app per environment is the platform inventory's record ([PLX-Environment](../contracts/environment.md)), and sensitivity is the one property that forces a value out of git.
A vault's environment feature is a developer's convenience for a local `.env`, never a system of record.

Decided 2026-11-04 in the first tenant's CI trial and written here as prose; it becomes requirements when a second tenant holds the two vaults.


## Maintaining

`configure_secrets` writes `.env.secret` and owns its rotation handler; `configure_apps` does the same for `.env` ([§ 3 PLX-Platform](platform.md)).
The secrets role runs before the apps role in the configure playbook, so the first `up` already sees the secrets.
1Password is a suggested default behind a thin adapter: `op.env` is plain dotenv of pointers any vault CLI could resolve, so leaving it means replacing `op run` in the wrapper, not rewriting logic, and recording the substitution in the platform marker.
A 1Password authorization timeout in automation most likely means an unlock prompt went unanswered; retry.
