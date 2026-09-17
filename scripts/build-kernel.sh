#!/usr/bin/env bash
#
# build-kernel.sh — build the kernel image with the unified clang 14 toolchain.
#
# usage: build-kernel.sh <device-codename> <image-name>
#
#   <device-codename>  log name: logs/<device>-full.log and the summary tail
#   <image-name>       image under arch/arm64/boot, e.g. Image.gz-dtb
#
# env: KROOT, RUNNER_TEMP, CLANG_DIR, CUSTOM_BUILD_TIME, GITHUB_WORKSPACE,
#      GITHUB_STEP_SUMMARY
#
# The build's summary goes to $GITHUB_STEP_SUMMARY; a failing build tail is
# echoed there before the step fails.
#
set -o pipefail

dev="${1:?usage: build-kernel.sh <device-codename> <image-name>}"
image="${2:?usage: build-kernel.sh <device-codename> <image-name>}"
: "${KROOT:?KROOT is not set}"
: "${RUNNER_TEMP:?RUNNER_TEMP is not set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is not set}"

mkdir -p "$GITHUB_WORKSPACE/logs"
# Unified toolchain: AOSP clang 14 + LD=ld.lld.
export PATH="$CLANG_DIR:$PATH"
export KBUILD_BUILD_HOST=build
export KBUILD_BUILD_USER=kernel
cd "$KROOT"
# Absolute toolchain prefixes (JackA1ltman style): the 4.9 arm64 Makefile
# requires CROSS_COMPILE_ARM32 for the compat vDSO and resolves
# $(CROSS_COMPILE_ARM32)ld via which/absolute path; the AOSP GCC 4.9
# prebuilts provide the <triple>-as/ld for clang's external
# assembler/linker when it builds the AArch32 vDSO.
rc=0
# Module-signing key generation writes RSA progress without newlines;
# build it serially first with that output silenced so it cannot
# interleave with the parallel build.
# uname -v timestamp: the build_time input when given, else the build-start
# time in UTC.
if [ -n "$CUSTOM_BUILD_TIME" ]; then
  export KBUILD_BUILD_TIMESTAMP="$CUSTOM_BUILD_TIME"
else
  export KBUILD_BUILD_TIMESTAMP="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
fi
if grep -q '^CONFIG_MODULE_SIG=y' "$RUNNER_TEMP/out/.config" 2>/dev/null; then
  make -j1 O="$RUNNER_TEMP/out" ARCH=arm64 \
  CC="clang" \
  CLANG_TRIPLE="aarch64-linux-gnu-" \
  CROSS_COMPILE="$RUNNER_TEMP/tc/gcc64/bin/aarch64-linux-android-" \
  CROSS_COMPILE_ARM32="$RUNNER_TEMP/tc/gcc32/bin/arm-linux-androideabi-" \
  LD=ld.lld LLVM=1 LLVM_IAS=1 \
  quiet=silent_ certs/ >"$RUNNER_TEMP/certs.log" 2>&1 || {
    echo "certs prebuild failed:" >&2
    tail -30 "$RUNNER_TEMP/certs.log" >&2; }
fi
make -j"$(nproc)" O="$RUNNER_TEMP/out" ARCH=arm64 \
  CC="clang" \
  CLANG_TRIPLE="aarch64-linux-gnu-" \
  CROSS_COMPILE="$RUNNER_TEMP/tc/gcc64/bin/aarch64-linux-android-" \
  CROSS_COMPILE_ARM32="$RUNNER_TEMP/tc/gcc32/bin/arm-linux-androideabi-" \
  LD=ld.lld LLVM=1 LLVM_IAS=1 \
  2>&1 || rc=$?
cp -f "$RUNNER_TEMP/out/.config" "$GITHUB_WORKSPACE/logs/final.config" 2>/dev/null || true
cp -f "$RUNNER_TEMP/out/arch/arm64/boot/$image" "$RUNNER_TEMP/out/$image" 2>/dev/null || true
[ -f "$RUNNER_TEMP/out/arch/arm64/boot/$image" ] || { echo "$image not produced"; rc=1; }
if [ "$rc" != 0 ]; then
  { echo "### build kernel FAILED (rc=$rc)"; tail -100 "$GITHUB_WORKSPACE/logs/$dev-full.log"; } >> "$GITHUB_STEP_SUMMARY" || true
  exit "$rc"
fi
{ echo "### build kernel OK"; tail -20 "$GITHUB_WORKSPACE/logs/$dev-full.log"; } >> "$GITHUB_STEP_SUMMARY" || true
