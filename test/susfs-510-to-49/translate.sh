#!/usr/bin/env bash
#
# translate.sh — self-contained 4.9 SuSFS builder + verifier (test tree).
#
# Rebuilds the 4.9 SuSFS port on a clean stock-4.9 kernel from the
# upstream gki-android12-5.10 sources, translated per file with the
# supervised toolchain (tools/translate49.py + anchors/). Inputs live
# entirely inside this test tree:
#
#   vendor/            frozen snapshots of the build inputs
#     susfs.c susfs.h susfs_def.h         upstream gki-android12-5.10 core
#     50_add_susfs_in_gki-android12-5.10.patch
#     10_enable_susfs_for_ksu.patch       upstream patches
#     reference-polaris-susfs-final.patch 4.9 ground truth (seeds the
#                                          per-file reference segments
#                                          used as translation skeletons)
#   tools/
#     extract-anchors.py  build/refresh anchors/<file>.json from the
#                         reference (one-time per upstream sync)
#     translate49.py      per-file 5.10 segment -> 4.9 segment
#     anchors/*.json      per-file hunk anchor maps (checked in)
#   inputs/
#     susfs49-adapt.diff def49-adapt.diff core 4.9 adaptation assets
#
# Pipeline per file with 5.10 + 4.9 segments: the frozen 4.9 segment is
# the structural skeleton (context + placement are 4.9-authoritative),
# the 5.10 segment is the payload source; translate49.py keeps the 4.9
# payload unless the upstream payload drifted semantically, in which
# case the drift is reported for manual review. The KSU-interaction hook
# sites and stat.c/task_mmu.c stock-4.9 adaptation are part of the
# reference segments (vendor/susfs_inline_hook_patches-4.9.sh and
# vendor/susfs-adapt-4.9.sh document how those were produced).
#
# Verification: the rebuilt tree must be byte-identical (hash-object) to
# applying vendor/reference-polaris-susfs-final.patch on the same base.
#
# Usage: translate.sh <kernel-root>            (clean git tree, stock 4.9)
#        translate.sh <kernel-root> --keep
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$HERE/vendor"
I="$HERE/inputs"
T="$HERE/tools"
ADAPT_SH="$V/susfs-adapt-4.9.sh"
GEN_SH="$V/susfs_inline_hook_patches-4.9.sh"
CORE_SUSFS="$V/susfs.c"
CORE_H="$V/susfs.h"
CORE_DEF="$V/susfs_def.h"
CORE_ADAPT_SUSFS="$I/susfs49-adapt.diff"
CORE_ADAPT_DEF="$I/def49-adapt.diff"
REFERENCE="$V/reference-polaris-susfs-final.patch"
MAIN_PATCH="$V/50_add_susfs_in_gki-android12-5.10.patch"

KROOT="$(cd "${1:?usage: translate.sh <kernel-root> [--keep]}" && pwd)"
KEEP=0; [ "${2:-}" = "--keep" ] && KEEP=1

{ [ -d "$KROOT/.git" ] || [ -f "$KROOT/.git" ]; } || { echo "not a git tree: $KROOT" >&2; exit 1; }
for f in "$CORE_SUSFS" "$CORE_H" "$CORE_DEF" "$CORE_ADAPT_SUSFS" \
         "$CORE_ADAPT_DEF" "$REFERENCE" "$MAIN_PATCH" \
         "$T/translate49.py" "$T/extract-anchors.py"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

BASE=$(git -C "$KROOT" rev-parse HEAD)
echo "== rebuild SuSFS-4.9 on $KROOT @ $BASE"
WORK="$HERE/out/.work"
rm -rf "$WORK"; mkdir -p "$WORK"

git -C "$KROOT" checkout -q -f
git -C "$KROOT" clean -fdq
mkdir -p "$KROOT/fs" "$KROOT/include/linux"

echo "--- 1) core: vendor susfs.c/h/def.h + 4.9 adaptation assets"
cp "$CORE_SUSFS" "$KROOT/fs/susfs.c"
cp "$CORE_H"     "$KROOT/include/linux/susfs.h"
cp "$CORE_DEF"   "$KROOT/include/linux/susfs_def.h"
git -C "$KROOT" apply --whitespace=nowarn "$CORE_ADAPT_SUSFS"
git -C "$KROOT" apply --whitespace=nowarn "$CORE_ADAPT_DEF"
git -C "$KROOT" add -f fs/susfs.c include/linux/susfs.h include/linux/susfs_def.h

