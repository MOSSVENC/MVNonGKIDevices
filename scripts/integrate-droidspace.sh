#!/usr/bin/env bash
#
# integrate-droidspace.sh — Droidspaces/LXC kernel support integration.
#
# Usage: integrate-droidspace.sh <kernel-root> [port-patch-file]
#
# Steps:
#   1. Apply the requested tree-adapted cgroup prefix port so runc/crun see
#      `subsys.file` symlinks on noprefix (systemd-style) cgroup mounts. The
#      port is passed only when the cgroup_port switch is on; a requested port
#      that is missing or does not apply cleanly fails the step.
#   2. Kernel config support is merged by merge-defconfig.sh from the
#      version-specific droidspace.config fragment.
#
set -euo pipefail

KROOT="${1:?usage: integrate-droidspace.sh <kernel-root> [port-patch-file]}"
PORT="${2:-}"

if [ -n "$PORT" ] && [ ! -f "$PORT" ]; then
  echo "requested cgroup port does not exist: $PORT" >&2
  exit 1
fi

cd "$KROOT" || exit 1

if [ -n "$PORT" ]; then
  if git apply --check -R "$PORT" >/dev/null 2>&1; then
    echo "cgroup prefix port already applied: $(basename "$PORT")"
  elif git apply --check "$PORT" >/dev/null 2>&1; then
    echo "==> applying cgroup prefix port: $(basename "$PORT")"
    git apply "$PORT"
  else
    echo "cgroup prefix port does not apply cleanly: $(basename "$PORT")" >&2
    exit 1
  fi
else
  echo "cgroup prefix port not requested"
fi

echo "integrate-droidspace.sh: done (config handled by merge-defconfig.sh)"
