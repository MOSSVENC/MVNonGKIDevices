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
