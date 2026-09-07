#!/usr/bin/env bash
#
# sync-susfs-510.sh — check / refresh the gki-android12-5.10 upstream
# snapshot stored in patches/susfs/upstream-5.10/.
#
# The 5.10 branch is the source of truth for the SuSFS feature set
# (9 features + the compile-time selinux-hide components that depend on
# state-ful selinux APIs). Our 4.9 port (polaris-susfs-final.patch)
# tracks it: when upstream bumps SUSFS_VERSION or changes susfs.c,
# re-derive the 4.9 port from the refreshed snapshot (see README).
#
# Usage:
#   sync-susfs-510.sh check    — compare local snapshot vs upstream, no write
#   sync-susfs-510.sh refresh  — overwrite local snapshot from upstream
#
set -euo pipefail

BASE_URL="https://gitlab.com/simonpunk/susfs4ksu/-/raw/gki-android12-5.10/kernel_patches"
DEST="$(cd "$(dirname "$0")/.." && pwd)/patches/susfs/upstream-5.10"

FILES=(
  "50_add_susfs_in_gki-android12-5.10.patch"
  "KernelSU/10_enable_susfs_for_ksu.patch"
  "fs/susfs.c"
  "include/linux/susfs.h"
  "include/linux/susfs_def.h"
)

# map remote path -> local filename
REMOTE_LOCAL=(
  "50_add_susfs_in_gki-android12-5.10.patch:50_add_susfs_in_gki-android12-5.10.patch"
  "KernelSU/10_enable_susfs_for_ksu.patch:10_enable_susfs_for_ksu.patch"
  "fs/susfs.c:susfs.c"
  "include/linux/susfs.h:susfs.h"
  "include/linux/susfs_def.h:susfs_def.h"
)

upstream_version() {
  curl -sL --max-time 30 "$BASE_URL/include/linux/susfs.h" \
    | grep -E '^#define SUSFS_VERSION' | head -1
}

local_version() {
  grep -E '^#define SUSFS_VERSION' "$DEST/susfs.h" | head -1
}

case "${1:-check}" in
  check)
    echo "== local snapshot:  $(local_version)"
    echo "== upstream now:    $(upstream_version)"
    uv=$(upstream_version | sed 's/.*"\(.*\)".*/\1/')
    lv=$(local_version | sed 's/.*"\(.*\)".*/\1/')
    if [ "$uv" != "$lv" ]; then
      echo ">> DIFFER: upstream $uv != local $lv — run: $0 refresh"
      exit 1
    fi
    echo ">> in sync (version)."
    # also compare susfs.c size as a cheap change signal
    remote_size=$(curl -sIL --max-time 30 "$BASE_URL/fs/susfs.c" | grep -i '^content-length' | tail -1 | tr -dc '0-9')
    local_size=$(wc -c < "$DEST/susfs.c" | tr -d ' ')
    echo ">> susfs.c size: upstream=$remote_size local=$local_size"
    ;;
  refresh)
    mkdir -p "$DEST"
    for entry in "${REMOTE_LOCAL[@]}"; do
      remote="${entry%%:*}"; local="${entry##*:}"
      echo "== fetching $remote"
      curl -sL --max-time 120 "$BASE_URL/$remote" -o "$DEST/$local"
    done
    echo "== refreshed: $(local_version)"
    ;;
  *)
    echo "usage: $0 [check|refresh]" >&2
    exit 2
    ;;
esac
