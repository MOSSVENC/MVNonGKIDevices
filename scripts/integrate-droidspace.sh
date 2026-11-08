#!/usr/bin/env bash
#
# integrate-droidspace.sh — Droidspaces/LXC kernel support integration.
#
# Usage: integrate-droidspace.sh <kernel-root> [port-patch-file] [extra-patch ...]
#
# Steps:
#   1. Apply the requested tree-adapted cgroup prefix port so runc/crun see
#      `subsys.file` symlinks on noprefix (systemd-style) cgroup mounts. The
#      port is passed only when the cgroup_port switch is on; a requested port
#      that is missing or does not apply cleanly fails the step.
#   2. Apply any extra tree patches in order (e.g. the !SCHED_WALT scheduler
#      stub for WALT-disabled builds).
#   3. Kernel config support is merged by merge-defconfig.sh from the
#      version-specific droidspace.config fragment.
#
set -euo pipefail

KROOT="${1:?usage: integrate-droidspace.sh <kernel-root> [port-patch-file] [extra-patch ...]}"
PORT="${2:-}"
if [ "$#" -gt 2 ]; then
  shift 2
  EXTRA=("$@")
else
  EXTRA=()
fi

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

for p in "${EXTRA[@]}"; do
  [ -f "$p" ] || { echo "requested patch does not exist: $p" >&2; exit 1; }
  if git apply --check -R "$p" >/dev/null 2>&1; then
    echo "extra patch already applied: $(basename "$p")"
  elif git apply --check "$p" >/dev/null 2>&1; then
    echo "==> applying extra patch: $(basename "$p")"
    git apply "$p"
  else
    echo "extra patch does not apply cleanly: $(basename "$p")" >&2
    exit 1
  fi
done

echo "integrate-droidspace.sh: done (config handled by merge-defconfig.sh)"
