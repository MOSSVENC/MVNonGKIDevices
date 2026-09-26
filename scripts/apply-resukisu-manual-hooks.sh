#!/usr/bin/env bash
#
# apply-resukisu-manual-hooks.sh — apply the ReSukiSU manual-hook patch set.
#
# usage: apply-resukisu-manual-hooks.sh <kernel-root> <patch-spec> [<extra-spec>]
#
#   <kernel-root>  kernel checkout the patches are applied to
#   <patch-spec>   directory or space-separated patch list for apply-patches.sh
#   <extra-spec>   only used when HOOK_EXTRA=manual, either
#                    glob:<pattern>  append the sorted match list
#                    <list>          append that list verbatim
#
# Absolute paths are required: apply-patches.sh changes into the kernel root
# first, so a relative path would not resolve there.
#
set -uo pipefail

kroot="${1:?usage: apply-resukisu-manual-hooks.sh <kernel-root> <patch-spec> [<extra-spec>]}"
spec="${2:?usage: apply-resukisu-manual-hooks.sh <kernel-root> <patch-spec> [<extra-spec>]}"
extra="${3:-}"

if [ "${HOOK_EXTRA:-lsm}" = "manual" ]; then
  echo "hook_extra=manual: also applying alt manual hooks (input/setuid/sys_read)"
  case "$extra" in
    glob:*) matches="$(ls ${extra#glob:} | sort)"
            [ -n "$matches" ] && spec="$spec $matches" ;;
    "")     : ;;
    *)      spec="$spec $extra" ;;
  esac
else
  echo "hook_extra=lsm: alt hooks handled by LSM/input_handler AUTO machinery"
fi

bash scripts/apply-patches.sh "$kroot" $spec
