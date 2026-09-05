#!/usr/bin/env bash
#
# apply-patches.sh — idempotently apply kernel source patches.
#
# Usage: apply-patches.sh <kernel-root> <patch-dir>...
#
# - Patches are applied with `git apply -3` (3-way merge fallback) from the
#   kernel root, so small line drift across 4.9.x sublevels is tolerated.
# - Idempotent: if a patch is already applied (reverse-check passes) it is
#   skipped; otherwise a clean forward check is required.
# - Any failure leaves the .rej files in place and exits non-zero.
#
set -euo pipefail

KROOT="${1:?usage: apply-patches.sh <kernel-root> <patch-dir>...}"
shift
[ $# -ge 1 ] || { echo "no patch dirs given" >&2; exit 2; }

cd "$KROOT"

for dir in "$@"; do
  [ -d "$dir" ] || { echo "skip (missing dir): $dir"; continue; }
  # deterministic order
  for patch in $(ls "$dir"/*.patch 2>/dev/null | sort); do
    echo "==> apply: $(basename "$patch")"
    # already applied? (reverse-check passes => applied) -> skip
    if git apply --check -R "$patch" >/dev/null 2>&1; then
      echo "    already applied, skipping"
      continue
    fi
    if git apply --check -3 "$patch" >/dev/null 2>&1; then
      git apply -3 "$patch" >/dev/null && echo "    applied OK" || { echo "    FAILED"; exit 1; }
    else
      echo "    cannot apply cleanly (context drift) - see .rej files"
      git apply -3 "$patch" || true
      exit 1
    fi
  done
done

echo "apply-patches.sh: done"
