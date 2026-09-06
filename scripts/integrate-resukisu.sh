#!/usr/bin/env bash
#
# integrate-resukisu.sh — ReSukiSU integration into a kernel tree.
#
# Usage: integrate-resukisu.sh <kernel-root> [fragment-out] [hook_extra_mode] [hook_type] [auto_fix_49]
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
#   hook_type:     manual (default) — source-hook integration: ReSukiSU main
#                                    branch + the mandatory source patches
#                                    (0001..0004, applied by apply-patches.sh
#                                    before this script runs).
#                  auto            — ReSukiSU auto-hook branch: no source
#                                    patches; ksu_handle_* calls are satisfied
#                                    by the runtime inline-hook engine. The
#                                    fragment carries no CONFIG_KSU_MANUAL_HOOK
#                                    AUTO_* symbols (they do not exist in the
#                                    auto-hook branch Kconfig).
#
# Steps:
#   1. Kernel-side mandatory source patches (stat/exec/open/reboot) are applied
#      by apply-patches.sh — caller runs it first for hook_type=manual only.
#   2. Run the ReSukiSU kernel/setup.sh from the kernel root (main or
#      auto-hook branch, checkout via the setup.sh positional arg).
#   3. Emit the CONFIG_KSU fragment.
#
set -euo pipefail

KROOT="${1:?usage: integrate-resukisu.sh <kernel-root> [fragment-out] [hook_extra_mode] [hook_type] [auto_fix_49]}"
FRAG="${2:-$(pwd)/resukisu.config.fragment}"
MODE="${3:-lsm}"
TYPE="${4:-manual}"
FIX49="${5:-true}"   # auto 模式下修正 auto-hook 分支对 <5.0 内核的 kasan_reset_tag 门槛
case "$MODE" in lsm|manual) ;; *) echo "ERROR: hook_extra_mode must be 'lsm' or 'manual' (got: $MODE)" >&2; exit 2;; esac
case "$TYPE" in manual|auto) ;; *) echo "ERROR: hook_type must be 'manual' or 'auto' (got: $TYPE)" >&2; exit 2;; esac

KSU_BRANCH="main"
if [ "$TYPE" = "auto" ]; then
  KSU_BRANCH="auto-hook"
fi

cd "$KROOT"

# --- 1. ReSukiSU setup.sh (idempotent: skip if already wired) ---
if [ -L drivers/kernelsu ] && [ -d KernelSU ]; then
  echo "ReSukiSU already integrated (drivers/kernelsu symlink exists), skipping setup.sh"
else
  echo "==> Running ReSukiSU setup.sh (branch=$KSU_BRANCH) ..."
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/$KSU_BRANCH/kernel/setup.sh" | bash -s "$KSU_BRANCH"
fi

# sanity checks
[ -L drivers/kernelsu ] || { echo "ERROR: drivers/kernelsu symlink missing after setup.sh" >&2; exit 1; }
[ -f drivers/kernelsu/Kconfig ] || { echo "ERROR: drivers/kernelsu/Kconfig missing" >&2; exit 1; }
grep -q "obj-\$(CONFIG_KSU) += kernelsu/" drivers/Makefile || { echo "ERROR: drivers/Makefile not wired" >&2; exit 1; }

# --- 1b. auto-hook <5.0 compatibility fix (opt-in, default on) ---
# The auto-hook branch guards kasan_reset_tag() (added in v5.0) with
# LINUX_VERSION_CODE < 4.0, so 4.x kernels link-fail on the undefined
# symbol. Rewrite the threshold to 5.0 so 4.x takes the no-op branch.
if [ "$TYPE" = "auto" ] && [ "$FIX49" = "true" ]; then
  TGT="KernelSU/kernel/hook/arm64/inline_hook.c"
  if [ -f "$TGT" ]; then
    if grep -q 'KERNEL_VERSION(5, 0, 0)' "$TGT"; then
      echo "==> auto-hook 4.9 kasan fix already applied, skipping"
    else
      # only the ksu_inline_kasan_reset_tag() guard (the other <4.0 guard in
      # this file, ksu_inline_kasan_module_alloc(), is correct and must stay)
      python3 - "$TGT" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = "#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 0, 0)\n    return p;\n#else\n    return kasan_reset_tag(p);"
new = "#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 0, 0)\n    return p;\n#else\n    return kasan_reset_tag(p);"
assert old in s, "kasan_reset_tag guard not found"
open(p, "w").write(s.replace(old, new, 1))
PYEOF
      echo "==> auto-hook 4.9 kasan_reset_tag threshold fixed (4.0 -> 5.0)"
    fi
  else
    echo "WARN: $TGT not found, kasan fix skipped" >&2
  fi
fi

# --- 2. hook fragment ---
if [ "$TYPE" = "auto" ]; then
  # auto-hook branch: runtime inline-hook engine; its Kconfig has no
  # CONFIG_KSU_MANUAL_HOOK_AUTO_* symbols (those exist only on main).
  echo "==> hook_type=auto (ReSukiSU auto-hook branch)"
  cat > "$FRAG" <<'EOF'
CONFIG_KSU=y
# CONFIG_KSU_DEBUG is not set
CONFIG_KSU_MANUAL_HOOK=y
# CONFIG_KSU_TRACEPOINT_HOOK is not set
# CONFIG_KSU_SUSFS is not set
EOF
elif [ "$MODE" = "manual" ]; then
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
echo "integrate-resukisu.sh: done (hook_extra_mode=$MODE, hook_type=$TYPE)"
