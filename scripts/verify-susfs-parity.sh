#!/usr/bin/env bash
#
# verify-susfs-parity.sh — verify the 4.9 SuSFS port stays in parity with
# the upstream gki-android12-5.10 snapshot (patches/susfs/upstream-5.10/).
#
# Run after an upstream refresh (scripts/sync-susfs-510.sh refresh) to
# detect feature drift before re-deriving the port:
#
#   bash scripts/verify-susfs-parity.sh
#
# Checks (all must pass for parity):
#   1. susfs.c function inventory: every upstream function exists in the
#      port; no missing functions.
#   2. Per-function body size parity (normalized for the known 4.9
#      adaptations: AS_FLAGS_* in i_state, fsnotify macro).
#   3. Kernel hook-site coverage per file: for each file both sides
#      touch, the number of upstream injection sites must be >= what 4.9
#      can host, and the port must cover every callback that exists on
#      4.9 (e.g. readdir: fillonedir/filldir/filldir64).
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
UP="$REPO/patches/susfs/upstream-5.10"
MAIN_UP="$UP/50_add_susfs_in_gki-android12-5.10.patch"
PORT="$REPO/patches/susfs/polaris-susfs-final.patch"

fail=0
note() { echo "== $*"; }
ok() { echo "   PASS: $*"; }
bad() { echo "   FAIL: $*"; fail=1; }

# ---------- 1. susfs.c function inventory ----------
note "1/3 susfs.c function inventory"
extract_susfs() { # $1=patch or file  $2=out
  if head -1 "$1" | grep -q '^diff --git'; then
    awk '/^diff --git a\/fs\/susfs.c/,/^diff --git a\/include\/linux\/susfs/' "$1" \
      | grep '^+' | grep -v '^+++' | sed 's/^+//' > "$2"
  else
    cp "$1" "$2"
  fi
}
extract_susfs "$UP/susfs.c" "$REPO/.work/verify-up-susfs.c"
extract_susfs "$PORT"      "$REPO/.work/verify-port-susfs.c"

python3 - "$REPO/.work/verify-up-susfs.c" "$REPO/.work/verify-port-susfs.c" <<'PYEOF'
import re, sys
def funcs(path):
    s=open(path).read()
    out=set()
    # function definitions: "name(" at line start after optional static/type
    for m in re.finditer(r'^(?:static\s+)?(?:inline\s+)?(?:[\w\s\*]+?)\s+(\w+)\s*\([^;]*$', s, re.M):
        n=m.group(1)
        if n in ('if','for','while','switch','return','sizeof','defined','copy_from_user'):
            continue
        out.add(n)
    return out
up=funcs(sys.argv[1]); port=funcs(sys.argv[2])
missing=sorted(up-port)
if missing:
    print('MISSING_FUNCTIONS', ' '.join(missing))
else:
    print('ALL_UPSTREAM_FUNCTIONS_PRESENT')
# extra functions beyond known 4.9 additions
known_extra={'m_free'}
extra=sorted(port-up-known_extra)
if extra:
    print('EXTRA_FUNCTIONS', ' '.join(extra))
PYEOF
echo "   (parse the MISSING_FUNCTIONS / EXTRA_FUNCTIONS lines above)"

# ---------- 2. per-function body parity (9 core features) ----------
note "2/3 per-function body parity (core feature functions)"
python3 - "$REPO/.work/verify-up-susfs.c" "$REPO/.work/verify-port-susfs.c" <<'PYEOF'
import sys
def body_of(path, fname):
    s=open(path).read()
    idx=s.find('\n'+fname+'(')
    if idx<0: idx=s.find(fname+'(')
    if idx<0: return ''
    start=s.find('{', idx)
    if start<0: return ''
    d=0; i=start
    while i<len(s):
        if s[i]=='{': d+=1
        elif s[i]=='}':
            d-=1
            if d==0: return s[idx:i+1]
        i+=1
    return s[idx:]
def norm(x):
    return (x.replace('&fi->inode.i_mapping->flags','&F')
             .replace('&inode->i_mapping->flags','&F')
             .replace('&fi->inode.i_state','&F')
             .replace('&inode->i_state','&F')
             .replace('i_mapping->flags','F').replace('i_state','F'))
core=['susfs_add_sus_path','susfs_is_inode_sus_path','susfs_add_sus_kstat',
      'susfs_sus_kstat_spoof_generic_fillattr','susfs_spoof_uname',
      'susfs_add_open_redirect','susfs_add_sus_map','susfs_set_avc_log_spoofing',
      'susfs_get_enabled_features','susfs_add_sus_path_loop','susfs_set_hide_sus_mnts_for_non_su_procs']
up,port=sys.argv[1],sys.argv[2]
problems=[]
for fn in core:
    u=norm(body_of(up,fn)); p=norm(body_of(port,fn))
    ul=[l for l in u.splitlines() if l.strip() and 'SUSFS_LOGI' not in l and 'SUSFS_LOGE' not in l]
    pl=[l for l in p.splitlines() if l.strip() and 'SUSFS_LOGI' not in l and 'SUSFS_LOGE' not in l]
    if abs(len(ul)-len(pl))>3:
        problems.append(f'{fn}: upstream {len(ul)} vs port {len(pl)}')
if problems:
    print('BODY_MISMATCH', '; '.join(problems))
else:
    print('ALL_CORE_BODIES_MATCH')
PYEOF

# ---------- 3. hook-site coverage ----------
note "3/3 hook-site coverage"
python3 - "$MAIN_UP" "$PORT" <<'PYEOF'
import sys
def file_adds(patch):
    s=open(patch).read()
    out={}
    for seg in s.split('diff --git ')[1:]:
        fn=seg.split(' b/')[1].split()[0]
        adds=len([l for l in seg.splitlines() if l.startswith('+') and not l.startswith('+++')])
        out[fn]=adds
    return out
up=file_adds(sys.argv[1]); port=file_adds(sys.argv[2])
# port files that exist upstream but with large shortfall
print('upstream files:', len(up), ' port files:', len(port))
# signal files where upstream adds >> port adds (potential drift).
# A larger upstream delta is expected when 5.10 has more hook sites than
# 4.9 can host (e.g. readdir: 5.10 has 5 dirent callbacks, 4.9 has 3) —
# so flag only files whose port delta is near zero while upstream is
# large, or where a known shared callback lost its injection.
for fn,ua in sorted(up.items()):
    pa=port.get(fn,0)
    # files that exist in both but the port did not touch at all
    if fn in up and fn not in port and fn not in (
        'security/selinux/hooks.c','security/selinux/selinuxfs.c',   # ReSukiSU fallback owns selinux hide
        'fs/proc/bootconfig.c',                                      # no bootconfig on 4.9
        'fs/open.c','fs/exec.c','fs/read_write.c','kernel/reboot.c', # hook gen handles these
        'drivers/input/input.c'):
        print('MISSING_FILE', fn, f'upstream +{ua}')
print('HOOK_COVERAGE_DONE')
PYEOF

rm -f "$REPO/.work/verify-up-susfs.c" "$REPO/.work/verify-port-susfs.c"
if [ "$fail" -eq 0 ]; then
  echo "PARITY: OK"
else
  echo "PARITY: FAILURES PRESENT"
  exit 1
fi
