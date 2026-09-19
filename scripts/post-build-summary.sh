#!/usr/bin/env bash
#
# post-build-summary.sh — append the build's one-screen summary to the run page.
#
# usage: post-build-summary.sh <device> <artifact-list>
#
#   <device>         codename shown in the heading and the log name
#   <artifact-list>  human-readable list of the produced files
#   [extra-line]     optional additional bullet (device-specific note)
#
# Reads the build knobs from the environment (DEFCONFIG, HOOK_MODE, KERNEL_REF,
# ROOT_MANAGER, ENABLE_BBG, ENABLE_DROIDSPACE) and appends to
# $GITHUB_STEP_SUMMARY; a missing summary file is not an error.
#
set -uo pipefail

dev="${1:?usage: post-build-summary.sh <device> <artifact-list> [extra-line]}"
artifacts="${2:?usage: post-build-summary.sh <device> <artifact-list>}"
extra="${3:-}"

{
  echo "## $dev build (${DEFCONFIG:-unknown}, ${HOOK_MODE:-none})"
  echo "- kernel_ref: ${KERNEL_REF:-default}"
  echo "- features: mode=${HOOK_MODE:-none} manager=${ROOT_MANAGER:-none} bbg=${ENABLE_BBG:-false} droidspace=${ENABLE_DROIDSPACE:-false}"
  echo "- artifacts: $artifacts"
  [ -n "$extra" ] && echo "$extra"
} >> "$GITHUB_STEP_SUMMARY" || true
