#!/usr/bin/env bash
#
# integrate-bbg.sh — Baseband-guard (BBG) integration into a kernel tree.
#
# Usage: integrate-bbg.sh <kernel-root>
#
# Steps:
#   BBG_REF can override the pinned commit for a deliberate source update.
#   1. Run the official Baseband-guard setup.sh from the kernel root. On
#      4.9 (pre-5.1, no DEFINE_LSM) it automatically patches
#      security/selinux (Makefile via sepatch.txt + objsec.h bbg_cred).
#   2. Emit CONFIG_BBG fragment into the given output file
#      (default: ./bbg.config.fragment).
#
# Cleanup/rollback if ever needed: cd <kernel-root>/Baseband-guard and run
# `../Baseband-guard/setup.sh --cleanup`? No — cleanup is a flag of the
# upstream script: run it from the kernel root as
#   curl -LSs https://raw.githubusercontent.com/vc-teahouse/Baseband-guard/main/setup.sh | bash -s -- --cleanup
#
set -euo pipefail

KROOT="${1:?usage: integrate-bbg.sh <kernel-root>}"
FRAG="${2:-$(pwd)/bbg.config.fragment}"
# This is the commit used by the validated full-feature polaris build. The
# setup script is fetched from the same commit and is passed the commit again.
BBG_REF="${BBG_REF:-028ff7fd509e2104596da7cc1ef8e6ce2a0c9082}"
BBG_REPO="https://github.com/vc-teahouse/Baseband-guard.git"

cd "$KROOT" || exit 1

# --- 1. official setup.sh (pinned; skip only when the checkout already matches) ---
want_ref=""
if [ -d Baseband-guard/.git ]; then
  want_ref="$(git -C Baseband-guard rev-parse "$BBG_REF^{commit}" 2>/dev/null || true)"
fi
actual_ref="$(git -C Baseband-guard rev-parse HEAD 2>/dev/null || true)"
if [ -e security/baseband-guard ] && grep -q "baseband-guard" security/Makefile 2>/dev/null && \
   [ -n "$actual_ref" ] && [ "$actual_ref" = "$want_ref" ]; then
  echo "Baseband-guard already integrated at $BBG_REF, skipping setup.sh"
else
  # The upstream setup helper accepts a commit for an already-cloned tree,
  # but its fallback clone uses `git clone --branch <ref>`, which rejects a
  # raw commit SHA. Clone and pin the checkout first, then let setup.sh do
  # only the wiring.
  if [ -d Baseband-guard/.git ]; then
    git -C Baseband-guard fetch --depth=1 origin "$BBG_REF"
    git -C Baseband-guard checkout -q --detach FETCH_HEAD
  else
    git clone --filter=blob:none --no-checkout "$BBG_REPO" Baseband-guard
    git -C Baseband-guard fetch --depth=1 origin "$BBG_REF"
    git -C Baseband-guard checkout -q --detach FETCH_HEAD
  fi
  echo "==> Running official Baseband-guard setup.sh (ref=$BBG_REF) ..."
  curl -fsSL "https://raw.githubusercontent.com/vc-teahouse/Baseband-guard/$BBG_REF/setup.sh" | bash -s "$BBG_REF"
fi

# sanity checks
[ -e security/baseband-guard ] || { echo "ERROR: security/baseband-guard missing" >&2; exit 1; }
grep -q 'obj-$(CONFIG_BBG) += baseband-guard/' security/Makefile || { echo "ERROR: security/Makefile not wired" >&2; exit 1; }
grep -q 'security/baseband-guard/Kconfig' security/Kconfig || { echo "ERROR: security/Kconfig not wired" >&2; exit 1; }
actual_ref="$(git -C Baseband-guard rev-parse HEAD 2>/dev/null || true)"
want_ref="$(git -C Baseband-guard rev-parse "$BBG_REF^{commit}" 2>/dev/null || true)"
[ -n "$want_ref" ] && [ "$actual_ref" = "$want_ref" ] || {
  echo "ERROR: Baseband-guard checkout is not the requested commit (wanted $BBG_REF, got ${actual_ref:-unknown})" >&2
  exit 1
}

# --- 2. fragment ---
# Kernels with the modern LSM framework (DEFINE_LSM in lsm_hooks.h, i.e.
# 5.1+ or 4.19 trees that backported it) require baseband_guard to be
# listed in CONFIG_LSM; the BBG Makefile aborts otherwise. Emit the
# kernel's default CONFIG_LSM list with baseband_guard appended.
# Pre-5.1-style kernels (4.9) patch security/selinux directly and only
# need CONFIG_BBG.
if grep -q "#define DEFINE_LSM(lsm)" include/linux/lsm_hooks.h 2>/dev/null; then
  echo "==> modern LSM framework detected; appending baseband_guard to CONFIG_LSM"
  # extract the last unconditional 'default "..."' of 'config LSM'
  LSM_DEFAULT=$(awk '
    /^config LSM$/ { in_lsm=1; next }
    in_lsm && /^[[:space:]]*config / { exit }
    in_lsm && /^[[:space:]]*default "/ {
      line=$0
      if (line !~ /if[[:space:]]+/) last=line
    }
    END {
      if (match(last, /"([^"]*)"/, m)) print m[1]
    }' security/Kconfig)
  if [ -z "${LSM_DEFAULT:-}" ]; then
    echo "ERROR: could not extract CONFIG_LSM default from security/Kconfig" >&2
    exit 1
  fi
  cat > "$FRAG" <<EOF
CONFIG_BBG=y
CONFIG_LSM="${LSM_DEFAULT},baseband_guard"
EOF
  echo "CONFIG_LSM=\"${LSM_DEFAULT},baseband_guard\""
else
  cat > "$FRAG" <<'EOF'
CONFIG_BBG=y
EOF
fi
echo "BBG fragment written: $FRAG"
echo "integrate-bbg.sh: done"
