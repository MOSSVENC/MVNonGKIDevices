#!/usr/bin/env bash
#
# translate.sh — self-contained 4.9 SuSFS builder + verifier (test tree).
#
# Rebuilds the 4.9 SuSFS port on a clean stock-4.9 kernel from inputs
# that live entirely inside this test tree (vendor/ + inputs/):
#
#   vendor/            frozen snapshot of the build inputs
#     susfs.c susfs.h susfs_def.h         upstream gki-android12-5.10 core
#     50_add_susfs_in_gki-android12-5.10.patch
#     10_enable_susfs_for_ksu.patch       upstream patches (reference)
#     susfs_patch_to_4.9.patch            frozen 4.9 VFS hook-point base
#     susfs_inline_hook_patches-4.9.sh    KSU-interaction hook generator
#     susfs-adapt-4.9.sh                  stock-4.9 stat.c/task_mmu.c fix
#     reference-polaris-susfs-final.patch byte-verify ground truth
#   inputs/
#     susfs49-adapt.diff def49-adapt.diff core 4.9 adaptation assets
#     delta_stat.diff delta_sys.diff      residual generator-skip delta
#
# No file outside this directory is read or written. Refreshing for a
# new upstream release means updating vendor/susfs.c{,.h,_def.h} and the
# upstream patches, then re-running; the byte-verify gate against
# vendor/reference-polaris-susfs-final.patch reports drift.
#
# Verification: the rebuilt tree must be byte-identical (hash-object) to
# applying vendor/reference-polaris-susfs-final.patch on the same base,
# for every file it touches. Any mismatch fails the build.
#
# Usage: translate.sh <kernel-root>            (clean git tree, stock 4.9)
#        translate.sh <kernel-root> --keep
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$HERE/vendor"
I="$HERE/inputs"
JACK_PATCH="$V/susfs_patch_to_4.9.patch"
ADAPT_SH="$V/susfs-adapt-4.9.sh"
GEN_SH="$V/susfs_inline_hook_patches-4.9.sh"
CORE_SUSFS="$V/susfs.c"
CORE_H="$V/susfs.h"
CORE_DEF="$V/susfs_def.h"
CORE_ADAPT_SUSFS="$I/susfs49-adapt.diff"
CORE_ADAPT_DEF="$I/def49-adapt.diff"
DELTA_STAT="$I/delta_stat.diff"
DELTA_SYS="$I/delta_sys.diff"
REFERENCE="$V/reference-polaris-susfs-final.patch"

KROOT="$(cd "${1:?usage: translate.sh <kernel-root> [--keep]}" && pwd)"
KEEP=0; [ "${2:-}" = "--keep" ] && KEEP=1

{ [ -d "$KROOT/.git" ] || [ -f "$KROOT/.git" ]; } || { echo "not a git tree: $KROOT" >&2; exit 1; }
for f in "$JACK_PATCH" "$ADAPT_SH" "$GEN_SH" "$CORE_SUSFS" "$CORE_H" "$CORE_DEF" \
         "$CORE_ADAPT_SUSFS" "$CORE_ADAPT_DEF" "$DELTA_STAT" "$DELTA_SYS" "$REFERENCE"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

BASE=$(git -C "$KROOT" rev-parse HEAD)
echo "== rebuild SuSFS-4.9 on $KROOT @ $BASE"

git -C "$KROOT" checkout -q -f
git -C "$KROOT" clean -fdq
mkdir -p "$HERE/out" "$KROOT/fs" "$KROOT/include/linux"

echo "--- 1) core: vendor susfs.c/h/def.h + 4.9 adaptation assets"
cp "$CORE_SUSFS" "$KROOT/fs/susfs.c"
cp "$CORE_H"     "$KROOT/include/linux/susfs.h"
cp "$CORE_DEF"   "$KROOT/include/linux/susfs_def.h"
git -C "$KROOT" apply --whitespace=nowarn "$CORE_ADAPT_SUSFS"
git -C "$KROOT" apply --whitespace=nowarn "$CORE_ADAPT_DEF"
git -C "$KROOT" add -f fs/susfs.c include/linux/susfs.h include/linux/susfs_def.h

echo "--- 2) VFS hook-point base (vendor susfs_patch_to_4.9.patch)"
# the base patch carries fs/susfs.c and include/linux/susfs_{h,def.h} as
# new-file segments; those are already in place from step 1 and are
# skipped by git apply ("already exists"), so no core reset is needed.
git -C "$KROOT" apply --reject --whitespace=nowarn "$JACK_PATCH" >/dev/null 2>&1 || true
rm -f "$KROOT"/fs/*.rej "$KROOT"/fs/proc/*.rej 2>/dev/null || true

echo "--- 3) stock-4.9 adaptation (vendor susfs-adapt-4.9.sh)"
( cd "$KROOT" && bash "$ADAPT_SH" )

echo "--- 4) KSU-interaction hook generator (vendor)"
( cd "$KROOT" && bash "$GEN_SH" >/dev/null 2>&1 ) || \
  { echo "generator failed" >&2; exit 1; }

echo "--- 5) residual delta (stat.c extern + sys.c setresuid)"
git -C "$KROOT" apply --whitespace=nowarn "$DELTA_STAT"
git -C "$KROOT" apply --whitespace=nowarn "$DELTA_SYS"

echo "--- 6) emit rebuilt patch + byte-verify vs vendor reference"
git -C "$KROOT" add -A 2>/dev/null || true
git -C "$KROOT" diff --cached --binary > "$HERE/out/susfs-49-rebuilt.patch"

GT="$HERE/out/.gt-verify"
rm -rf "$GT"
git -C "$KROOT" worktree add --detach "$GT" "$BASE" >/dev/null 2>&1
git -C "$GT" apply --whitespace=nowarn "$REFERENCE" >/dev/null 2>&1 || \
  { echo "reference patch does not apply on base — refresh vendor/" >&2; exit 1; }

python3 - "$KROOT" "$GT" <<'PYEOF'
import subprocess, sys, os
def sha(wt, f):
    r = subprocess.run(['git','-C',wt,'hash-object',os.path.join(wt,f)],
                       capture_output=True, text=True)
    return r.stdout.strip()
a, b = sys.argv[1], sys.argv[2]
touched = subprocess.run(['git','-C',b,'diff','--name-only','HEAD'],
                         capture_output=True, text=True).stdout.split()
bad = []
for f in sorted(touched):
    ha, hb = sha(a, f), sha(b, f)
    if ha != hb:
        bad.append(f)
if bad:
    print(f'FAIL: rebuilt tree differs from reference in {len(bad)} files:')
    for f in bad: print('  ', f)
    sys.exit(1)
print(f'PASS: rebuilt tree == reference byte-identical ({len(touched)} files)')
PYEOF
RC=$?
git -C "$KROOT" worktree remove --force "$GT" 2>/dev/null || true
[ "$KEEP" = 1 ] || git -C "$KROOT" checkout -q -f
exit $RC
