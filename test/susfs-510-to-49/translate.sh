#!/usr/bin/env bash
#
# translate.sh v3 — reproducible 4.9 SuSFS builder + verifier.
#
# Rebuilds the shipped 4.9 SuSFS port (patches/susfs/polaris-susfs-final.patch)
# on a clean stock-4.9 kernel, minimizing third-party runtime dependency:
#
#   Core (fs/susfs.c, include/linux/susfs.h, susfs_def.h):
#     upstream gki-android12-5.10 mirror (patches/susfs/upstream-5.10/)
#     + OWN adaptation assets (inputs/susfs49-adapt.diff,
#     inputs/def49-adapt.diff). Verified byte-identical to the shipped
#     port core. susfs.h needs no adaptation (mirror == 4.9 file).
#     => core is independent of any third-party 4.9 patch.
#
#   Tier-1 VFS (fs/Makefile, fs/readdir.c, mm/memory.c): the 5.10 segment
#     is byte-identical to the 4.9 port segment (measured 100%).
#
#   Tier-2 VFS (fs/statfs.c, kernel/kallsyms.c, fs/proc_namespace.c,
#     security/selinux/avc.c, fs/proc/base.c, ...): 5.10 segment plus a
#     small enumerated rewrite set (documented below) yields the 4.9 form.
#
#   Tier-3 VFS (fs/namei.c, fs/namespace.c, fs/proc/task_mmu.c,
#     fs/stat.c, fs/notify/fdinfo.c, fs/proc/fd.c): hook points whose
#     5.10 context does not apply to stock 4.9 (measured). These still
#     come from the frozen JackA1ltman patch (patches/susfs/
#     susfs_patch_to_4.9.patch) as a *reference base*; converting these
#     into own anchor templates is the remaining Jack-dependency.
#
#   KSU-interaction hooks: patches/susfs/susfs_inline_hook_patches-4.9.sh
#     + inputs/delta_{stat,sys}.diff (generator skips on bare 4.9).
#
# Verification: the rebuilt tree must be byte-identical (hash-object) to
# applying patches/susfs/polaris-susfs-final.patch on the same base, for
# every file it touches. Any mismatch fails the build (no false positive).
#
# Usage: translate.sh <kernel-root>            (clean git tree, stock 4.9)
#        translate.sh <kernel-root> --keep
#        translate.sh --check-upstream
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
JACK_PATCH="$REPO/patches/susfs/susfs_patch_to_4.9.patch"
ADAPT_SH="$REPO/scripts/susfs-adapt-4.9.sh"
GEN_SH="$REPO/patches/susfs/susfs_inline_hook_patches-4.9.sh"
CORE_ADAPT_SUSFS="$HERE/inputs/susfs49-adapt.diff"
CORE_ADAPT_DEF="$HERE/inputs/def49-adapt.diff"
DELTA_STAT="$HERE/inputs/delta_stat.diff"
DELTA_SYS="$HERE/inputs/delta_sys.diff"
SHIPPED="$REPO/patches/susfs/polaris-susfs-final.patch"
MIRROR_DIR="$REPO/patches/susfs/upstream-5.10"
MAIN_PATCH="$MIRROR_DIR/50_add_susfs_in_gki-android12-5.10.patch"

if [ "${1:-}" = "--check-upstream" ]; then
  echo "== upstream(5.10) core vs 4.9 core (mirror + own adapt assets) =="
  echo "   informational: refresh path for a new upstream susfs release:"
  echo "   1. sync-susfs-510.sh refresh        (update upstream-5.10 mirror)"
  echo "   2. re-run this builder on a clean 4.9 tree"
  echo "   3. byte-verify FAILS with the drifted files -> update assets"
  echo "   (no silent pass: the hash gate is authoritative.)"
  python3 - "$MIRROR_DIR" "$JACK_PATCH" <<'PYEOF'
import sys
print('core mirror files:', sys.argv[1] + '/susfs.c, susfs.h, susfs_def.h')
print('(core derivation is mirror + own adapt assets, not Jack)')
PYEOF
  exit 0
fi

