# ReSukiSU manual hooks — 4.19 kernel variants

Mandatory KernelSU manual-hook source patches for 4.19 non-GKI kernels
(kona/sm8250 LineageOS tree). Same hook set as `common/` (4.9), with the
host-context and call-shape differences required by the 4.19 kernel and
the [ReSukiSU manual-integrate reference](https://resukisu.org/zh-Hans/guide/manual-integrate.html):

- `0001-fs-stat` — include block anchored at the 4.19 `fs/stat.c`
  (`<asm/unistd.h>` + doc-comment layout; 4.9 anchored at
  `<asm/uaccess.h>` + `generic_fillattr`); the four call sites
  (newfstatat / newfstat / fstat64 / fstatat64) are unchanged.
- `0002-fs-exec` — 沿用 `common/0002` 的补丁文件（4.19 仍是
  `do_execveat_common()` 位于 `__do_execve_file()` 之后的 3.14+ 形态，
  即 manual-integrate 文档为 `ksu_handle_execveat` 指定的落点）。
- `0003-fs-open` — 4.19 moved the faccessat body into
  `do_faccessat(dfd, filename, mode)` and the syscall wrapper is a thin
  `SYSCALL_DEFINE3(faccessat)` that just calls it. Per the doc's 4.19+
  shape, `ksu_handle_faccessat` is placed inside that wrapper (before
  `return do_faccessat(...)`), not in the 4.9 inline body.
- `0004-kernel-reboot` — 沿用 `common/0004` 的补丁文件（3.11+ 形态：
  hook `SYSCALL_DEFINE4(reboot)` 于 `kernel/reboot.c`）。

Apply this whole directory instead of `common/` on 4.19 trees:

```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu-manual-hook/419
```

The optional hooks (input / setuid / initrc sys_read) are handled by the
AUTO machinery on <6.8 kernels (`hook_extra=lsm`), so no 4.19 source
variants are needed for them.
