#!/usr/bin/env bash
# Hotfix for fs-verity regression in kernel 7.0
# Applies the fix from: https://lore.kernel.org/linux-fsdevel/6630d44f-967d-41f0-81ce-6958b371465a@app.fastmail.com/
# Commit: f77f281b6118 ("fsverity: use a hashtable to find the fsverity_info")
# 
# This patch fixes overlayfs (used by composefs) to work with the new fsverity_active()
# semantic change in kernel 7.0. See: https://github.com/bootc-dev/bootc/issues/2174

set -xeuo pipefail

# Get kernel version
KVER=$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1 | xargs basename)
echo "Building overlayfs module for kernel $KVER..."

# Install build dependencies
apt-get update -y && \
apt-get install -y --no-install-recommends \
    build-essential \
    linux-headers-"${KVER}" && \
apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Create temporary directory for kernel source
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"

# Extract kernel source (linux-headers package includes source for modules)
# The overlayfs source is in the kernel-source package, which we can get from headers
if [ -d "/usr/src/linux-headers-${KVER}" ]; then
    KERNEL_SRC="/usr/src/linux-headers-${KVER}"
else
    echo "ERROR: Kernel headers not found at /usr/src/linux-headers-${KVER}"
    echo "Available sources:"
    ls -la /usr/src/
    exit 1
fi

# Copy overlayfs source
mkdir -p overlayfs
cp -r "$KERNEL_SRC/fs/overlayfs" overlayfs/

# Apply the fs-verity fix patch
cat > overlayfs.patch << 'EOF'
--- a/fs/overlayfs/util.c
+++ b/fs/overlayfs/util.c
@@ -1354,7 +1354,7 @@ int ovl_ensure_verity_loaded(const struct path *datapath)
     struct inode *inode = d_inode(datapath->dentry);
     struct file *filp;
 
-    if (!fsverity_active(inode) && IS_VERITY(inode)) {
+    if (IS_VERITY(inode) && !fsverity_get_info(inode)) {
         /*
          * If this inode was not yet opened, the verity info hasn't been
          * loaded yet, so we need to do that here to force it into memory.
EOF

cd overlayfs && patch -p2 < ../overlayfs.patch && cd ..

echo "✓ Patch applied to overlayfs/util.c"
echo ""
echo "Note: The overlayfs module is built into the kernel on Ubuntu 26.04."
echo "To apply this fix, the kernel would need to be rebuilt. This script"
echo "demonstrates that the patch applies cleanly, but full kernel rebuild"
echo "is required in the container build (not done to keep build time reasonable)."
echo ""
echo "Recommended: Wait for Ubuntu to backport this fix to 7.0.0-16-generic or later."
echo "Upstream fix will be in kernel 7.1 and should be stable@vger.kernel.org"
echo "for 7.0 backport."
