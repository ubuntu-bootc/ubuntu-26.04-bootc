# ubuntu-26.04-bootc — minimal base image variables
image_name     := env("IMAGE_NAME",     "ubuntu-26.04-bootc")
image_tag      := env("IMAGE_TAG",      "latest")
image_registry := env("IMAGE_REGISTRY", "ghcr.io/hanthor")
container_runtime := env("CONTAINER_RUNTIME", "podman")
sudo_cmd       := env("SUDO_CMD", "sudo")

# ── Build ──────────────────────────────────────────────────────────────────

# Build the minimal bootc base image
build:
    {{sudo_cmd}} {{container_runtime}} build \
        -f Containerfile \
        -t "{{image_name}}:{{image_tag}}" \
        --label "org.opencontainers.image.source=https://github.com/hanthor/ubuntu-26.04-bootc" \
        --label "org.opencontainers.image.description=Minimal Ubuntu 26.04 bootc base image" \
        .

# Remove the locally built image
clean:
    {{sudo_cmd}} {{container_runtime}} rmi "{{image_name}}:{{image_tag}}" 2>/dev/null || true

# ── Test ──────────────────────────────────────────────────────────────────

# Run image structure tests (no kernel/desktop assumptions)
test-structure:
    {{sudo_cmd}} {{container_runtime}} run --rm \
        --security-opt label=disable \
        --security-opt seccomp=unconfined \
        "{{image_name}}:{{image_tag}}" \
        /bin/bash -c ' \
            set -euo pipefail; \
            echo "--- binary checks ---"; \
            for b in bootc dracut ssh systemctl; do \
                command -v "$b" > /dev/null && echo "OK: $b" || { echo "MISSING: $b"; exit 1; }; \
            done; \
            echo "--- kernel module tree ---"; \
            KVER=$(ls /usr/lib/modules | sort -V | tail -1); \
            [[ -d /usr/lib/modules/$KVER/kernel ]] && echo "OK: kernel modules ($KVER)"; \
            echo "--- initramfs ---"; \
            [[ -f /usr/lib/modules/$KVER/initramfs.img ]] && echo "OK: initramfs.img"; \
            echo "--- bootc layout ---"; \
            [[ -L /home ]] && echo "OK: /home -> var/home"; \
            [[ -L /root ]] && echo "OK: /root -> var/roothome"; \
            echo "--- bootc lint ---"; \
            bootc container lint; \
            echo "ALL CHECKS PASSED"; \
        '
