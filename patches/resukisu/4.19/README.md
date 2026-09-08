# ReSukiSU manual hooks — 4.19 trees

Tree-adapted mandatory hook patches for 4.19 non-GKI kernels (alioth /
kona LOS tree). Symlinks point to the shared 4.9 files where both kernel
families share a shape; local files cover the 4.19-specific parts.

- `0001-fs-stat` → shared (4.9).
- `0002-fs-exec` → shared (4.9): 4.19 keeps the 3.14+ shape,
  `ksu_handle_execveat` inside `do_execveat_common()`.
- `0003-fs-open` — local: 4.19 moved the faccessat body into
  `do_faccessat(dfd, filename, mode)` and the syscall wrapper is a thin
  `SYSCALL_DEFINE3(faccessat)`; the hook sits in the wrapper (4.19+
  shape).
- `0004-kernel-reboot` → shared (4.9).
- `0010-input` → shared (4.9); `0011-setuid` / `0012-sysread` — local
  (4.17+ `__sys_setresuid` shape / 4.19+ ksys_read wrapper shape),
  used in `hook_extra=manual` mode.

Doc-shape reference lives in `../upstream/manualhook/`.

Apply:
```bash
bash scripts/apply-patches.sh <kernel-root> patches/resukisu/4.19
```
