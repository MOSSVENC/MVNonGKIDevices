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
#   - default: aarch64 gcc (the era-correct, maximally compatible choice)
#   - set USE_CLANG=1 (or export CC=clang) to build with clang instead
# Note: LLVM_IAS is NOT used — 4.9 predates the Android integrated assembler
# path; the assembler/linker come from CROSS_COMPILE binutils.
# CROSS_COMPILE_ARM32 is mandatory on 4.9 arm64 when CONFIG_COMPAT=y (the
# arch Makefile hard-errors without it — "compat vDSO will not be built").
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
CROSS32="${CROSS_COMPILE_ARM32:-arm-linux-gnueabihf-}"
if [ -n "${CC:-}" ]; then
  echo "==> using CC=$CC CROSS_COMPILE=$CROSS CROSS_COMPILE_ARM32=$CROSS32"
  make O="$OUT" ARCH=arm64 CC="$CC" CROSS_COMPILE="$CROSS" \
       CROSS_COMPILE_ARM32="$CROSS32" -j"$JOBS" "$IMAGE_NAME"
elif [ "${USE_CLANG:-0}" = "1" ] && command -v clang >/dev/null 2>&1; then
  TRIPLE="${CLANG_TRIPLE:-aarch64-linux-gnu-}"
  echo "==> using clang (CLANG_TRIPLE=$TRIPLE, CROSS_COMPILE=$CROSS, CROSS_COMPILE_ARM32=$CROSS32)"
  make O="$OUT" ARCH=arm64 CC=clang CLANG_TRIPLE="$TRIPLE" \
       CROSS_COMPILE="$CROSS" CROSS_COMPILE_ARM32="$CROSS32" \
       -j"$JOBS" "$IMAGE_NAME"
else
  echo "==> using gcc (CROSS_COMPILE=$CROSS, CROSS_COMPILE_ARM32=$CROSS32)"
  make O="$OUT" ARCH=arm64 CROSS_COMPILE="$CROSS" \
       CROSS_COMPILE_ARM32="$CROSS32" -j"$JOBS" "$IMAGE_NAME"
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
