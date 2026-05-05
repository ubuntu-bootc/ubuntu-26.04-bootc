# ubuntu-26.04-bootc

Minimal Ubuntu 26.04 LTS "Resolute Raccoon" **bootc** base image.

No desktop environment, no display manager, no flatpak. Designed as a slim
foundation for derived images (server workloads, CI runners, custom desktops).

```
ghcr.io/hanthor/ubuntu-26.04-bootc:latest
```

## What's included

| Component | Package |
|-----------|---------|
| Kernel | `linux-generic` (7.0.0-generic) |
| Init | `systemd` |
| Bootloader | `systemd-boot` / `systemd-boot-efi` |
| Initramfs | dracut (bootc + zstd, `hostonly=no`) |
| SSH | `openssh-server` (enabled) |
| Containers | `podman`, `skopeo` |
| Filesystems | `btrfs-progs`, `e2fsprogs`, `dosfstools`, `xfsprogs` |
| Auth | `sssd`, `sudo` |
| bootc | v1.15.2 (compiled from source) |

## What's not included

- GNOME / any desktop environment → use [ubuntu-26.04-desktop-bootc]
- Plymouth
- Flatpak / Flathub remote
- ZFS (add `zfsutils-linux`, `zfs-dracut`, `linux-modules-zfs-generic` in a derived image)
- `gnome-initial-setup`

## Building locally

```bash
just build
```

## Deriving from this image

```dockerfile
FROM ghcr.io/hanthor/ubuntu-26.04-bootc:latest

RUN apt-get update && apt-get install -y my-package && apt-get clean
```

## Known issues

- **Kernel 7.0 / composefs verity regression** — see [issue #1](../../issues/1)
- **sysroot.mount / systemd-gpt-auto-generator** — see [issue #2](../../issues/2)

## Related

- [ubuntu-26.04-desktop-bootc](https://github.com/hanthor/ubuntu-26.04-desktop-bootc) — GNOME 50 desktop layer built on top of this image
