#!/usr/bin/env bash
#
# integrate-bakasu.sh — BakaSU integration into a kernel tree.
#
# Usage: integrate-bakasu.sh <kernel-root> [fragment-out] [hook_extra_mode] [hook_type]
#
#   hook_extra_mode: lsm     (default) — the 3 optional hooks (setuid / initrc
#                                      / input) are handled by BakaSU's LSM
#                                      + input_handler AUTO machinery; NO extra
#                                      source patches are applied and the three
#                                      CONFIG_KSU_MANUAL_HOOK_AUTO_* are =y.
#                    manual            — the 3 optional hooks are applied as real
#                                      source patches (patches/bakasu/4.9/
#                                      0010..0012) and the three
#                                      AUTO options are turned OFF so BakaSU's
#                                      compile-time check requires the manually
#                                      added ksu_handle_* symbols instead.
#
#   BAKASU_REF can override the pinned commit for a deliberate source update.
#   hook_type:     manual (default) — source-hook integration: BakaSU main
#                                    branch + the mandatory source patches
#                                    (0001..0004, applied by apply-patches.sh
#                                    before this script runs).
#                  susfs           — BakaSU main + SuSFS inline hook:
#                                    kernel-side susfs (fs/susfs.c + hook
#                                    points) must be applied by the caller;
#                                    fragment selects CONFIG_KSU_SUSFS=y
#                                    (KernelSU-side Kconfig choice).
#
# Steps:
#   1. Kernel-side mandatory source patches (stat/exec/open/reboot) are applied
#      by apply-patches.sh — caller runs it first for hook_type=manual only.
#   2. Check out the pinned BakaSU source and wire drivers/kernelsu from it.
#   3. Emit the CONFIG_KSU fragment.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

KROOT="${1:?usage: integrate-bakasu.sh <kernel-root> [fragment-out] [hook_extra_mode] [hook_type]}"
FRAG="${2:-$(pwd)/bakasu.config.fragment}"
MODE="${3:-lsm}"
TYPE="${4:-manual}"
case "$MODE" in lsm|manual) ;; *) echo "ERROR: hook_extra_mode must be 'lsm' or 'manual' (got: $MODE)" >&2; exit 2;; esac
case "$TYPE" in manual|susfs) ;; *) echo "ERROR: hook_type must be 'manual' or 'susfs' (got: $TYPE)" >&2; exit 2;; esac

# The source and wiring are pinned. A moving branch makes the preinit runner
# and Kconfig surface unrepeatable.
KSU_MAIN_REF="7b65bde0710b5e7c6f755545cb15a4abd417f3a8"
KSU_REPO="https://github.com/Baka-SU/BakaSU.git"
KSU_REF="${BAKASU_REF:-$KSU_MAIN_REF}"

cd "$KROOT" || exit 1
if [ -d common/drivers ]; then
  DRIVER_DIR="common/drivers"
else
  DRIVER_DIR="drivers"
fi
[ -d "$DRIVER_DIR" ] || { echo "ERROR: drivers/ directory not found" >&2; exit 1; }

# --- 1. BakaSU checkout + the two wiring lines setup.sh performs ---
if [ ! -d KernelSU/.git ]; then
  [ -e KernelSU ] && { echo "ERROR: KernelSU exists but is not a git checkout" >&2; exit 1; }
  git clone --filter=blob:none --no-checkout "$KSU_REPO" KernelSU
  git -C KernelSU fetch --depth=1 origin "$KSU_REF"
  git -C KernelSU checkout -q --detach FETCH_HEAD
else
  actual_ref="$(git -C KernelSU rev-parse HEAD 2>/dev/null || true)"
  want_ref="$(git -C KernelSU rev-parse "$KSU_REF^{commit}" 2>/dev/null || true)"
  [ -n "$want_ref" ] || { echo "ERROR: cannot resolve BakaSU ref $KSU_REF" >&2; exit 1; }
  [ "$actual_ref" = "$want_ref" ] || {
    echo "ERROR: existing BakaSU checkout is not $KSU_REF (got ${actual_ref:-unknown}); use a fresh tree" >&2
    exit 1
  }
fi

actual_ref="$(git -C KernelSU rev-parse HEAD 2>/dev/null || true)"
want_ref="$(git -C KernelSU rev-parse "$KSU_REF^{commit}" 2>/dev/null || true)"
[ -n "$want_ref" ] && [ "$actual_ref" = "$want_ref" ] || {
  echo "ERROR: BakaSU checkout is not the requested commit (wanted $KSU_REF, got ${actual_ref:-unknown})" >&2
  exit 1
}

ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$KROOT/KernelSU/kernel")" "$DRIVER_DIR/kernelsu"
grep -q 'obj-\$(CONFIG_KSU) += kernelsu/' "$DRIVER_DIR/Makefile" || \
  printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$DRIVER_DIR/Makefile"
grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_DIR/Kconfig" || \
  sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_DIR/Kconfig"

