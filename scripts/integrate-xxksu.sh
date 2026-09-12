#!/usr/bin/env bash
#
# integrate-xxksu.sh — wire the Backslashxx KernelSU fork (XXKSU) into a kernel tree.
#
# Usage: integrate-xxksu.sh <kernel-root>
#
# env: HOOK_TYPE   syscall_table | branch_link (anything else writes both off)
#      RUNNER_TEMP  scratch directory for the fork clone
#      GITHUB_WORKSPACE  where xxksu.config.fragment is written
#
# Steps:
#   1. Clone the fork and drop its LKM-only Kconfig default line: 4.x Kconfig
#      has no '=' comparison and alldefconfig would abort on it. In-tree
#      CONFIG_KSU=y is set by the fragment written in step 3.
#   2. Link the fork's kernel/ into the tree both as KernelSU/kernel (the
#      in-tree path kernel/Kconfig expects) and drivers/kernelsu (the path the
#      build walks), then register it in drivers/Makefile and drivers/Kconfig.
#      Both links are absolute: a relative target would resolve under drivers/.
#   3. Write the config fragment with exactly one hook engine enabled — the two
#      engines are mutually exclusive at the Kconfig level
#      (KSU_HACK_ARM64_BRANCH_LINK depends on !KSU_TAMPER_SYSCALL_TABLE).
#
set -euo pipefail

KROOT="${1:?usage: integrate-xxksu.sh <kernel-root>}"
: "${RUNNER_TEMP:?RUNNER_TEMP is not set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is not set}"
HOOK_TYPE="${HOOK_TYPE:-none}"

git clone -q --depth=1 --single-branch \
  --branch=master \
  https://github.com/Backslashxx/KernelSU "$RUNNER_TEMP/xxksu"
sed -i '/default y if KSU = m/d' "$RUNNER_TEMP/xxksu/kernel/Kconfig"

cd "$KROOT"
mkdir -p KernelSU
ln -sfn "$RUNNER_TEMP/xxksu/kernel" KernelSU/kernel
ln -sfn "$RUNNER_TEMP/xxksu/kernel" drivers/kernelsu
grep -q "kernelsu" drivers/Makefile || \
  printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> drivers/Makefile
grep -q "drivers/kernelsu/Kconfig" drivers/Kconfig || \
  sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" drivers/Kconfig

case "$HOOK_TYPE" in
  branch_link) ENGINE=branch_link ;;
  syscall_table) ENGINE=syscall_table ;;
  *) ENGINE=none ;;
esac
{
  echo "CONFIG_KSU=y"
  echo "CONFIG_KSU_LSM_SECURITY_HOOKS=y"
  case "$ENGINE" in
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
} > "$GITHUB_WORKSPACE/xxksu.config.fragment"
echo "xxksu mode: $HOOK_TYPE engine: $ENGINE"
cat "$GITHUB_WORKSPACE/xxksu.config.fragment"
