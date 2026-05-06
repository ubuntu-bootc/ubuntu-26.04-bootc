# AGENTS.md — ubuntu-26.04-bootc

AI agent guidance for this repository.

## What this repo is

A **minimal bootc base image** for Ubuntu 26.04 LTS "Resolute Raccoon". No
desktop, no display manager, no flatpak. The companion desktop image lives at
[hanthor/ubuntu-26.04-desktop-bootc](https://github.com/ubuntu-bootc/ubuntu-26.04-desktop-bootc)
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
  build.yaml            CI: build + push to ghcr.io/ubuntu-bootc/ubuntu-26.04-bootc
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

- **fs-verity regression** (Ubuntu 26.04 kernel 7.0, commit f77f281b6118):
  - **Status**: Upstream patch accepted (Colin Walters fix, reviewed by Eric Biggers)
  - **Workaround**: `prepare-root.conf` uses `enabled = yes` (composefs fallback works)
  - **Timeline**: Ubuntu kernel backport expected within 1-2 weeks
  - **Issue**: https://github.com/bootc-dev/bootc/issues/2174

- **sysroot.mount quirk** (Ubuntu 26.04, systemd 259.5-0ubuntu3):
  - **Status**: CI smoke test patches BLS with explicit `root=UUID=` as workaround
  - **Note**: Already handled in test-boot workflow

## Pattern for derived images

Because `bootc-rootfs.sh` wipes `/var`, derived images **cannot run `apt-get`**
without first restoring the dpkg database. Use a multi-stage build:

```dockerfile
# Provides pristine dpkg state for restoration
FROM docker.io/library/ubuntu:26.04 AS dpkg-state

FROM ghcr.io/ubuntu-bootc/ubuntu-26.04-bootc:latest AS system

# Restore dpkg/apt so apt-get works again
RUN --mount=type=bind,from=dpkg-state,source=/var,target=/mnt/var \
    cp -a /mnt/var/lib/dpkg /var/lib/ && \
    mkdir -p /var/cache/apt/archives/partial \
             /var/lib/apt/lists/partial \
             /var/log/apt

RUN apt-get update && apt-get install -y my-package && apt-get clean

# Re-run at the end to wipe /var again before committing
COPY shared/bootc-rootfs.sh /tmp/
RUN /tmp/bootc-rootfs.sh && rm /tmp/bootc-rootfs.sh

RUN bootc container lint
```
