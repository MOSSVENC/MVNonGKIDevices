#!/usr/bin/env bash
#
# integrate-bbg.sh — Baseband-guard (BBG) integration into a kernel tree.
#
# Usage: integrate-bbg.sh <kernel-root>
#
# Steps:
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

cd "$KROOT"

# --- 1. official setup.sh (idempotent) ---
if [ -e security/baseband-guard ] && grep -q "baseband-guard" security/Makefile 2>/dev/null; then
  echo "Baseband-guard already integrated, skipping setup.sh"
else
  echo "==> Running official Baseband-guard setup.sh ..."
  curl -LSs "https://raw.githubusercontent.com/vc-teahouse/Baseband-guard/main/setup.sh" | bash
fi

# sanity checks
[ -e security/baseband-guard ] || { echo "ERROR: security/baseband-guard missing" >&2; exit 1; }
grep -q 'obj-$(CONFIG_BBG) += baseband-guard/' security/Makefile || { echo "ERROR: security/Makefile not wired" >&2; exit 1; }
grep -q "security/baseband-guard/Kconfig" security/Kconfig || { echo "ERROR: security/Kconfig not wired" >&2; exit 1; }

# --- 2. fragment ---
cat > "$FRAG" <<'EOF'
CONFIG_BBG=y
EOF
echo "BBG fragment written: $FRAG"
echo "integrate-bbg.sh: done"
