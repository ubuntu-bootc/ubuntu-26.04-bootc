# AGENTS.md — ubuntu-26.04-bootc

AI agent guidance for this repository.

## What this repo is

A **minimal bootc base image** for Ubuntu 26.04 LTS "Resolute Raccoon". No
desktop, no display manager, no flatpak. The companion desktop image lives at
[hanthor/ubuntu-26.04-desktop-bootc](https://github.com/hanthor/ubuntu-26.04-desktop-bootc)
and is built on top of this one.

## Repository map

```
Containerfile           Multi-stage OCI build (ctx → base → builder → system)
Justfile                build, test-structure
shared/
  build.sh              Compiles bootc v1.15.2 from source
  initramfs.sh          Builds dracut initramfs (bootc module, hostonly=no, zstd)
  bootc-rootfs.sh       Sets up bootc/ostree symlink forest; WIPES /var — see below
.github/workflows/
  build.yaml            CI: build + push to ghcr.io/hanthor/ubuntu-26.04-bootc
```

## Build stages

```
ctx      COPY shared/ scripts
base     ubuntu:26.04 — APT base
builder  Rust toolchain + bootc v1.15.2 compiled from source
system   Kernel, systemd-boot, dracut, openssh, podman, skopeo, sssd, sudo;
         initramfs built; bootc-rootfs.sh run; bootc container lint
```

## Critical constraint: bootc-rootfs.sh wipes /var

`shared/bootc-rootfs.sh` does `rm -rf /var && mkdir -p /var` then creates the
bootc symlink forest. Any file written to `/var/...` before this step is lost.
Use `mkdir -p /var/roothome/...` not `/root/...` during the build.

## Known issues

- Ubuntu 26.04 kernel 7.0 / fs-verity regression breaks composefs-native
  deployment — `prepare-root.conf` uses `enabled = maybe` as a workaround
  until the kernel is patched upstream.
- `systemd-gpt-auto-generator` generates a broken `sysroot.mount` on Ubuntu
  26.04 when no `root=UUID=` is in the BLS entry — the CI smoke test patches
  the BLS entry post-install as a workaround.
