#!/usr/bin/env bash
#
# download-toolchain.sh — fetch the shared unified toolchain into $RUNNER_TEMP/tc.
#
# usage: download-toolchain.sh <clang-spec> [<clang-branch>|-] [--gcc32]
#
#   <clang-spec>    either an AOSP clang directory name inside the prebuilt
#                   checkout (e.g. clang-r450784d) or an LLVM release tag
#                   (e.g. llvmorg-19.1.7); the tag form pulls the upstream
#                   LLVM-<version>-Linux-X64 release tarball.
#   <clang-branch>  branch of prebuilts/clang/host/linux-x86 for the AOSP form;
#                   pass `-` (or omit) for the LLVM release form.
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

clang_spec="${1:?usage: download-toolchain.sh <clang-spec> [<clang-branch>|-] [--gcc32]}"
clang_branch="${2:--}"
shift $(( $# >= 2 ? 2 : 1 ))
GCC32=0
for a in "$@"; do
  case "$a" in
    --gcc32) GCC32=1 ;;
    -) ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
: "${RUNNER_TEMP:?RUNNER_TEMP is not set}"
: "${GITHUB_ENV:?GITHUB_ENV is not set}"
: "${GITHUB_PATH:?GITHUB_PATH is not set}"

TC="$RUNNER_TEMP/tc"
mkdir -p "$TC"

case "$clang_spec" in
  llvmorg-*)
    # Upstream LLVM release: LLVM-<version>-Linux-X64.tar.xz, binaries under
    # <root>/local/bin (contains clang, ld.lld, llvm-nm/objcopy/strip/ar).
    ver="${clang_spec#llvmorg-}"
    tarball="LLVM-${ver}-Linux-X64.tar.xz"
    url="https://github.com/llvm/llvm-project/releases/download/${clang_spec}/${tarball}"
    echo "==> LLVM release ${clang_spec}"
    curl -fL --retry 3 --retry-delay 5 -o "$TC/llvm.tar.xz" "$url"
    mkdir -p "$TC/llvm"
    tar -xJf "$TC/llvm.tar.xz" -C "$TC/llvm" --strip-components=1
    rm -f "$TC/llvm.tar.xz"
    CLANG_BIN="$TC/llvm/local/bin"
    ;;
  *)
    if [ "$clang_branch" = "-" ]; then
      echo "ERROR: the AOSP clang form needs <clang-branch> (got '-')" >&2
      exit 2
    fi
    echo "==> AOSP clang ${clang_spec} @ ${clang_branch}"
    git clone -q --depth=1 --single-branch \
      https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
      -b "$clang_branch" "$TC/clang"
    CLANG_BIN="$TC/clang/$clang_spec/bin"
    ;;
esac

ls "$CLANG_BIN/clang" >/dev/null
ls "$CLANG_BIN/ld.lld" >/dev/null
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
