#!/usr/bin/env bash
#
# download-toolchain.sh — fetch the shared unified toolchain into $RUNNER_TEMP/tc.
#
# usage: download-toolchain.sh <clang-dir> <clang-branch> [--gcc32]
#
#   <clang-dir>     directory name inside the clang prebuilt checkout,
#                   e.g. clang-r450784d
#   <clang-branch>  branch of prebuilts/clang/host/linux-x86
#   --gcc32         also fetch the 32-bit ARM GCC prebuilt (needed for the
#                   compat vDSO on the 4.9/4.19 trees)
#
# Writes:
#   CLANG_DIR=<abs path>   appended to $GITHUB_ENV (later steps read it)
#   gcc64/bin[:gcc32/bin]:clang/bin  appended to $GITHUB_PATH
#
# The GCC prebuilts are needed because clang (without LLVM=1) resolves
# <triple>-as/ld through the gcc-toolchain style layout.
#
set -euo pipefail

clang_dir="${1:?usage: download-toolchain.sh <clang-dir> <clang-branch> [--gcc32]}"
clang_branch="${2:?usage: download-toolchain.sh <clang-dir> <clang-branch> [--gcc32]}"
shift 2
GCC32=0
for a in "$@"; do
  case "$a" in
    --gcc32) GCC32=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
: "${RUNNER_TEMP:?RUNNER_TEMP is not set}"
: "${GITHUB_ENV:?GITHUB_ENV is not set}"
: "${GITHUB_PATH:?GITHUB_PATH is not set}"

TC="$RUNNER_TEMP/tc"
mkdir -p "$TC"

# AOSP clang (contains clang + ld.lld)
git clone -q --depth=1 --single-branch \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  -b "$clang_branch" "$TC/clang"
CLANG_BIN="$TC/clang/$clang_dir/bin"
ls "$CLANG_BIN/clang" >/dev/null
echo "CLANG_DIR=$CLANG_BIN" >> "$GITHUB_ENV"

# Android GCC 4.9 cross toolchains
git clone -q --depth=1 --single-branch \
  https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 \
  -b android12L-release "$TC/gcc64"
path="$TC/gcc64/bin"
if [ "$GCC32" = 1 ]; then
  git clone -q --depth=1 --single-branch \
    https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
    -b android12L-release "$TC/gcc32"
  path="$path:$TC/gcc32/bin"
fi
echo "$path:$CLANG_BIN" >> "$GITHUB_PATH"