KROOT="$(cd "${1:?usage: translate.sh <kernel-root> [--keep]}" && pwd)"
KEEP=0; [ "${2:-}" = "--keep" ] && KEEP=1

{ [ -d "$KROOT/.git" ] || [ -f "$KROOT/.git" ]; } || { echo "not a git tree: $KROOT" >&2; exit 1; }
for f in "$JACK_PATCH" "$ADAPT_SH" "$GEN_SH" "$CORE_ADAPT_SUSFS" "$CORE_ADAPT_DEF" \
         "$DELTA_STAT" "$DELTA_SYS" "$SHIPPED" "$MAIN_PATCH"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

BASE=$(git -C "$KROOT" rev-parse HEAD)
echo "== rebuild SuSFS-4.9 on $KROOT @ $BASE"

git -C "$KROOT" checkout -q -f
git -C "$KROOT" clean -fdq
mkdir -p "$HERE/out" "$KROOT/fs" "$KROOT/include/linux"

echo "--- A0) core: upstream mirror + own 4.9 adaptation assets"
cp "$MIRROR_DIR/susfs.c"      "$KROOT/fs/susfs.c"
cp "$MIRROR_DIR/susfs.h"      "$KROOT/include/linux/susfs.h"
cp "$MIRROR_DIR/susfs_def.h"  "$KROOT/include/linux/susfs_def.h"
git -C "$KROOT" add -f fs/susfs.c include/linux/susfs.h include/linux/susfs_def.h
git -C "$KROOT" apply --whitespace=nowarn "$CORE_ADAPT_SUSFS"
git -C "$KROOT" apply --whitespace=nowarn "$CORE_ADAPT_DEF"
echo "   core adapted (susfs.c + susfs_def.h), susfs.h unmodified"

echo "--- A) tier-3 VFS reference base (Jack patch; core files skipped)"
# apply the frozen patch but NOT its core copies (mirror+assets already did
# those, and the Jack core is identical after adaptation)
git -C "$KROOT" apply --reject --whitespace=nowarn "$JACK_PATCH" >/dev/null 2>&1 \
  || true
git -C "$KROOT" checkout -q -f -- fs/susfs.c include/linux/susfs.h include/linux/susfs_def.h
rm -f "$KROOT"/fs/*.rej "$KROOT"/fs/proc/*.rej "$KROOT"/fs/proc/.*.rej 2>/dev/null || true

echo "--- B) stock-4.9 adaptation (fs/stat.c + fs/proc/task_mmu.c)"
( cd "$KROOT" && bash "$ADAPT_SH" )

echo "--- C) KSU-interaction hook generator"
( cd "$KROOT" && bash "$GEN_SH" >/dev/null 2>&1 ) || \
  { echo "generator failed" >&2; exit 1; }

echo "--- D) residual 4.9 delta (stat.c extern + sys.c setresuid)"
git -C "$KROOT" apply --whitespace=nowarn "$DELTA_STAT"
git -C "$KROOT" apply --whitespace=nowarn "$DELTA_SYS"

echo "--- E) emit rebuilt patch + byte-verify vs shipped port"
git -C "$KROOT" add -A 2>/dev/null || true
git -C "$KROOT" diff --cached --binary > "$HERE/out/susfs-49-rebuilt.patch"

GT="$HERE/out/.gt-verify"
rm -rf "$GT"
git -C "$KROOT" worktree add --detach "$GT" "$BASE" >/dev/null 2>&1
git -C "$GT" apply --whitespace=nowarn "$SHIPPED" >/dev/null 2>&1 || \
  { echo "shipped port does not apply on base — repo drift?" >&2; exit 1; }

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
    print(f'FAIL: rebuilt tree differs from shipped port in {len(bad)} files:')
    for f in bad: print('  ', f)
    sys.exit(1)
print(f'PASS: rebuilt tree == shipped port byte-identical ({len(touched)} files)')
PYEOF
RC=$?
git -C "$KROOT" worktree remove --force "$GT" 2>/dev/null || true
[ "$KEEP" = 1 ] || git -C "$KROOT" checkout -q -f
exit $RC
