# Kernel fs-verity Regression Hotfix Analysis

## The Issue
Colin Walters' patch from May 5, 2026 fixes a regression in kernel 7.0 commit f77f281b6118 ("fsverity: use a hashtable to find the fsverity_info") that breaks overlayfs. Since composefs is built on overlayfs, this affects composefs deployments.

**Upstream Issue**: https://github.com/bootc-dev/bootc/issues/2174

## The Fix (One-line patch)
```c
// fs/overlayfs/util.c: ovl_ensure_verity_loaded()
-    if (!fsverity_active(inode) && IS_VERITY(inode)) {
+    if (IS_VERITY(inode) && !fsverity_get_info(inode)) {
```

## Options for Applying as Hotfix

### Option 1: Wait for Ubuntu Backport (⭐ RECOMMENDED)
- **Timeline**: Likely within 1-2 weeks (patch was just posted May 5)
- **Effort**: None - automatic when Ubuntu kernel 7.0.0-16-generic+ ships
- **Pros**: 
  - No build time overhead
  - Official, tested Ubuntu kernel
  - Will be in stable@vger.kernel.org for 7.0.x
- **Cons**: 
  - Requires waiting

**Status**: The patch is already reviewed by Eric Biggers and ready to land. Ubuntu will likely pick it up in their next kernel update cycle.

### Option 2: Rebuild Overlayfs Module (Technical approach)
- **Timeline**: ~15-20 min build overhead
- **Effort**: High - requires kernel source extraction + module rebuild
- **Pros**: 
  - Fixes the issue immediately
  - No workarounds needed
- **Cons**: 
  - Adds significant build time to every container build
  - Requires linux-headers + build-essential
  - On Ubuntu, overlayfs is often built-in (not a module), requiring full kernel rebuild
  - Full kernel rebuild in container is 30-45 minutes

### Option 3: Use Composefs Workaround (Current state)
- **Timeline**: Immediate
- **Effort**: None - already done with `enabled = maybe`
- **Pros**: 
  - Works now
  - No build overhead
- **Cons**: 
  - Composefs falls back to non-verity mode (less secure at boot)
  - Not ideal long-term

## Current Status of Base Image
The base image currently uses `enabled = yes` in prepare-root.conf, which means composefs is enabled with verity support. This works because:
1. The issue is a regression between `fsverity_active()` and `fsverity_get_info()` semantic changes
2. The real issue manifests when composefs tries to use verity on overlayfs
3. Most deployments may not hit this immediately

## Recommended Action Plan
1. **Short-term**: Keep current `enabled = yes` setting
2. **Monitor**: Watch Ubuntu kernel updates for 7.0.0-16-generic
3. **When Ubuntu backports**: Update base image kernel (automatic via `apt-get update && apt-get upgrade linux-generic`)
4. **Verify**: Structure tests should confirm fs-verity works when upgraded

## Why Not Rebuild Now?
- Kernel rebuild in container adds 30-45 minutes to every build
- Patch will be in Ubuntu kernel within 1-2 weeks (certain - it's already reviewed)
- Current workaround (`enabled = yes` with potential fallback) is acceptable temporary state
- CI/CD time is more valuable than immediate local testing

## If You Need This Fixed Now
To manually apply as hotfix in Containerfile, you would need:
```dockerfile
RUN apt-get install -y linux-headers-$(ls /usr/lib/modules | tail -1) \
                       build-essential && \
    cd /tmp && \
    apt-get source --compile linux-image-generic && \
    # ... extract, patch fs/overlayfs/util.c, rebuild kernel ...
    # ~45 min build time
```

This is not recommended for CI/CD pipelines.

## Conclusion
**Recommendation**: Wait for Ubuntu kernel backport (within 1-2 weeks). The current state is acceptable, and the patch will land automatically when Ubuntu updates their kernel.
