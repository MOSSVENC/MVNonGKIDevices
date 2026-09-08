# ReSukiSU manual hooks — 4.14 trees

Tree-adapted mandatory hook patches for 4.14 non-GKI kernels (realme
AndroidS MTK tree). Symlinks point to the shared 4.9 files where the two
kernel families share a shape; local files cover the MTK-specific parts.

- `0001-fs-stat` → shared (4.9); the MTK stat.c region matches.
- `0002-fs-exec` — local: include block anchors the MTK
  `<mt-plat/mtk_pidmap.h>` layout after `<trace/events/sched.h>`.
- `0003-fs-open` — local: inline `SYSCALL_DEFINE3(faccessat)` body with
  the MTK tree's fallocate/comment context.
- `0004-kernel-reboot` → shared (4.9).
- `0010-input` / `0011-setuid` / `0012-sysread` — local optional hooks
  (MTK input_event / 4.17- setresuid body / inline read body with the
  OPLUS_IOMONITOR region), used in `hook_extra=manual` mode.

Doc-shape reference lives in `../upstream/manualhook/`.

Apply:
```bash
bash scripts/apply-patches.sh <kernel-root> patches/resukisu/4.14
```
