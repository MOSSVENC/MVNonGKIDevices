#!/usr/bin/env bash
#
# integrate-droidspace.sh — Droidspaces/LXC kernel support integration.
#
# Usage: integrate-droidspace.sh <kernel-root> [port-patch-file]
#
# Steps:
#   1. Apply the 4.9 cgroup prefix port
#      (patches/droidspace/common/0001-cgroup-noprefix-4.9-port.patch,
#      shared by all supported 4.9 devices) so runc/crun see `subsys.file`
#      symlinks on noprefix (systemd-style) cgroup mounts. Dry-run first;
#      if it does not apply, warn and continue — the port matters only for
#      noprefix mounts, and 4.9 already restores prefixed names otherwise.
#   2. Kernel config support is merged by merge-defconfig.sh from
#      patches/droidspace/common/droidspace.config.
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