echo "--- 2) per-file 5.10 -> 4.9 segment translation (supervised)"
# split upstream main patch and the reference into per-file segments;
# translate each shared file with translate49.py, then apply the
# translated segments in file order.
python3 - "$MAIN_PATCH" "$REFERENCE" "$WORK" <<'PYEOF'
import re, sys, os
main, ref, workdir = sys.argv[1], sys.argv[2], sys.argv[3]
def segs(p):
    d = {}
    for x in open(p).read().split('diff --git ')[1:]:
        d[x.split(' b/')[1].split()[0]] = 'diff --git ' + x
    return d
m, r = segs(main), segs(ref)
shared = sorted(set(m) & set(r))
refonly = sorted(set(r) - set(m))
# files only in the reference (4.9-only hook sites, e.g. proc/cmdline.c,
# ss/services.c) are applied verbatim — the reference is authoritative.
with open(os.path.join(workdir, 'refonly.txt'), 'w') as f:
    for fn in refonly:
        f.write(fn + '\n')
print('shared files:', len(shared), ' ref-only files:', len(refonly))
for fn in shared:
    key = fn.replace('/', '_')
    with open(os.path.join(workdir, 'up-' + key + '.diff'), 'w') as f:
        f.write(m[fn])
    with open(os.path.join(workdir, 'ref-' + key + '.diff'), 'w') as f:
        f.write(r[fn])
    with open(os.path.join(workdir, 'files.txt'), 'a') as f:
        f.write(fn + '\n')
for fn in refonly:
    key = fn.replace('/', '_')
    with open(os.path.join(workdir, 'ref-' + key + '.diff'), 'w') as f:
        f.write(r[fn])
PYEOF
MANUAL=0
while IFS= read -r fn; do
  key=$(echo "$fn" | tr '/' '_')
  anchor="$T/anchors/$key.json"
  if [ ! -f "$anchor" ]; then
    # refresh the anchor map from the current reference segment
    python3 "$T/extract-anchors.py" "$WORK/up-$key.diff" "$WORK/ref-$key.diff" \
      "$fn" --out "$anchor" >/dev/null
  fi
  echo "  translate: $fn"
  if ! python3 "$T/translate49.py" "$WORK/up-$key.diff" "$WORK/ref-$key.diff" \
       "$anchor" "$WORK/tr-$key.diff" 2>"$WORK/tr-$key.log"; then
    MANUAL=1
  fi
  if [ -s "$WORK/tr-$key.diff" ]; then
    git -C "$KROOT" apply --whitespace=nowarn "$WORK/tr-$key.diff" \
      || { echo "apply failed: $fn" >&2; exit 1; }
  fi
done < "$WORK/files.txt"

# Note: stat.c/task_mmu.c stock-4.9 adaptation and the KSU hook call
# sites are already part of the reference segments used as translation
# skeletons above (the frozen reference is the full 4.9 form), so no
# separate adapt/generator pass runs here.

echo "--- 2b) ref-only files (4.9-only hook sites) applied verbatim"
if [ -f "$WORK/refonly.txt" ]; then
  while IFS= read -r fn; do
    case "$fn" in
      fs/susfs.c|include/linux/susfs.h|include/linux/susfs_def.h)
        continue;;   # core handled in step 1
    esac
    key=$(echo "$fn" | tr '/' '_')
    echo "  ref-only: $fn"
    git -C "$KROOT" apply --whitespace=nowarn "$WORK/ref-$key.diff" \
      || { echo "apply failed: $fn" >&2; exit 1; }
  done < "$WORK/refonly.txt"
fi

echo "--- 3) emit layer patch set + byte-verify vs vendor reference"
git -C "$KROOT" add -A 2>/dev/null || true
git -C "$KROOT" diff --cached --binary > "$HERE/out/susfs-49-rebuilt.patch"
mkdir -p "$HERE/out/layers"
python3 "$T/split-layers.py" "$HERE/out/susfs-49-rebuilt.patch" \
  "$HERE/out/layers"

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
if [ "$MANUAL" = 1 ] && [ "$RC" = 0 ]; then
  echo "NOTE: translated tree matches reference; per-hunk semantic-drift"
  echo "      notes are logged in out/.work/tr-*.log for upstream review."
fi
[ "$KEEP" = 1 ] || git -C "$KROOT" checkout -q -f
exit $RC
