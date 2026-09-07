# patches/susfs — SuSFS for 4.9 (Non-GKI)

SuSFS upstream (susfs4ksu) has abandoned Non-GKI support; this directory
holds the porting assets used to bring SuSFS onto our 4.9 kernels, based
on JackA1ltman/NonGKI_Kernel_Build_2nd's verified work (polaris/4.9).

## Files

- `susfs_patch_to_4.9.patch` — SuSFS v2.3.0 core (fs/susfs.c, susfs.h,
  susfs_def.h + kernel hook points).
  Source: https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd
          (mainline branch, Patches/Patch/susfs_patch_to_4.9.patch)
- `susfs_inline_hook_patches-4.9.sh` — sed generator for the
  KSU-inline-hook call sites, **fixed for ReSukiSU on stock 4.9**:
  ksu_handle_sys_read is 3-arg (ReSukiSU signature) and the stat.c
  vfs_fstatat extern no longer carries the fragment bug from the
  upstream generator.
- `polaris-susfs-final.patch` — **pre-generated final snapshot** for the
  polaris LOS tree: core + stat.c/task_mmu.c 4.9 adaptation +
  hook call sites. This is what CI applies (one self-contained patch);
  the generator + adapt script below are the regeneration path for
  tracking upstream.
- `../../scripts/susfs-adapt-4.9.sh` — stock-4.9 adaptation of the two
  files the upstream patch misses (stat.c: 2-arg vfs_getattr_nosec /
  no result_mask; task_mmu.c: two-block show_map_vma).

## Regeneration path (tracking upstream gki-android12-5.10)

1. patch -p1 < susfs_patch_to_4.9.patch            (or refreshed core)
2. bash scripts/susfs-adapt-4.9.sh                 (stock-4.9 fixes)
3. create drivers/kernelsu marker (hook gen check), then
   bash susfs_inline_hook_patches-4.9.sh           (hook call sites)
4. git diff -> polaris-susfs-final.patch           (snapshot)

## CI apply

Single step: git apply polaris-susfs-final.patch, then the fragment
(CONFIG_KSU_SUSFS=y + sub-options; ReSukiSU's KSU_SUSFS choice selected
— hook mode "susfs").

## Upstream tracking

Upstream susfs4ksu (gitlab.com/simonpunk/susfs4ksu) tracks
gki-android12-5.10+ only. To refresh: re-port susfs.c/susfs.h/susfs_def.h
from the 5.10 branch and re-run the generator script against a 4.9 tree;
the sed-based generator is the main maintenance lever.

## Upstream tracking (gki-android12-5.10)

- `upstream-5.10/` mirrors the official susfs4ksu gki-android12-5.10
  kernel_patches (main patch, KernelSU 10_enable, fs/susfs.c,
  include/linux/susfs.h, susfs_def.h) — the source of truth for the
  SuSFS feature set.
- `scripts/sync-susfs-510.sh check|refresh` compares/refreshes the
  snapshot against gitlab (SUSFS_VERSION + susfs.c size signal).
- The 4.9 port (`polaris-susfs-final.patch`) is derived from this
  snapshot via the regeneration path above; when upstream bumps the
  version, refresh the snapshot and re-derive.

### Feature-set parity note (4.9 vs 5.10)

Feature surface (9 Kconfig features + susfs.c API) is kept identical
between 5.10 upstream and the 4.9 port. The selinux-hide *userspace
query faking* (setprocattr/context/access/status nodes) is provided on
4.9 by ReSukiSU's built-in fallback, which is line-equivalent to the
5.10 compile-time my_* components (same uid gate, same fake-policy
resolution, same node coverage). The 5.10 compile-time my_* themselves
depend on state-ful selinux APIs (security_context_to_sid(&state,...))
that do not exist on 4.9, so they are not portable verbatim; the 4.9
fallback resolves against its backup policydb instead — same semantics,
different plumbing. Compile-time integration of my_* into 4.9
selinuxfs.c/hooks.c would be cosmetic (no behavior change) and is not
done.

### Parity verification (run 2026-09-07, upstream 7373f8d8 / v2.3.0)

- Function inventory: all 40 upstream susfs.c functions exist in the
  4.9 port; no missing functions. Port adds only `m_free` (fsnotify
  old-API mark free callback, required on 4.9).
- Per-function body line counts are identical after normalizing the two
  known 4.9 adaptations: AS_FLAGS_* stored in `inode->i_state` high
  bits (33/34/35/36/39, free on 4.9) instead of `i_mapping->flags`;
  sdcard fsnotify handler declared via `SUSFS_DECL_FSNOTIFY_OPS`.
- 9 core feature functions verified line-equal (sus_path, sus_kstat,
  kstat_spoof_generic_fillattr, uname, open_redirect, sus_map,
  avc_log_spoofing, enabled_features, is_inode_sus_path).
- Remaining diff lines classified: only the two adaptations above +
  `#include <linux/version.h>`; no un-adapted functional difference.

### Upstream refresh checklist (5.10 -> 4.9 port)

When `scripts/sync-susfs-510.sh check` reports a newer upstream:

1. `scripts/sync-susfs-510.sh refresh`
2. `bash scripts/verify-susfs-parity.sh` — must report PARITY: OK after
   re-deriving; any MISSING_FUNCTIONS / BODY_MISMATCH / MISSING_FILE is
   drift to fix.
3. Re-derive the port: update `susfs_patch_to_4.9.patch` file-by-file
   per the translation map below, re-run `susfs-adapt-4.9.sh` and
   `susfs_inline_hook_patches-4.9.sh`, regenerate
   `polaris-susfs-final.patch`, git-apply-check on a clean tree.
4. Build via CI (hook_mode=susfs) and device-test the affected feature.

### Per-file translation map (upstream 5.10 patch -> 4.9)

| upstream file | 4.9 handling |
|---|---|
| fs/susfs.c (+h/def.h) | external files; AS_FLAGS_* stored in inode->i_state high bits (33/34/35/36/39) instead of i_mapping->flags; sdcard fsnotify handler via SUSFS_DECL_FSNOTIFY_OPS macro; extra m_free for old fsnotify API |
| fs/Makefile, fs/statfs.c, fs/proc_namespace.c, fs/notify/fdinfo.c, mm/memory.c, kernel/kallsyms.c, fs/proc/base.c, fs/proc/fd.c, fs/namespace.c | translate directly (contexts close) |
| fs/namei.c | translate; nameidata gains `state` field for sus_path |
| fs/stat.c | translate; drop statx mnt_id spoof (no statx on 4.9); keep vfs_getattr_nosec 2-arg adaptation |
| fs/readdir.c | inject into the 3 callbacks that exist on 4.9 (fillonedir/filldir/filldir64); upstream's extra 5.10 callbacks do not exist here |
| fs/readdir/stat faccessat/exec hooks | NOT in main patch — emitted by susfs_inline_hook_patches-4.9.sh (ksu_handle_* call sites), run after ReSukiSU setup |
| fs/proc/cmdline.c | 4.9 location for cmdline spoof (upstream uses proc/bootconfig.c — bootconfig absent on 4.9) |
| security/selinux/hooks.c, selinuxfs.c | NOT ported: 5.10 my_* depend on state-ful selinux APIs (security_context_to_sid(&state,..)) absent on 4.9; ReSukiSU fallback is line-equivalent (same uid gate / fake-policy resolution / node coverage) |
| fs/proc/bootconfig.c | absent on 4.9 (bootconfig is 5.x) |
