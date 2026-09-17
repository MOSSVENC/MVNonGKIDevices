#!/usr/bin/env bash
#
# apply-susfs-port.sh — apply a SuSFS port and assert the KSU interaction faces.
#
# usage: apply-susfs-port.sh <kernel-root> <port-patch>
#
# The port carries both the susfs core and the ksu_handle_* call sites that
# ReSukiSU's inline_hook_check.mk demands, so one face set is asserted for every
# device and kernel version. The step fails on: a port that does not apply, a
# missing face, a post-execve call placed before the exec attempt, or a
# filename_lookup that is still static (fs/open.c and fs/stat.c call it).
#
set -euo pipefail

KROOT="${1:?usage: apply-susfs-port.sh <kernel-root> <port-patch>}"
P="${2:?usage: apply-susfs-port.sh <kernel-root> <port-patch>}"
[ -f "$P" ] || { echo "no such port patch: $P" >&2; exit 1; }

cd "$KROOT"
git apply --check "$P" || { echo "port does not apply cleanly" >&2; exit 1; }
git apply "$P"
echo "SuSFS port applied:"
grep -c 'CONFIG_KSU_SUSFS' fs/susfs.c include/linux/susfs.h

MISSING=""
for spec in "ksu_handle_setresuid:kernel/sys.c" "ksu_handle_execveat:fs/exec.c" \
            "ksu_handle_post_execveat_sucompat:fs/exec.c" \
            "ksu_handle_faccessat:fs/open.c" "ksu_handle_sys_read:fs/read_write.c" \
            "ksu_handle_stat:fs/stat.c" "ksu_handle_vfs_fstat:fs/stat.c" \
            "ksu_handle_sys_reboot:kernel/reboot.c" \
            "ksu_handle_input_handle_event:drivers/input/input.c"; do
  sym="${spec%%:*}"; file="${spec##*:}"
  grep -q "$sym" "$file" || MISSING="$MISSING $sym($file)"
done

# the post-execve call must sit after the exec attempt
post=$(grep -n '(void)ksu_handle_post_execveat_sucompat(' fs/exec.c | head -1 | cut -d: -f1)
done_line=$(grep -n 'exec_binprm(bprm)' fs/exec.c | head -1 | cut -d: -f1)
[ -n "$post" ] && [ -n "$done_line" ] && [ "$post" -gt "$done_line" ] || {
  echo "post-execve call not after the exec attempt (post=$post exec=$done_line)" >&2
  exit 1; }

grep -q '^int filename_lookup' fs/namei.c || MISSING="$MISSING filename_lookup(fs/namei.c)"

if [ -n "$MISSING" ]; then
  echo "port left missing:$MISSING" >&2
  exit 1
fi
echo "SuSFS KSU-interaction hooks present"
