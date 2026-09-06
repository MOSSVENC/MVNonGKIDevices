#!/usr/bin/env bash
#
# apply-patches.sh — idempotently apply kernel source patches.
#
# Usage: apply-patches.sh <kernel-root> <patch-dir-or-file>...
#
# Each argument may be:
#   - a directory: every *.patch inside is applied in sorted order
#   - a .patch file: that single patch is applied
# This lets devices share the common/ patches but swap in their own
# device-specific variant of one patch (e.g. daisy/vince use their own
# 0004-reboot patch and must NOT apply common/0004).
#
# - Patches are applied with `git apply -3` (3-way merge fallback) from the
#   kernel root, so small line drift across 4.9.x sublevels is tolerated.
# - Idempotent: if a patch is already applied (reverse-check passes) it is
#   skipped; otherwise a clean forward check is required.
# - Any failure leaves the .rej files in place and exits non-zero.
#
set -euo pipefail

KROOT="${1:?usage: apply-patches.sh <kernel-root> <patch-dir-or-file>...}"
shift
[ $# -ge 1 ] || { echo "no patch dirs/files given" >&2; exit 2; }

cd "$KROOT"

apply_one() { # patch-file
  local patch="$1"
  echo "==> apply: $(basename "$patch")"
  # already applied? (reverse-check passes => applied) -> skip
  if git apply --check -R "$patch" >/dev/null 2>&1; then
    echo "    already applied, skipping"
    return 0
  fi
  if git apply --check -3 "$patch" >/dev/null 2>&1; then
    git apply -3 "$patch" >/dev/null && echo "    applied OK" || { echo "    FAILED"; return 1; }
  else
    echo "    cannot apply cleanly (context drift) - see .rej files"
    git apply -3 "$patch" || true
    return 1
  fi
  return 0
}

for arg in "$@"; do
  if [ -d "$arg" ]; then
    # directory: apply every *.patch in deterministic order
    for patch in $(ls "$arg"/*.patch 2>/dev/null | sort); do
      apply_one "$patch" || exit 1
    done
  elif [ -f "$arg" ]; then
    # single patch file
    apply_one "$arg" || exit 1
  else
    echo "skip (missing): $arg"
  fi
done

echo "apply-patches.sh: done"
