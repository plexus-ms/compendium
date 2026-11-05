---
title: Exoscale field notes
short_title: Exoscale
description: What the maintainers measured and learned running the hybrid CI strategy's throwaway instances on Exoscale — boot times, the intermittent boot stall and how to read a stalled disk, user-data, IAM operations, billing — and the providers rejected on the way.
maturity: note
binds: repo
depends: [PLX-Delivery]
order: 27
---

This page is the field record of the cloud side of [§ 8 PLX-Delivery](delivery.md): the facts that shaped the throwaway instances and that a tenant on the same provider would otherwise rediscover.
It is a note: it states no requirement, and nothing here is a primitive.
Numbers are measurements of November 2026 and age from there; no tenant's identifiers, bucket names or key ids appear here, since those are substance.


## § 1 Why Exoscale

The strategy needs a provider that bills per second, in EUR, has an API that creates a Debian instance with user-data in one call, and runs Docker on a plain VM.
Exoscale met all four in November 2026; the rejections below are the measurements that ruled the others out.
It also credits every running instance with outbound traffic (1.42 GiB per hour of runtime into the organisation's pool), which covers the layer traffic of a build.

- Instance limit: 20 across all zones for a new organisation; types up to `cpu.huge` and `standard.huge`.
- `cpu.extra-large` (8 vCPU, 16 GB) cost €0.23 per hour, billed per second; a 100 GB disk €0.02 per hour, billed also while the instance is stopped.
- Object storage bills egress to the internet per gigabyte; traffic between an instance and a bucket of the same zone does not count, which is why the builders and the registry bucket share one zone.


## § 2 Boot times

Measured from the create call to cloud-init's `final` stage on the stock template `Linux Debian 13 (Trixie) 64-bit` (login user `debian`), with no user-data beyond a marker:

| Zone | Create to cloud-init done |
|---|---|
| de-fra-1 | 25–38 s |
| de-muc-1 | 25–43 s |
| at-vie-2 | 28–35 s |
| ch-gva-2 | up to 74 s |

The create call itself takes about 21 s, and the instance type barely matters.
With Docker installed by cloud-init the figure rises to 39–50 s; pulling a Postgres image afterwards takes 5–7 s.
A stopped instance is back on SSH about 17 s after `start`.
A security group with no rules drops all inbound traffic, which is the group the instances run in.


## § 3 User-data

- User-data has to be gzip-compressed before base64.
  Plain base64 user-data stalled the template's boot before cloud-init ran, four times out of four; compressed, the same content boots.
  The CLI (`exo compute instance create --cloud-init`) compresses; a raw `create-instance` API call has to do so itself.
- The raw API call is preferable to the CLI's `create` in a job: the CLI follows its create with reads of templates, types, security groups and the operation, each of which the daily IAM role would otherwise have to allow.
- Without `--ssh-key`, the CLI registers a single-use SSH key for every create and deletes it afterwards, which puts `register-ssh-key` and `delete-ssh-key` into the daily role; passing a key registered once at setup takes both out.
- The first cloud-init step is the one that matters: arm the self-deletion timers before anything else, so that a boot that fails later still ends.


## § 4 The boot stall

An instance sometimes never comes online: no SSH, no runner registration, no cloud-init `final`.
What is known, from 29 launches on one day with 7 misses, and none in 93 bare probe boots:

- It is random per instance, not per zone, type or time of day.
- It was only ever seen on instances launched from a GitHub-hosted job, three creates within one second, each with a 100 GB disk and real user-data; bare probes from a workstation, single creates with marker user-data, never stalled, not even while a workflow's launches were stalling in the same minute.
- At least one miss was a late boot rather than a dead one: the instance came up two to five minutes after creation.
  Whether the others would have come up was not observed, because they deleted themselves first.
- The one stalled boot whose log was read placed the stall at the network step: the Exoscale datasource hands cloud-init no network configuration, cloud-init applies a fallback DHCP configuration on a NIC it renames to `eth0` by MAC address, and only then fetches metadata and sets the hostname.

It is characterised, not pinpointed.
The launch therefore treats a miss as expected ([§ 8 PLX-Delivery](delivery.md)): it waits a bounded time for the runner to register, keeps and stops the instance that missed, mails, and launches a replacement.

**Reading a stalled disk.**
The logs survive on the instance's disk, and a stopped instance costs only its disk.
In the portal console, reboot the instance, edit the GRUB entry and append `systemd.debug-shell=1`, boot, switch to tty9 for a root shell without a password, and read `/var/log/cloud-init.log` and `/var/log/cloud-init-output.log`; the previous boot's lines are the ones before the reboot.
`journalctl --list-boots` and `journalctl -b -1` give the kernel's and systemd's view of the stalled boot.
If the log is not conclusive, reproduce across a matrix with bare probes, five boots per cell over two templates and two instance types, and count the stalls per cell; a cell that never stalls is the pragmatic answer.


## § 5 IAM

A role per credential, each able to do nothing else, and the daily set separated from the one-time setup:

| Role | Daily | Setup only |
|---|---|---|
| launch and sweep | `create-instance`, `list-instances`, `get-instance`, `delete-instance`, `list-templates`, `get-template`, `list-instance-types`, `get-instance-type`, `list-security-groups`, `get-security-group`, `get-operation`; `stop-instance` for keeping a stalled instance | `create-security-group` once; `register-ssh-key` and `delete-ssh-key` only while the CLI's single-use key is in use (§ 3) |
| self-delete, from user-data | `list-instances` (the CLI resolves an instance by listing, even by id), `get-instance`, `delete-instance`, `get-operation` | none |
| storage | object reads and writes on the Turbo bucket and the two current registry buckets, `create-bucket` and `delete-bucket` for the monthly rotation | the Turbo bucket and its lifecycle rule, the first registry bucket |

Whether IAM can restrict the self-delete role to instances carrying a label is unverified; today it can delete any instance of the organisation.


## § 6 Rejected providers and shapes

- OVH Public Cloud: 91–351 s from create to cloud-init done, and HTTP 503 from the network API during the trial.
- Hetzner Cloud: billed per started hour, which defeats a three-minute instance.
- GARM as the runner orchestrator: no Exoscale provider, and a public stateful service to operate.
- A persistent build VM or a remote BuildKit daemon: idle cost, and memory contention between apps' builds.
- A persistent registry instance on a private network: unreachable from the forge-hosted jobs that look tags up and copy.
- A managed registry at another provider: cross-provider egress on every cache pull and push.
- Providers billing in USD, and platforms without Docker.


## Maintaining

Kept current by whoever runs the hybrid strategy; a number that is re-measured replaces the old one with its date.
The page is linked from § 8.2 PLX, where rented machines are otherwise not covered, and from § 8 PLX-Delivery.
It is promoted to nothing: if a second provider is ever run, its notes get a page of their own, and what both share moves into PLX-Delivery.
