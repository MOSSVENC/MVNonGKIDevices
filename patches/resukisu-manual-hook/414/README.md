# ReSukiSU manual hooks — 4.14 kernel variants

Mandatory KernelSU manual-hook source patches for 4.14 non-GKI kernels
(realme AndroidS MTK 4.14.186 tree). Shapes follow the [ReSukiSU
manual-integrate reference](https://resukisu.org/zh-Hans/guide/manual-integrate.html)
for a 4.17- kernel (pre-`__sys_*` split, 4.19- faccessat/read bodies):

- `0001-fs-stat` — include block anchored at the include/comment layout of
  the 4.14 `fs/stat.c`; call sites: newfstatat / newfstat / fstat64 /
  fstatat64.
- `0002-fs-exec` — 3.14+ shape (`ksu_handle_execveat` in
  `do_execveat_common()`); the 4.14 tree carries an extra
  `<mt-plat/mtk_pidmap.h>` include after `<trace/events/sched.h>`, so the
  include block anchors on the MTK layout.
- `0003-fs-open` — 4.19- shape: `faccessat` is the full
  `SYSCALL_DEFINE3(faccessat)` body (no `do_faccessat()` split), hook
  inside it after the local declarations, extern block after `fallocate`.
- `0004-kernel-reboot` — 3.11+ shape: `SYSCALL_DEFINE4(reboot)` in
  `kernel/reboot.c`.

Apply this whole directory instead of `common/` or `419/` on 4.14 trees:

```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu-manual-hook/414
```

Optional hooks live in `414-alt/` for `hook_extra=manual` use:
`0010-input` (input_event), `0011-setuid` (4.17- shape: hook
`SYSCALL_DEFINE3(setresuid)` body directly), `0012-sysread` (4.19- shape:
`SYSCALL_DEFINE3(read)` body, no `ksys_read`). On <6.8 kernels the LSM
AUTO machinery (`KSU_MANUAL_HOOK_AUTO_*`) covers these three without
source variants.

Landing was verified on the realme AndroidS tree snapshots with real
`git apply` (all seven patches apply cleanly; hook call sites present in
fs/stat.c, fs/exec.c, fs/open.c, kernel/reboot.c, drivers/input/input.c,
kernel/sys.c, fs/read_write.c). Compile status is tracked by the
build-RMX2117.yml CI.
