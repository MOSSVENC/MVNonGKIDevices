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
