#!/usr/bin/env bash
#
# integrate-droidspace.sh — Droidspaces/LXC kernel support integration.
#
# Usage: integrate-droidspace.sh <kernel-root> [port-patch-file]
#
# Steps:
#   1. The official non-GKI patch "01 (xt_qtaguid panic fix)" is NOT applied:
#      this kernel tree (sdm845 4.9, all branches) does not contain
#      net/netfilter/xt_qtaguid.c, so the patch target does not exist.
#   2. The "02 (cgroup prefix restore)" patch is ported to the 4.9 layout
#      (kernel/cgroup.c) and shipped here as patches/droidspace/polaris/.
#      It is applied with a dry-run first; on failure we warn and continue
#      (4.9 already restores prefixes via cgroup_file_name when not NOPREFIX).
#   3. The bulk of the support is kernel config — handled by
#      merge-defconfig.sh merging patches/droidspace/common/droidspace.config.
#
set -euo pipefail

KROOT="${1:?usage: integrate-droidspace.sh <kernel-root> [port-patch-file]}"
PORT="${2:-}"

cd "$KROOT"

if [ -n "$PORT" ] && [ -f "$PORT" ]; then
  if git apply --check -3 "$PORT" >/dev/null 2>&1; then
    echo "==> applying 4.9 cgroup prefix port: $(basename "$PORT")"
    git apply -3 "$PORT"
  else
    echo "!! 4.9 cgroup port does not apply cleanly; skipping (non-fatal)."
    echo "   4.9 cgroup_file_name() already restores prefixed names when the"
    echo "   root is NOT mounted noprefix; this port only matters for runc/"
    echo "   crun against noprefix (systemd) mounts."
  fi
else
  echo "No cgroup port patch provided/found — skipping (non-fatal)."
fi

echo "integrate-droidspace.sh: done (config handled by merge-defconfig.sh)"
