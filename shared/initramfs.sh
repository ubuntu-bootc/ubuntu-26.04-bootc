#!/usr/bin/env bash

set -xeuo pipefail

mkdir -p /usr/lib/dracut/dracut.conf.d/

# Fix dracut's search paths for systemd units on Debian/Ubuntu
printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" \
    | tee /usr/lib/dracut/dracut.conf.d/30-ubuntu-bootc-fix-paths.conf

# Build a reproducible, non-host-specific initramfs with bootc, plymouth, and zfs modules.
# zfs-dracut (installed in the image) provides the dracut 'zfs' module needed for ZFS root.
printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" bootc plymouth zfs "\n' \
    | tee /usr/lib/dracut/dracut.conf.d/30-ubuntu-bootc-container-build.conf

KVER_DIR="$(find /usr/lib/modules -maxdepth 1 -type d | grep -vE '\.img$' | tail -n 1)"
dracut --force "${KVER_DIR}/initramfs.img"
