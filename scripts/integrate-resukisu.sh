#!/usr/bin/env bash
#
# integrate-resukisu.sh — ReSukiSU integration (manual hook) into a kernel tree.
#
# Usage: integrate-resukisu.sh <kernel-root> [fragment-out] [hook_extra_mode]
#
#   hook_extra_mode: lsm     (default) — the 3 optional hooks (setuid / initrc
#                                      / input) are handled by ReSukiSU's LSM
#                                      + input_handler AUTO machinery; NO extra
#                                      source patches are applied and the three
#                                      CONFIG_KSU_MANUAL_HOOK_AUTO_* are =y.
#                    manual            — the 3 optional hooks are applied as real
#                                      source patches (patches/resukisu-manual-
#                                      hook/alt-hooks/0010..0012) and the three
#                                      AUTO options are turned OFF so ReSukiSU's
#                                      compile-time check requires the manually
#                                      added ksu_handle_* symbols instead.
#
# Steps:
#   1. Kernel-side mandatory source patches (stat/exec/open/reboot) are applied
#      by apply-patches.sh — caller runs it first. In "manual" extra mode the
#      alt-hooks patches (input/setuid/sys_read) must also be applied first.
#   2. Run the official ReSukiSU kernel/setup.sh from the kernel root.
#   3. Emit the CONFIG_KSU fragment (AUTO toggles depend on hook_extra_mode).
#
set -euo pipefail

KROOT="${1:?usage: integrate-resukisu.sh <kernel-root> [fragment-out] [hook_extra_mode]}"
FRAG="${2:-$(pwd)/resukisu.config.fragment}"
MODE="${3:-lsm}"
case "$MODE" in lsm|manual) ;; *) echo "ERROR: hook_extra_mode must be 'lsm' or 'manual' (got: $MODE)" >&2; exit 2;; esac

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
if [ "$MODE" = "manual" ]; then
  # Manual extra hooks: AUTO off -> ReSukiSU requires ksu_handle_setresuid /
  # ksu_handle_sys_read / ksu_handle_input_handle_event present in the source
  # (they are added by patches/resukisu-manual-hook/alt-hooks/0010..0012).
  echo "==> hook_extra_mode=manual (source patches + AUTO off)"
  cat > "$FRAG" <<'EOF'
CONFIG_KSU=y
# CONFIG_KSU_DEBUG is not set
CONFIG_KSU_MANUAL_HOOK=y
# CONFIG_KSU_TRACEPOINT_HOOK is not set
# CONFIG_KSU_SUSFS is not set
# CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK is not set
# CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK is not set
# CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK is not set
EOF
else
  # LSM/input_handler AUTO machinery (4.9 < 6.8, default & recommended)
  echo "==> hook_extra_mode=lsm (AUTO machinery)"
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
fi

echo "ReSukiSU fragment written: $FRAG"
echo "integrate-resukisu.sh: done (hook_mode=manual, hook_extra_mode=$MODE)"
