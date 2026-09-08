# ReSukiSU manual hooks — 4.14 trees

Tree-adapted mandatory hook patches for 4.14 non-GKI kernels (realme
AndroidS MTK tree). Single copies live where noted; workflows reference
files across version dirs (file-level lists, no copies).

- `0001-fs-stat` / `0004-kernel-reboot` — shared with 4.9 (single copy
  in `../4.9/`; the MTK stat.c/reboot.c regions match).
- `0002-fs-exec` — MTK-local: include block anchors the
  `<mt-plat/mtk_pidmap.h>` layout after `<trace/events/sched.h>`.
- `0003-fs-open` — MTK-local: inline `SYSCALL_DEFINE3(faccessat)` body
  with the MTK tree's fallocate/comment context.
- `0010-input` / `0011-setuid` / `0012-sysread` — MTK-local optional
  hooks (MTK input_event / 4.17- setresuid body / inline read body with
  the OPLUS_IOMONITOR region), used in `hook_extra=manual` mode.

Doc-shape reference (web excerpts) lives in `../upstream/manualhook/`.

Apply:
```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu/4.9/0001-fs-stat-ksu-manual-hook.patch \
  patches/resukisu/4.14/0002-fs-exec-ksu-manual-hook.patch \
  patches/resukisu/4.14/0003-fs-open-ksu-manual-hook.patch \
  patches/resukisu/4.9/0004-kernel-reboot-ksu-manual-hook.patch
```
