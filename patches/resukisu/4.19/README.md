# ReSukiSU manual hooks — 4.19 trees

Tree-adapted mandatory hook patches for 4.19 non-GKI kernels (alioth /
kona LOS tree). Single copies live where noted; workflows reference
files across version dirs (file-level lists, no copies).

- `0001-fs-stat` / `0002-fs-exec` / `0004-kernel-reboot` /
  `0010-input` — shared with 4.9 (single copy in `../4.9/`): 4.19 keeps
  the 3.14+ `do_execveat_common` shape and matches stat/reboot/input
  regions.
- `0003-fs-open` — 4.19-local: faccessat body moved into
  `do_faccessat(dfd, filename, mode)`, hook sits in the thin
  `SYSCALL_DEFINE3(faccessat)` wrapper (4.19+ shape).
- `0011-setuid` — 4.19-local: 4.17+ shape hooking `__sys_setresuid`.
- `0012-sysread` — 4.19-local: 4.19+ shape hooking the `ksys_read`
  wrapper.

Doc-shape reference (web excerpts) lives in `../upstream/manualhook/`.

Apply:
```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu/4.9/0001-fs-stat-ksu-manual-hook.patch \
  patches/resukisu/4.9/0002-fs-exec-ksu-manual-hook.patch \
  patches/resukisu/4.19/0003-fs-open-ksu-manual-hook.patch \
  patches/resukisu/4.9/0004-kernel-reboot-ksu-manual-hook.patch
```
