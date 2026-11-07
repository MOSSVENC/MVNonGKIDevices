#!/usr/bin/env bash
#
# verify-preinit-runner.sh — reject a host-architecture BakaSU preinit runner.
#
# usage: verify-preinit-runner.sh <kernel-root> <out-dir>
#
# BakaSU's preinit source builds an embedded PID 1 runner. A 4.x Kbuild
# sub-make may not inherit CLANG_FLAGS, so a careless build can emit an
# x86_64 ELF on the runner host. That ELF cannot execute on the device and
# can leave PID 1 stuck before Android userspace starts. The runner must be
# AArch64 whenever the integrated BakaSU tree carries the preinit source.
#
set -euo pipefail

kroot="${1:?usage: verify-preinit-runner.sh <kernel-root> <out-dir>}"
out="${2:?usage: verify-preinit-runner.sh <kernel-root> <out-dir>}"
cfg="$out/.config"
runner="$out/drivers/kernelsu/preinit/runner.elf"

[ -f "$cfg" ] || { echo "ERROR: kernel config not found: $cfg" >&2; exit 1; }
if ! grep -q '^CONFIG_KSU=y$' "$cfg"; then
  echo "BakaSU preinit runner: not applicable (CONFIG_KSU is not enabled)"
  exit 0
fi

# The auto-hook branch has no preinit source; it is not expected to produce
# this runner. The main branch does have it, including the SuSFS build.
if [ ! -f "$kroot/KernelSU/kernel/preinit/preinit.c" ]; then
  echo "BakaSU preinit runner: not applicable (checkout has no preinit source)"
  exit 0
fi

[ -f "$runner" ] || {
  echo "ERROR: BakaSU preinit runner was not produced: $runner" >&2
  exit 1
}

machine="$(readelf -h "$runner" 2>/dev/null | sed -n 's/^[[:space:]]*Machine:[[:space:]]*//p' | head -n1)"
[ "$machine" = "AArch64" ] || {
  echo "ERROR: BakaSU preinit runner is not AArch64 (readelf: ${machine:-unknown})" >&2
  exit 1
}

echo "BakaSU preinit runner: AArch64 ($runner)"
