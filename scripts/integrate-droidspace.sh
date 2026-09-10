#!/usr/bin/env bash
#
# integrate-droidspace.sh — Droidspaces/LXC kernel support integration.
#
# Usage: integrate-droidspace.sh <kernel-root> [port-patch-file]
#
# Steps:
#   1. Apply the 4.9 cgroup prefix port
#      (patches/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch,
#      shared by all supported 4.9 devices) so runc/crun see `subsys.file`
#      symlinks on noprefix (systemd-style) cgroup mounts. The port is only
#      passed when the cgroup_port switch is on; a requested port that does
#      not apply cleanly fails the step.
#   2. Kernel config support is merged by merge-defconfig.sh from
#      patches/droidspace/4.9/droidspace.config.
#
set -euo pipefail

KROOT="${1:?usage: integrate-droidspace.sh <kernel-root> [port-patch-file]}"
PORT="${2:-}"

cd "$KROOT"

if [ -n "$PORT" ] && [ -f "$PORT" ]; then
  git apply --check "$PORT" || {
    echo "!! cgroup prefix port requested but does not apply cleanly: $(basename "$PORT")" >&2
    exit 1; }
  echo "==> applying 4.9 cgroup prefix port: $(basename "$PORT")"
  git apply "$PORT"
else
  echo "cgroup prefix port not requested — skipping"
fi

echo "integrate-droidspace.sh: done (config handled by merge-defconfig.sh)"
