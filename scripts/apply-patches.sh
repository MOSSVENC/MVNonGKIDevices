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
# - Patches must apply cleanly: a strict `git apply --check` is required
#   before the apply, so drifted context is reported instead of merged.
# - Idempotent: if a patch is already applied (reverse-check passes) it is
#   treated as applied; otherwise a clean forward check is required.
# - Any failure exits non-zero without touching the tree.
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
  if git apply --check "$patch" >/dev/null 2>&1; then
    git apply "$patch" >/dev/null && echo "    applied OK" || { echo "    FAILED"; return 1; }
  else
    echo "    cannot apply cleanly (context drift); patch carries its own context" >&2
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
