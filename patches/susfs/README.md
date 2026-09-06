# patches/susfs — SuSFS for 4.9 (Non-GKI)

SuSFS upstream (susfs4ksu) has abandoned Non-GKI support; this directory
holds the porting assets used to bring SuSFS onto our 4.9 kernels, based
on JackA1ltman/NonGKI_Kernel_Build_2nd's verified work (polaris/4.9).

## Files

- `susfs_patch_to_4.9.patch` — SuSFS v2.3.0 core (fs/susfs.c, susfs.h,
  susfs_def.h + kernel hook points), self-contained patch.
  Source: https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd
          (mainline branch, Patches/Patch/susfs_patch_to_4.9.patch)
- `susfs_inline_hook_patches.sh` — generates the KSU-inline-hook call
  sites (fs/exec.c, open.c, read_write.c, stat.c, namei.c, input.c,
  security.c, selinux hooks/services, reboot.c, sys.c) with sed,
  adapting to 4.4/4.9/4.14/4.19/5.4 feature differences.
  Source: same repo (Patches/susfs_inline_hook_patches.sh)

## Apply order (in CI, inside kernel tree)

1. patch -p1 < patches/susfs/susfs_patch_to_4.9.patch   (core)
2. bash patches/susfs/susfs_inline_hook_patches.sh      (hook call sites)
3. defconfig fragment: CONFIG_KSU_SUSFS=y + sub-options
   (KernelSU-side Kconfig provides the symbols; ReSukiSU's KSU_SUSFS
   choice must be selected — hook mode "susfs")

Rejected hunks (.rej) must be reviewed manually per kernel tree; the
polaris LOS tree currently applies cleanly except fs/stat.c and
fs/proc/task_mmu.c (minor context drift).

## Upstream tracking

Upstream susfs4ksu (gitlab.com/simonpunk/susfs4ksu) tracks
gki-android12-5.10+ only. To refresh: re-port susfs.c/susfs.h/susfs_def.h
from the 5.10 branch and re-run the generator script against a 4.9 tree;
the sed-based generator is the main maintenance lever.
