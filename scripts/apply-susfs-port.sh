#!/usr/bin/env bash
#
# apply-susfs-port.sh — apply a SuSFS port and assert the KSU interaction faces.
#
# usage: apply-susfs-port.sh <kernel-root> <port-patch>
#
# The port carries both the susfs core and the ksu_handle_* call sites that
# BakaSU's inline_hook_check.mk demands, so one face set is asserted for every
# device and kernel version. The step fails on: a port that does not apply, a
# missing face, a post-execve call placed before the exec attempt, or a
# filename_lookup that is still static (fs/open.c and fs/stat.c call it).
#
set -euo pipefail

KROOT="${1:?usage: apply-susfs-port.sh <kernel-root> <port-patch>}"
P="${2:?usage: apply-susfs-port.sh <kernel-root> <port-patch>}"
[ -f "$P" ] || { echo "no such port patch: $P" >&2; exit 1; }

cd "$KROOT" || exit 1
if git apply --check -R "$P" >/dev/null 2>&1; then
  echo "SuSFS port already applied: $P"
elif git apply --check "$P" >/dev/null 2>&1; then
  git apply "$P"
  echo "SuSFS port applied:"
else
  echo "port does not apply cleanly" >&2
  exit 1
fi
grep -c 'CONFIG_KSU_SUSFS' fs/susfs.c include/linux/susfs.h

MISSING=""
for spec in "ksu_selinux_hide_running:security/selinux/hooks.c" \
            "handle_selinux_setprocattr:security/selinux/hooks.c" \
            "ksu_handle_setresuid:kernel/sys.c" "ksu_handle_execveat:fs/exec.c" \
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

# The 4.9/4.14/4.19 exec paths perform their own success cleanup. The preinit
# post-exec handler therefore runs before the failure branch and retries the
# real init after ENOEXEC, while clearing the failed exec state first.
grep -q 'The runner did not execute' fs/exec.c || \
    MISSING="$MISSING preinit ENOEXEC retry(fs/exec.c)"
awk '
  /if \(ksu_preinit_handle_post_execveat\(/ { pre = NR }
  /if \(retval < 0\)/ && pre && !seen { post = NR; seen = 1 }
  END { exit !(seen && pre < post) }
' fs/exec.c || \
    MISSING="$MISSING preinit handler before exec failure branch(fs/exec.c)"

grep -q '^int filename_lookup' fs/namei.c || MISSING="$MISSING filename_lookup(fs/namei.c)"

grep -q 'return selinux_setprocattr' security/selinux/hooks.c || \
    MISSING="$MISSING selinux_setprocattr fallback(security/selinux/hooks.c)"

awk '
  /^#ifdef CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER$/ { guarded = 1; next }
  /^#endif.*CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER/ { guarded = 0 }
  /static struct cred \*susfs_switch_to_ksu_domain\(/ { if (!guarded) bad = 1; saw = 1 }
  /static void susfs_restore_creds\(/ { if (!guarded) bad = 1; saw = 1 }
  END { exit !(saw && !bad) }
' fs/susfs.c || \
    MISSING="$MISSING priority-cred helpers not config-guarded(fs/susfs.c)"

awk '
  /tcontext=%s", "u:r:priv_app/ { line = NR; next }
  line && NR == line + 1 && /if \(!rc\)/ { guard = NR }
  guard && NR == guard + 1 && /kfree\(scontext\)/ { freed = 1 }
  END { exit !(freed) }
' security/selinux/avc.c || \
    MISSING="$MISSING AVC spoof context not freed(security/selinux/avc.c)"

if [ -n "$MISSING" ]; then
  echo "port left missing:$MISSING" >&2
  exit 1
fi
echo "SuSFS KSU-interaction hooks present"
