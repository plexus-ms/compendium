---
title: Installing Proxmox VE on Debian
short_title: Proxmox on Debian
description: Field notes on turning a hoster's stock Debian 13 into a Proxmox VE 9 host, including the traps met on Scaleway Elastic Metal.
---

Some hosters offer no Proxmox VE image, only stock Debian.
The way through is "Debian first, Proxmox on top": let the hoster install Debian 13 (Trixie), then convert it following the upstream guide [Install Proxmox VE on Debian 13 Trixie](https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_13_Trixie).

These notes record what the upstream guide does not say.
They come from automating the conversion with Ansible on a Scaleway Elastic Metal server in September 2026, which took six attempts to get right.
Where a hoster ships a Proxmox image of its own, use that instead and skip all of this.

## The sequence that works

1. Disable cloud-init (`touch /etc/cloud/cloud-init.disabled`), so it stops rewriting the hostname, `/etc/hosts`, and the network config.
2. Set the hostname and make it resolve to the public IP in `/etc/hosts`; remove the `127.0.1.1` entry.
   `pve-cluster` refuses to start when the hostname resolves to a loopback address.
3. Fix grub's install devices (see the traps below), then run `dpkg --configure -a` to recover from any earlier interrupted run.
4. Add the `pve-no-subscription` repository with the Proxmox archive keyring, and run a full upgrade.
5. Install `proxmox-default-kernel` and reboot into it.
6. Preseed postfix as "Local only", then install `proxmox-ve ifupdown2 postfix open-iscsi chrony`.
7. Disable the enterprise repositories that `proxmox-ve` adds (`pve-enterprise.sources`, `ceph.sources`: set `Enabled: false`); without a subscription they fail every `apt update` with a 401.
8. Purge the Debian kernels (`linux-image-amd64`, `linux-image-[0-9]*`) and `os-prober`, then `update-grub`.
9. Switch the network to a `vmbr0` bridge (see below).
10. Create the guest storage: a volume group on the spare partition, a thin pool, and `pvesm add lvmthin local-lvm --vgname pve --thinpool data --content rootdir,images`.
    Create the pool with `lvcreate -l 95%FREE`, so there is room left to grow the pool metadata later.

The keyring lives at `https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg`.
Verify it against the checksum the upstream guide publishes before trusting the repository.

## Traps

### grub fails on the first upgrade

A hoster image may preseed grub for a two-disk RAID layout even when only one disk is in use.
The first `apt full-upgrade` then dies in `grub-pc`'s postinst on the untouched second disk, and leaves dpkg half-configured.

Point grub at the disk holding `/boot` only, before upgrading:

```sh
disk=/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)")
echo "grub-pc grub-pc/install_devices multiselect $disk" | debconf-set-selections
dpkg --configure -a
```

Prefer the disk's `/dev/disk/by-id/` name over `/dev/sda`, since the kernel's naming can change across reboots.

### The bridge config disappears at boot

Installing `ifupdown2` leaves a default config in `/etc/network/interfaces.new`.
Proxmox's `pvenetcommit.service` moves that file over `/etc/network/interfaces` at the next boot, which silently replaces the bridge config and leaves the host without an address.

Delete `/etc/network/interfaces.new` after writing `/etc/network/interfaces`, every time.

### The bridge needs the NIC's MAC address

Hosters commonly forward traffic only for the MAC address they know.
A bridge gets a MAC of its own by default, so the host goes dark the moment the IP moves onto `vmbr0`.
Pin the bridge to the uplink's MAC with `hwaddress`.

For the same reason, guests attached to `vmbr0` are unreachable until the hoster assigns each one an additional IP with a virtual MAC.

### IPv6 stops working on the bridge

ifupdown2 enables forwarding on a bridge that holds an address, and the kernel ignores router advertisements on a forwarding interface.
Set `accept-ra 2` to keep SLAAC working.

### The resulting config

