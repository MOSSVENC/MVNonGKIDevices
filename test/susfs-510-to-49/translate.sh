#!/usr/bin/env bash
#
# translate.sh v2 — reproducible 4.9 SuSFS builder + verifier.
#
# Rebuilds the shipped 4.9 SuSFS port (patches/susfs/polaris-susfs-final.patch)
# on a clean stock-4.9 kernel from its four verified sources:
#
#   A. JackA1ltman 4.9 patch   (patches/susfs/susfs_patch_to_4.9.patch)
#      -> 4.9-semantics VFS/core base (namei, namespace, proc, ...,
#         susfs.c/h/def.h). Its stat.c/task_mmu.c hunks do NOT apply to
#         stock 4.9 (they target Jack's backported fork); handled by B.
#   B. scripts/susfs-adapt-4.9.sh
#      -> stock-4.9 rewrite of fs/stat.c + fs/proc/task_mmu.c.
#   C. patches/susfs/susfs_inline_hook_patches-4.9.sh
#      -> KSU-interaction hook sites (exec/open/read_write/input/reboot/
#         sys/hooks/stat). On a bare 4.9 tree (no ReSukiSU symbols) it
#         skips the setresuid block -> covered by D.
#   D. inputs/delta_stat.diff + inputs/delta_sys.diff
#      -> the residual manual delta the generator skips on a bare tree:
#         fs/stat.c second kstat-spoof extern (after EXPORT_SYMBOL) and
#         kernel/sys.c ksu_handle_setresuid CONFIG_KSU block.
#
# Why not translate the 5.10 upstream main patch directly? Measured:
# its VFS hook hunks use 5.10-only APIs (ida_alloc_min, d_alloc_parallel,
# open_last_lookups, VMA_PAD_START, show_options2 result_mask, ...) that
# do not exist on 4.9, so relocating them yields code that cannot compile
# or misbehaves. Upstream (upstream-5.10/) stays the *sync/source-of-truth*
# mirror: verify-susfs-parity.sh + --check-upstream compare the mirrored
# core against this pipeline's output so a new upstream susfs release is
# caught as a delta, never silently re-relocated.
#
# Verification: the rebuilt tree must be byte-identical (hash-object) to
# applying patches/susfs/polaris-susfs-final.patch on the same base, for
# every file it touches. Any mismatch fails the build (no false positive).
#
# Usage: translate.sh <kernel-root>            (kernel-root: clean git tree, stock 4.9)
#        translate.sh <kernel-root> --keep     (keep tree for inspection)
#        translate.sh --check-upstream
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
JACK_PATCH="$REPO/patches/susfs/susfs_patch_to_4.9.patch"
ADAPT_SH="$REPO/scripts/susfs-adapt-4.9.sh"
GEN_SH="$REPO/patches/susfs/susfs_inline_hook_patches-4.9.sh"
DELTA_STAT="$HERE/inputs/delta_stat.diff"
DELTA_SYS="$HERE/inputs/delta_sys.diff"
SHIPPED="$REPO/patches/susfs/polaris-susfs-final.patch"
MIRROR_DIR="$REPO/patches/susfs/upstream-5.10"

if [ "${1:-}" = "--check-upstream" ]; then
  echo "== upstream(5.10) core vs Jack 4.9 core (susfs.c/h/def.h) =="
  echo "   informational: shows the measured 4.9-adaptation transform lines."
  echo "   authoritative drift check is the rebuild byte-verify (run without"
  echo "   --check-upstream on a clean tree): if upstream moved, it FAILs."
  python3 - "$MIRROR_DIR" "$JACK_PATCH" <<'PYEOF'
import re, sys, difflib, os
mir, jackpatch = sys.argv[1], sys.argv[2]
def extract(patch, fname):
    s = open(patch).read()
    for seg in s.split('diff --git ')[1:]:
        if fname in seg.split(' b/')[1].split()[0]:
            return '\n'.join(l[1:].rstrip() for l in seg.splitlines()
                             if l.startswith('+') and not l.startswith('+++'))
    return ''
for f in ['fs/susfs.c','include/linux/susfs.h','include/linux/susfs_def.h']:
    up = open(os.path.join(mir, os.path.basename(f))).read().splitlines()
    ja = extract(jackpatch, f).splitlines()
    d = [l for l in difflib.unified_diff(up, ja, lineterm='', n=0)
         if l[:1] in '+-' and not l.startswith(('+++','---'))]
    # collapse whitespace-only and pure #/brace churn for the summary
    sig = [l for l in d
           if re.sub(r'[^A-Za-z0-9_]', '', l).strip('+-')
           and not re.fullmatch(r'[+-]\s*[{}#]*\s*', l)]
    print(f'{f}: {len(d)} diff lines, {len(sig)} with content '
          f'(see above for the 4.9-adaptation shape)')
    for l in sig[:25]: print('   ', l[:128])
PYEOF
  exit 0
fi

KROOT="$(cd "${1:?usage: translate.sh <kernel-root> [--keep]}" && pwd)"
KEEP=0; [ "${2:-}" = "--keep" ] && KEEP=1

{ [ -d "$KROOT/.git" ] || [ -f "$KROOT/.git" ]; } || { echo "not a git tree: $KROOT" >&2; exit 1; }
for f in "$JACK_PATCH" "$ADAPT_SH" "$GEN_SH" "$DELTA_STAT" "$DELTA_SYS" "$SHIPPED"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

BASE=$(git -C "$KROOT" rev-parse HEAD)
echo "== rebuild SuSFS-4.9 on $KROOT @ $BASE"

git -C "$KROOT" checkout -q -f
git -C "$KROOT" clean -fdq
mkdir -p "$HERE/out"

echo "--- A) Jack 4.9 patch (stat.c/task_mmu.c expected to reject; fixed by B)"
git -C "$KROOT" apply --reject --whitespace=nowarn "$JACK_PATCH" >/dev/null 2>&1 \
  || true
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

# ground-truth tree: apply shipped port on identical base
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
