#!/usr/bin/env bash
#
# build-kernel.sh — compile the assembled polaris kernel and package it.
#
# Usage:
#   build-kernel.sh <kernel-root> <out-dir>
#     env:
#       CC / CLANG_TRIPLE / CROSS_COMPILE  (defaults target clang from PATH)
#       TC_PATH                           (toolchain dir to prepend to PATH)
#       AK3_DIR                           (AnyKernel3 template dir; if set and
#                                          Image.gz-dtb exists, builds a zip)
#       IMAGE_NAME                        (default Image.gz-dtb)
#
# Produces: $OUT/arch/arm64/boot/Image.gz-dtb  (and $OUT/Image.gz-dtb copy)
#
set -euo pipefail

KROOT="${1:?usage: build-kernel.sh <kernel-root> <out-dir>}"
OUT="${2:?}"
IMAGE_NAME="${IMAGE_NAME:-Image.gz-dtb}"

cd "$KROOT"

JOBS="$(nproc)"
echo "==> building kernel with -j${JOBS}"

# toolchain strategy for a 4.9 (2016-era) tree:
#   - honor external CC / CROSS_COMPILE / CLANG_TRIPLE if set
#   - else prefer clang if present (needs aarch64 binutils for as/ld on 4.9)
#   - else fall back to aarch64-linux-gnu- gcc
# Note: LLVM_IAS is NOT used — 4.9 predates the Android integrated assembler
# path; the assembler/linker come from CROSS_COMPILE binutils.
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
if [ -n "${CC:-}" ]; then
  echo "==> using CC=$CC CROSS_COMPILE=$CROSS"
  make O="$OUT" ARCH=arm64 CC="$CC" CROSS_COMPILE="$CROSS" -j"$JOBS" "$IMAGE_NAME"
elif command -v clang >/dev/null 2>&1; then
  TRIPLE="${CLANG_TRIPLE:-aarch64-linux-gnu-}"
  echo "==> using clang (CLANG_TRIPLE=$TRIPLE, CROSS_COMPILE=$CROSS)"
  make O="$OUT" ARCH=arm64 CC=clang CLANG_TRIPLE="$TRIPLE" \
       CROSS_COMPILE="$CROSS" -j"$JOBS" "$IMAGE_NAME"
else
  echo "==> using gcc (CROSS_COMPILE=$CROSS)"
  make O="$OUT" ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$JOBS" "$IMAGE_NAME"
fi

IMG="$OUT/arch/arm64/boot/$IMAGE_NAME"
[ -f "$IMG" ] || { echo "ERROR: $IMG not produced" >&2; exit 1; }
cp -f "$IMG" "$OUT/$IMAGE_NAME"
echo "build-kernel.sh: done -> $OUT/$IMAGE_NAME"

# --- AnyKernel3 packaging (optional) ---
if [ -n "${AK3_DIR:-}" ] && [ -d "$AK3_DIR" ]; then
  cp -f "$IMG" "$AK3_DIR/$IMAGE_NAME"
  ( cd "$AK3_DIR" && zip -r9 "$OUT/anykernel3-polaris.zip" . -x "*.git*" >/dev/null )
  echo "AnyKernel3 zip: $OUT/anykernel3-polaris.zip"
fi