# sanity checks
[ -L "$DRIVER_DIR/kernelsu" ] || { echo "ERROR: $DRIVER_DIR/kernelsu symlink missing" >&2; exit 1; }
[ -f "$DRIVER_DIR/kernelsu/Kconfig" ] || { echo "ERROR: $DRIVER_DIR/kernelsu/Kconfig missing" >&2; exit 1; }
grep -q 'obj-\$(CONFIG_KSU) += kernelsu/' "$DRIVER_DIR/Makefile" || { echo "ERROR: $DRIVER_DIR/Makefile not wired" >&2; exit 1; }

# --- 1a. harden BakaSU's PID 1 preinit path ---
# BakaSU builds the embedded PID 1 runner with $(CC) but relies on the kernel's
# computed CLANG_FLAGS.  4.x Kbuild does not export that variable to sub-makes,
# so host clang silently emits an x86_64 runner.  The kernel then replaces
# /system/bin/init with an ELF that cannot execute on the device, and PID 1
# never reaches userspace.  Patch the generator to pass the target triple
# explicitly; build-kernel.sh additionally verifies the generated ELF machine.
# The second patch keeps /proc/self/fd/<fd> within the filename buffer and
# NUL-terminated (fd >= 10 used to overflow the old /system/bin/init buffer).
apply_bakasu_patch() {
  local file="$1" marker="$2" patch="$3" label="$4"
  [ -f "$file" ] || return 0
  if grep -q "$marker" "$file"; then
    echo "$label already present, skipping"
  elif git -C KernelSU apply --check "$patch"; then
    git -C KernelSU apply "$patch"
    echo "$label applied"
  else
    echo "ERROR: BakaSU layout changed; update $patch" >&2
    exit 1
  fi
}

PREINIT_MK="KernelSU/kernel/tools/code_generation/preinit_runner/preinit_runner.mk"
PREINIT_C="KernelSU/kernel/preinit/preinit.c"
apply_bakasu_patch "$PREINIT_MK" "KSU_RUNNER_TARGET_FLAGS" \
  "$REPO_ROOT/patches/bakasu/0100-preinit-runner-target-arch.patch" \
  "BakaSU preinit runner target fix"
apply_bakasu_patch "$PREINIT_C" "filename->name was allocated for INIT_PATH" \
  "$REPO_ROOT/patches/bakasu/0101-preinit-filename-bounds.patch" \
  "BakaSU preinit filename bounds fix"

# --- 1a3. renew the susfs sus-path uid filter after package tracking ---
# 4.x trees reach do_track_throne() through the manual-hook renameat path,
# after /data/system/packages.list.tmp is swapped in; the uid bitmap that
# decides which apps the sus-path feature hides for is rebuilt there.
if [ "$TYPE" = "susfs" ]; then
  apply_bakasu_patch "KernelSU/kernel/manager/throne_tracker.c" "susfs_parse_sus_path_app_strings" \
    "$REPO_ROOT/patches/bakasu/0102-susfs-sus-path-uid-filter-renew.patch" \
    "BakaSU sus path uid-filter renewal"
fi

# --- 2. hook fragment ---
if [ "$TYPE" = "susfs" ]; then
  # SuSFS inline hook: kernel-side susfs is applied by the caller
  # (patches/susfs/), KernelSU-side Kconfig provides the KSU_SUSFS
  # symbols; select the full feature set. KALLSYMS_ALL keeps the
  # static_export_check gate off: without it nine selinux symbols
  # (write_op, sel_mutex, selinux_ops, policy_rwlock, ...) must be
  # de-static'd and exported in the tree.
  echo "==> hook_type=susfs (BakaSU + SuSFS inline hook)"
  cat > "$FRAG" <<'EOF'
CONFIG_KSU=y
CONFIG_KALLSYMS_ALL=y
# CONFIG_KSU_DEBUG is not set
# CONFIG_KSU_TRACEPOINT_HOOK is not set
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
EOF
elif [ "$MODE" = "manual" ]; then
  # Manual extra hooks: AUTO off -> BakaSU requires ksu_handle_setresuid /
  # ksu_handle_sys_read / ksu_handle_input_handle_event present in the source
  # (they are added by patches/bakasu/4.9/0010..0012).
  echo "==> hook_extra_mode=manual (source patches + AUTO off)"
  cat > "$FRAG" <<'EOF'
CONFIG_KSU=y
CONFIG_KALLSYMS_ALL=y
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
CONFIG_KALLSYMS_ALL=y
# CONFIG_KSU_DEBUG is not set
CONFIG_KSU_MANUAL_HOOK=y
# CONFIG_KSU_TRACEPOINT_HOOK is not set
# CONFIG_KSU_SUSFS is not set
CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK=y
CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK=y
CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y
EOF
fi

echo "BakaSU fragment written: $FRAG"
echo "integrate-bakasu.sh: done (hook_extra_mode=$MODE, hook_type=$TYPE)"
