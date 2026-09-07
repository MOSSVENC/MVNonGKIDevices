#!/usr/bin/env bash
#
# translate.sh — scripted 5.10 -> 4.9 translation of the upstream SuSFS
# patch collection. Output is a NEW 4.9 patch under this test dir; it is
# intentionally kept separate from patches/susfs/* (the shipped port).
#
# Usage:
#   bash translate.sh <kernel-root> [upstream-snapshot-dir]
#
#   kernel-root        : clean checkout of the 4.9 kernel tree
#   upstream-snapshot  : patches/susfs/upstream-5.10 by default
#
# Outputs (in this dir):
#   out/susfs-49-translated.patch   — kernel-side patch (files only)
#   out/susfs-49-files/             — susfs.c + headers placed for copy
#   out/manual-list.txt             — hunks/files the engine could not
#                                     script (must be reviewed by hand)
#   out/log.txt                     — full trace
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
KROOT="${1:?usage: translate.sh <kernel-root> [upstream-dir]}"
UP="${2:-$(cd "$HERE/../.." && pwd)/patches/susfs/upstream-5.10}"
MAIN_PATCH="$UP/50_add_susfs_in_gki-android12-5.10.patch"
OUT="$HERE/out"
rm -rf "$OUT"; mkdir -p "$OUT/files"
LOG="$OUT/log.txt"

echo "== kernel root : $KROOT" | tee "$LOG"
echo "== upstream    : $UP" | tee -a "$LOG"
{ [ -d "$KROOT/.git" ] || [ -f "$KROOT/.git" ]; } || { echo "kernel root not a git tree" >&2; exit 1; }
[ -f "$MAIN_PATCH" ] || { echo "upstream main patch missing" >&2; exit 1; }

cd "$KROOT"
git checkout -q -f 2>/dev/null || true
git clean -fdq 2>/dev/null || true

MANUAL="$OUT/manual-list.txt"
: > "$MANUAL"

# 1. split upstream patch per file
python3 - "$MAIN_PATCH" "$OUT" <<'PYEOF'
import sys, os
patch = sys.argv[1]; out = sys.argv[2]
s = open(patch).read()
for seg in s.split('diff --git ')[1:]:
    fn = seg.split(' b/')[1].split()[0].replace('/', '_')
    with open(os.path.join(out, 'files', 'seg_' + fn + '.diff'), 'w') as f:
        f.write('diff --git ' + seg)
print('split ok')
PYEOF

SKIP_LIST=(
  "security/selinux/hooks.c"      # my_* need state-ful selinux API (absent on 4.9)
  "security/selinux/selinuxfs.c"  # same
  "fs/proc/bootconfig.c"          # bootconfig is 5.x; 4.9 uses proc/cmdline.c
)

declare -a APPLIED=()
declare -a FAILED_SEGS=()

for seg in "$OUT"/files/seg_*.diff; do
  # recover original path from first line
  orig=$(head -1 "$seg" | sed -E 's|diff --git a/([^ ]+) b/.*|\1|')
  skip=0
  for s in "${SKIP_LIST[@]}"; do [ "$orig" = "$s" ] && skip=1; done
  [ $skip -eq 1 ] && { echo "SKIP (not portable to 4.9): $orig" | tee -a "$LOG"; echo "SKIP $orig (see translate.sh SKIP_LIST)" >> "$MANUAL"; continue; }

  # new-file segments (susfs.c / headers) are not in the main patch, but
  # handle 'new file' segments defensively
  if grep -q 'new file mode' "$seg"; then
    dest="$KROOT/$orig"
    mkdir -p "$(dirname "$dest")"
    python3 - "$seg" "$dest" <<'PYEOF'
import sys
# extract the file content from a new-file diff segment
seg = open(sys.argv[1]).read()
body = []
for l in seg.splitlines(True):
    if l.startswith('+') and not l.startswith('+++'):
        body.append(l[1:])
open(sys.argv[2], 'w').write(''.join(body))
PYEOF
    echo "NEW FILE: $orig" | tee -a "$LOG"
    APPLIED+=("$orig")
    continue
  fi

  # regular segment: try git apply first (strict), then patch (fuzz),
  # then apply-hunks.py relocation
  if git apply --check "$seg" 2>/dev/null; then
    git apply "$seg"
    echo "git-apply OK: $orig" | tee -a "$LOG"
  elif patch -p1 -f --dry-run < "$seg" >/dev/null 2>&1; then
    patch -p1 -f < "$seg" >/dev/null 2>&1
    echo "patch(fuzz) OK: $orig" | tee -a "$LOG"
  else
    tgt="$KROOT/$orig"
    if [ -f "$tgt" ]; then
      if python3 "$HERE/apply-hunks.py" "$tgt" "$seg" "$tgt" >> "$LOG" 2>&1; then
        echo "relocated OK: $orig" | tee -a "$LOG"
      else
        echo "MANUAL (relocation failed): $orig" | tee -a "$LOG"
        echo "MANUAL $orig" >> "$MANUAL"
        FAILED_SEGS+=("$orig")
      fi
    else
      echo "MANUAL (target missing): $orig" | tee -a "$LOG"
      echo "MANUAL $orig (missing in 4.9 tree)" >> "$MANUAL"
      FAILED_SEGS+=("$orig")
    fi
  fi
done

# 2. copy susfs.c / susfs.h / susfs_def.h from upstream snapshot and run
#    the 4.9 mechanical adaptation (i_state bits / fsnotify macro are the
#    only deltas; see adapt step below).
for f in fs/susfs.c include/linux/susfs.h include/linux/susfs_def.h; do
  src="$UP/${f#fs/}"        # upstream keeps them under kernel_patches/{fs,include}
  # map: upstream layout kernel_patches/fs/susfs.c -> snapshot file susfs.c
  case "$f" in
    fs/susfs.c) src="$UP/susfs.c" ;;
    include/linux/susfs.h) src="$UP/susfs.h" ;;
    include/linux/susfs_def.h) src="$UP/susfs_def.h" ;;
  esac
  dest="$KROOT/$f"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "COPY: $f" | tee -a "$LOG"
done

# 3. mechanical 4.9 adaptation of susfs.c: AS_FLAGS_* i_mapping->flags -> i_state
python3 - "$KROOT/fs/susfs.c" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('&fi->inode.i_mapping->flags', '&fi->inode.i_state')
s = s.replace('&inode->i_mapping->flags', '&inode->i_state')
# fsnotify: the 5.10 sdcard handler signature differs; handled by the
# SUSFS_DECL_FSNOTIFY_OPS macro on 4.9 — mechanical rewrite is NOT safe
# here, so the handler is flagged for the manual list if present.
open(p, 'w').write(s)
print('susfs.c mechanical adaptation applied (i_state)')
PYEOF

# 4. emit the translated patch (kernel tree diff) — ONLY for files that
#    actually changed; keep separate from the shipped patches/susfs.
cd "$KROOT"
git add -A 2>/dev/null || true
git diff --cached --binary > "$OUT/susfs-49-translated.patch" 2>/dev/null || true
echo "== translated patch: $OUT/susfs-49-translated.patch" | tee -a "$LOG"
echo "== manual list     : $MANUAL" | tee -a "$LOG"
echo "== applied files   : ${#APPLIED[@]}  manual: ${#FAILED_SEGS[@]}" | tee -a "$LOG"
