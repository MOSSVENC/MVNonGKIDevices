#!/usr/bin/env bash
#
# integrate-resukisu.sh — ReSukiSU integration (manual hook) into a kernel tree.
#
# Usage: integrate-resukisu.sh <kernel-root>
#
# Steps:
#   1. Kernel-side manual-hook source patches are applied by apply-patches.sh
#      (patches/resukisu-manual-hook/common/*.patch) — caller runs it first.
#   2. Run the official ReSukiSU kernel/setup.sh from the kernel root.
#      It clones https://github.com/ReSukiSU/ReSukiSU into KernelSU/,
#      symlinks kernel/ -> drivers/kernelsu and wires drivers/Kconfig+Makefile.
#   3. Emit CONFIG_KSU_MANUAL_HOOK fragment into the given output file
#      (default: ./resukisu.config.fragment) for merge-defconfig.sh to use.
#
set -euo pipefail

KROOT="${1:?usage: integrate-resukisu.sh <kernel-root>}"
FRAG="${2:-$(pwd)/resukisu.config.fragment}"

cd "$KROOT"

# --- 1. official setup.sh (idempotent: skip if already wired) ---
if [ -L drivers/kernelsu ] && [ -d KernelSU ]; then
  echo "ReSukiSU already integrated (drivers/kernelsu symlink exists), skipping setup.sh"
else
  echo "==> Running official ReSukiSU setup.sh ..."
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
fi

# sanity checks
[ -L drivers/kernelsu ] || { echo "ERROR: drivers/kernelsu symlink missing after setup.sh" >&2; exit 1; }
[ -f drivers/kernelsu/Kconfig ] || { echo "ERROR: drivers/kernelsu/Kconfig missing" >&2; exit 1; }
grep -q "obj-\$(CONFIG_KSU) += kernelsu/" drivers/Makefile || { echo "ERROR: drivers/Makefile not wired" >&2; exit 1; }

# --- 2. hook mode fragment ---
cat > "$FRAG" <<'EOF'
CONFIG_KSU=y
# CONFIG_KSU_DEBUG is not set
CONFIG_KSU_MANUAL_HOOK=y
# CONFIG_KSU_TRACEPOINT_HOOK is not set
# CONFIG_KSU_SUSFS is not set
CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK=y
CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK=y
CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y
EOF
echo "ReSukiSU fragment written: $FRAG"
echo "integrate-resukisu.sh: done (hook_mode=manual)"
