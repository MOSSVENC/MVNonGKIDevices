#!/usr/bin/env bash
#
# integrate-xxksu.sh — wire the Backslashxx KernelSU fork (XXKSU) into a tree.
#
# Usage: integrate-xxksu.sh <kernel-root> [fragment-out]
#
# env: HOOK_TYPE      syscall_table | branch_link  (anything else enables no
#                     hook engine; the two engines are mutually exclusive)
#      RUNNER_TEMP    scratch directory for the fork checkout
#      XXKSU_REF      override the pinned fork commit
#
# Steps:
#   1. Check out the fork at the pinned commit and drop its LKM-only Kconfig
#      default line: 4.x Kconfig has no '=' comparison, so alldefconfig aborts
#      on `default y if KSU = m`. CONFIG_KSU=y comes from the fragment.
#   2. Link the fork's kernel/ into the tree as KernelSU/kernel (the in-tree
#      path kernel/Kconfig expects) and as drivers/kernelsu (the path the build
#      walks), then register it in drivers/Makefile and drivers/Kconfig. Both
#      links are absolute: a relative target resolves under drivers/.
#   3. Emit the fragment with exactly one hook engine enabled: the fork's
#      Kconfig makes KSU_HACK_ARM64_BRANCH_LINK depend on
#      !KSU_TAMPER_SYSCALL_TABLE.
#
set -euo pipefail

KROOT="${1:?usage: integrate-xxksu.sh <kernel-root> [fragment-out]}"
FRAG="${2:-$(pwd)/xxksu.config.fragment}"
: "${RUNNER_TEMP:?RUNNER_TEMP is not set}"
HOOK_TYPE="${HOOK_TYPE:-none}"

XXKSU_REPO="https://github.com/Backslashxx/KernelSU.git"
XXKSU_PIN="1b8ce9e15a9402aa2192aed5d381366cf2150f0f"
XXKSU_REF="${XXKSU_REF:-$XXKSU_PIN}"

case "$HOOK_TYPE" in
  syscall_table|branch_link) ;;
  none) ;;
  *) echo "ERROR: hook_type must be 'syscall_table' or 'branch_link' (got: $HOOK_TYPE)" >&2; exit 2;;
esac

SRC="$RUNNER_TEMP/xxksu"
if [ ! -d "$SRC/.git" ]; then
  git clone -q --filter=blob:none --no-checkout "$XXKSU_REPO" "$SRC"
fi
git -C "$SRC" fetch --depth=1 -q origin "$XXKSU_REF"
git -C "$SRC" checkout -q --detach FETCH_HEAD
sed -i '/default y if KSU = m/d' "$SRC/kernel/Kconfig"

KROOT_ABS="$(cd "$KROOT" && pwd)"
if [ -d "$KROOT/KernelSU" ] && [ ! -L "$KROOT/KernelSU" ]; then
  echo "ERROR: KernelSU exists in the tree and is not a directory link; use a fresh tree" >&2
  exit 1
fi
mkdir -p "$KROOT/KernelSU"
ln -sfn "$SRC/kernel" "$KROOT/KernelSU/kernel"
ln -sfn "$SRC/kernel" "$KROOT/drivers/kernelsu"
grep -q 'obj-$(CONFIG_KSU) += kernelsu/' "$KROOT/drivers/Makefile" || \
  printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$KROOT/drivers/Makefile"
grep -q 'source "drivers/kernelsu/Kconfig"' "$KROOT/drivers/Kconfig" || \
  sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$KROOT/drivers/Kconfig"

if [ ! -L "$KROOT/KernelSU/kernel" ] || [ ! -L "$KROOT/drivers/kernelsu" ]; then
  echo "ERROR: fork symlinks missing after wiring ($KROOT_ABS)" >&2
  exit 1
fi

{
  echo "CONFIG_KSU=y"
  echo "CONFIG_KALLSYMS_ALL=y"
  echo "CONFIG_KSU_LSM_SECURITY_HOOKS=y"
  case "$HOOK_TYPE" in
    branch_link)
      echo "CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y"
      echo "# CONFIG_KSU_TAMPER_SYSCALL_TABLE is not set"
      ;;
    syscall_table)
      echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y"
      echo "# CONFIG_KSU_HACK_ARM64_BRANCH_LINK is not set"
      ;;
    *)
      echo "# CONFIG_KSU_TAMPER_SYSCALL_TABLE is not set"
      echo "# CONFIG_KSU_HACK_ARM64_BRANCH_LINK is not set"
      ;;
  esac
} > "$FRAG"

echo "XXKSU checked out at $(git -C "$SRC" rev-parse --short HEAD) (hook_type=$HOOK_TYPE)"
echo "fragment: $FRAG"
cat "$FRAG"
