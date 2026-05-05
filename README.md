# ubuntu-26.04-bootc

Minimal Ubuntu 26.04 LTS "Resolute Raccoon" **bootc** base image.
No desktop, no server assumptions — a slim foundation for derived images.

```
ghcr.io/hanthor/ubuntu-26.04-bootc:latest
```

## Image hierarchy

```
docker.io/library/ubuntu:26.04
└── ghcr.io/hanthor/ubuntu-26.04-bootc          ← you are here
    ├── ghcr.io/hanthor/ubuntu-26.04-server-bootc
    └── ghcr.io/hanthor/ubuntu-26.04-desktop-bootc
```

| Image | Description |
|-------|-------------|
| **[ubuntu-26.04-bootc](https://github.com/hanthor/ubuntu-26.04-bootc)** | This image — kernel, bootc, dracut, ssh, podman |
| [ubuntu-26.04-server-bootc](https://github.com/hanthor/ubuntu-26.04-server-bootc) | Server layer — cloud-init, netplan, ufw, snapd, chrony |
| [ubuntu-26.04-desktop-bootc](https://github.com/hanthor/ubuntu-26.04-desktop-bootc) | Desktop layer — GNOME 50, flatpak, ZFS, plymouth |

## What's included

| Component | Package |
|-----------|---------|
| Kernel | `linux-generic` (7.0.0-15-generic) |
| Init | `systemd` |
| Bootloader | `systemd-boot` / `systemd-boot-efi` |
| Initramfs | dracut (bootc module, `hostonly=no`, zstd) |
| SSH | `openssh-server` (enabled) |
| Containers | `podman`, `skopeo` |
| Filesystems | `btrfs-progs`, `e2fsprogs`, `dosfstools`, `xfsprogs` |
| Auth | `sssd`, `sudo` |
| bootc | v1.15.2 (compiled from source) |

## What's not included

- Desktop environment → use [ubuntu-26.04-desktop-bootc](https://github.com/hanthor/ubuntu-26.04-desktop-bootc)
- Server tools (cloud-init, netplan, ufw) → use [ubuntu-26.04-server-bootc](https://github.com/hanthor/ubuntu-26.04-server-bootc)
- Plymouth, Flatpak, ZFS
- `gnome-initial-setup`

## Building locally

```bash
just build
```

## Deriving from this image

```dockerfile
# Restore the dpkg database wiped by bootc-rootfs.sh in the base image
FROM docker.io/library/ubuntu:26.04 AS dpkg-state
FROM ghcr.io/hanthor/ubuntu-26.04-bootc:latest

COPY --from=dpkg-state /var/lib/dpkg /var/lib/dpkg
RUN mkdir -p /var/cache/apt/archives/partial /var/lib/apt/lists/partial /var/log/apt

RUN apt-get update && apt-get install -y my-package && apt-get clean

# Re-run to wipe /var before committing
COPY shared/bootc-rootfs.sh /tmp/
RUN /tmp/bootc-rootfs.sh && rm /tmp/bootc-rootfs.sh

RUN bootc container lint
```

> **Note:** `bootc-rootfs.sh` in this base image wipes `/var`, removing
> the apt/dpkg database. Derived images must restore it from a fresh
> `ubuntu:26.04` stage before running `apt-get`. See `AGENTS.md` for details.

## Known issues

- [#1](https://github.com/hanthor/ubuntu-26.04-desktop-bootc/issues/2) — composefs verity regression on kernel 7.0 (`f77f281b6118`)
- [#2](https://github.com/hanthor/ubuntu-26.04-desktop-bootc/issues/3) — `sysroot.mount` / `systemd-gpt-auto-generator` quirk on Ubuntu 26.04
