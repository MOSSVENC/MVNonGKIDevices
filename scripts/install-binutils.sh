#!/usr/bin/env bash
#
# install-binutils.sh — host packages the kernel builds need.
#
# usage: install-binutils.sh
#
# git/zip/curl for the checkout and packaging steps, the usual build tools,
# python3 for the helper scripts, the AOSP cross binutils that clang resolves
# <triple>-as/ld through, and dtc for the device trees.
#
# Only packages the runner image lacks are installed. The apt index refresh and
# the install are retried, and a package the image cannot fetch leaves the build
# running on the image toolchain: the gate is the tool binary being on PATH.
set -euo pipefail

PACKAGES=(
  git zip unzip curl bc bison flex libssl-dev make
  libncurses-dev python3 python3-pip
  binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi
  device-tree-compiler
)

BINARIES=(
  git zip unzip curl bc bison flex make python3 dtc
  aarch64-linux-gnu-as arm-linux-gnueabi-as
)

apt_install() {
  local attempt
  for attempt in 1 2 3; do
    if [ "$attempt" -lt 3 ]; then
      sudo apt-get update -qq -o Acquire::Retries=3 || true
    fi
    if sudo apt-get install -y -qq --no-install-recommends "$@"; then
      return 0
    fi
    echo "apt attempt $attempt failed; retrying" >&2
    sleep $((attempt * 10))
  done
  return 1
}

missing=()
for pkg in "${PACKAGES[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "host packages present: ${#PACKAGES[@]}"
else
  echo "installing ${#missing[@]} package(s): ${missing[*]}"
  apt_install "${missing[@]}" ||
    echo "apt could not complete; continuing with the image toolchain" >&2
fi

absent=()
for bin in "${BINARIES[@]}"; do
  command -v "$bin" >/dev/null 2>&1 || absent+=("$bin")
done

if [ "${#absent[@]}" -gt 0 ]; then
  echo "missing host tool(s): ${absent[*]}" >&2
  exit 1
fi
echo "toolchain ready: ${#BINARIES[@]} binaries"