```
auto lo
iface lo inet loopback

iface <uplink> inet manual

auto vmbr0
iface vmbr0 inet static
    address <public-ip>/<prefix>
    gateway <gateway>
    hwaddress <uplink-mac>
    bridge-ports <uplink>
    bridge-stp off
    bridge-fd 0
    accept-ra 2

source /etc/network/interfaces.d/*
```

Alongside it: remove the netplan config, disable `systemd-networkd.service`, `systemd-networkd.socket`, and `systemd-resolved.service`, enable `networking.service`, and replace the resolved stub `/etc/resolv.conf` with a static file naming the real nameservers.

Once the bridge is up, apply later changes with `ifreload -a`; no reboot is needed.

## Switching the network without locking yourself out

The switch from netplan to the bridge happens across a reboot, and a mistake there costs the only way into the host.
On hardware with slow reboots and a console that is not always available, guard it with a dead-man's-switch:

1. Back up `/etc/netplan` and `/etc/resolv.conf` to `/var/backups/pve-net/`.
2. Install a rollback script and a systemd timer with `OnActiveSec=5min`, enabled for the next boot.
3. Write the new config and reboot.
4. Reconnect, check that the default route sits on `vmbr0`, and disable the timer.

If nobody disarms the timer within five minutes of boot, it runs the rollback script:

```sh
#!/bin/sh
exec >>/var/log/pve-net-rollback.log 2>&1
set -x
date
ip -br link; ip -br addr; ip route; ip -6 route
systemctl --no-pager status networking.service
journalctl -b --no-pager -u networking.service

cp -a /var/backups/pve-net/netplan/. /etc/netplan/
cp /var/backups/pve-net/resolv.conf /etc/resolv.conf
mv /etc/network/interfaces /etc/network/interfaces.failed
systemctl disable networking.service pve-net-guard.timer
systemctl enable systemd-networkd.service systemd-networkd.socket systemd-resolved.service
sync
systemctl reboot
```

The script logs the network state before restoring anything, so the cause of the failure is readable after the host returns, without console access.
Create `/var/log/journal` beforehand, so the journal of the failed boot survives as well.

In an automated run, wait for the host to come back even when the reboot times out, then fail with the contents of the rollback log.
Make the switch conditional on the default route not yet being on `vmbr0`, so a rerun retries a rolled-back switch and skips a completed one.

## Scaleway Elastic Metal

- A reboot takes about 8 minutes, most of it firmware POST.
  Set reboot timeouts accordingly (15 minutes worked).
- The BMC remote console is available only for one hour after an OS install.
  This is what makes the rollback guard above worth its effort.
- An install that ends in `error` after about 3 minutes with no details means the server itself is broken.
  Rescue mode and default partitioning did not help; replacing the server did.
- The Debian image logs in as user `debian`, and reinstalls change the host keys.
- The default partitioning spans both disks as RAID.
  A custom schema, passed to the install API, keeps one disk and leaves a partition unformatted for the thin pool.

The partitioning schema, with a 50 GB root and the rest of the disk left for LVM-thin:

```json
{
  "disks": [
    {
      "device": "/dev/sda",
      "partitions": [
        {"label": "legacy", "number": 1, "size": 536870912},
        {"label": "swap",   "number": 2, "size": 4294967296},
        {"label": "boot",   "number": 3, "size": 1073741824},
        {"label": "root",   "number": 4, "size": 53687091200},
        {"label": "data",   "number": 5, "use_all_available_space": true}
      ]
    }
  ],
  "raids": [],
  "filesystems": [
    {"device": "/dev/sda3", "format": "ext4", "mountpoint": "/boot"},
    {"device": "/dev/sda4", "format": "ext4", "mountpoint": "/"}
  ],
  "zfs": {"pools": []}
}
```

Validate it first with `POST /baremetal/v1/zones/<zone>/partitioning-schemas/validate` (body: `partitioning_schema`, `offer_id`, `os_id`).
Then install with `POST /baremetal/v1/zones/<zone>/servers/<server-id>/install` (body: `os_id`, `hostname`, `ssh_key_ids`, `partitioning_schema`), and poll `scw baremetal server get <server-id>` until `.install.status` is `completed`.
The install wipes the disks.
