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
set -euo pipefail

sudo apt-get update -qq
sudo apt-get install -y -qq \
  git zip unzip curl bc bison flex libssl-dev make \
  libncurses-dev python3 python3-pip \
  binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi \
  device-tree-compiler
