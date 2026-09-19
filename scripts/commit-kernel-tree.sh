#!/usr/bin/env bash
#
# commit-kernel-tree.sh — record the patched kernel tree.
#
# usage: commit-kernel-tree.sh <kernel-root> <commit-message>
#
#   <kernel-root>      path of the kernel checkout to commit
#   <commit-message>   message describing the feature patches applied
#
# A tree with uncommitted changes makes the kernel version string carry
# -dirty, so the patched tree is committed before the build starts.
#
set -uo pipefail

kroot="${1:?usage: commit-kernel-tree.sh <kernel-root> <commit-message>}"
msg="${2:?usage: commit-kernel-tree.sh <kernel-root> <commit-message>}"

cd "$kroot"
git config user.email "action@localhost"
git config user.name "kernel-builder"
git add -A
if git diff --cached --quiet; then
  echo "no changes to commit (clean tree)"
else
  git commit -q -m "$msg"
  echo "committed patched tree: $(git rev-parse --short HEAD)"
fi
