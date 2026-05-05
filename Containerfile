FROM scratch AS ctx

COPY shared/ /shared

# Ubuntu 26.04 LTS "Resolute Raccoon"
FROM docker.io/library/ubuntu:26.04 AS base

# ── Builder: compile bootc from source ───────────────────────────────────────
FROM base AS builder

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=tmpfs,dst=/boot \
    apt-get update -y && \
    apt-get install -y \
        build-essential \
        curl \
        git \
        go-md2man \
        libostree-dev \
        libzstd-dev \
        make \
        ostree \
        pkgconf && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/*

ENV CARGO_HOME=/tmp/rust
ENV RUSTUP_HOME=/tmp/rust
WORKDIR /home/build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- --profile minimal -y && \
    sh -c ". ${RUSTUP_HOME}/env ; /ctx/shared/build.sh"

# ── System: minimal bootc base image ─────────────────────────────────────────
FROM base AS system
COPY --from=builder /output /

ENV DEBIAN_FRONTEND=noninteractive

# Core system utilities (no kernel yet — install it after hooks are stubbed).
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    apt-get update -y && \
    apt-get install -y \
        btrfs-progs \
        curl \
        dbus \
        dosfstools \
        dracut \
        e2fsprogs \
        fdisk \
        iproute2 \
        less \
        linux-firmware \
        openssh-server \
        podman \
        rsync \
        skopeo \
        sssd \
        sudo \
        systemd \
        systemd-boot \
        systemd-boot-efi \
        vim-tiny \
        xfsprogs && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Stub out kernel/grub/kdump post-install hooks BEFORE installing the kernel.
# We generate the initramfs ourselves with dracut in a later step.
RUN printf '#!/bin/sh\nexit 0\n' | tee \
        /usr/sbin/update-initramfs \
        /usr/sbin/mkinitramfs \
        /usr/sbin/update-grub \
        /usr/sbin/grub-mkconfig > /dev/null && \
    chmod +x \
        /usr/sbin/update-initramfs \
        /usr/sbin/mkinitramfs \
        /usr/sbin/update-grub \
        /usr/sbin/grub-mkconfig && \
    mkdir -p /etc/kernel/postinst.d && \
    printf '#!/bin/sh\nexit 0\n' > /etc/kernel/postinst.d/kdump-tools && \
    chmod +x /etc/kernel/postinst.d/kdump-tools

# Install the kernel (hooks are now stubbed so post-install scripts are no-ops).
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=tmpfs,dst=/boot \
    apt-get update -y && \
    apt-get install -y linux-generic && \
    KVER=$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1 | xargs basename) && \
    cp "/boot/vmlinuz-${KVER}" "/usr/lib/modules/${KVER}/vmlinuz" && \
    rm -rf /boot/* && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN systemctl enable --root / ssh.service

# Build the bootc-compatible initramfs with dracut.
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/shared/initramfs.sh

# Set up the ostree/bootc filesystem layout and symlink forest.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    echo "HOME=/var/home" | tee -a /etc/default/useradd && \
    /ctx/shared/bootc-rootfs.sh

LABEL containers.bootc 1

# Clean up runtime directories left by package post-install scripts.
RUN find /run -mindepth 1 -maxdepth 1 ! -name 'secrets' -exec rm -rf {} + ; \
    rm -rf /tmp/*

RUN bootc container lint
