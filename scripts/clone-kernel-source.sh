#!/usr/bin/env bash
#
# clone-kernel-source.sh — fetch the kernel source and export its location.
#
# usage: clone-kernel-source.sh <repo> <ref> <dest> [tail-lines]
#
#   <repo>        kernel repository URL
#   <ref>         branch or tag to check out
#   <dest>        path the tree is cloned into
#   [tail-lines]  lines of the clone log echoed into the step summary (default 40)
#
# Partial clone: fetch commit+tree first, blobs lazily in batches — avoids
# GitHub's single-pack transfer limit on 1.5GB repos. The clone log is teed so
# a transfer error is readable through the run summary even when the step
# output is truncated.
#
set -o pipefail

repo="${1:?usage: clone-kernel-source.sh <repo> <ref> <dest> [tail-lines]}"
ref="${2:?usage: clone-kernel-source.sh <repo> <ref> <dest> [tail-lines]}"
dest="${3:?usage: clone-kernel-source.sh <repo> <ref> <dest> [tail-lines]}"
tail_lines="${4:-40}"

git config --global http.postBuffer 524288000
git clone --depth=1 --filter=blob:none \
  --branch="$ref" \
  "$repo" \
  "$dest" 2>&1 | tee /tmp/clone.log
echo "KROOT=$dest" >> "$GITHUB_ENV"
head -6 "$dest/Makefile"
{ echo "### kernel clone"; tail -"$tail_lines" /tmp/clone.log; } >> "$GITHUB_STEP_SUMMARY" || true
