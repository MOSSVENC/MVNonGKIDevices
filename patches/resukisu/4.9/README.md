# ReSukiSU manual hooks — 4.9 trees

Tree-adapted mandatory hook patches for 4.9 non-GKI kernels
(polaris / beryllium / daisy / vince, LOS/CAF trees).

- `0001-fs-stat` / `0002-fs-exec` / `0003-fs-open` / `0004-kernel-reboot`
  — mandatory hook set in the shapes this kernel family needs (open uses
  the inline `SYSCALL_DEFINE3(faccessat)` body).
- `0010-input` / `0011-setuid` / `0012-sysread` — optional hooks, applied
  in `hook_extra=manual` mode only; `hook_extra=lsm` (default) covers them
  via ReSukiSU's LSM/input_handler AUTO machinery.
- `daisy/0004` / `vince/0004` — device-tree variants of the reboot hook
  (their reboot.c contexts differ); use them instead of `0004` for those
  two trees. `vince/0000-remove-legacy-ksu-hooks.patch` strips the
  tree's bundled legacy KernelSU hooks before integration.

Doc-shape reference for the whole family lives in
`../upstream/manualhook/`; the doc's version tabs map onto these
files as follows: stat/exec/reboot are the 3.14+ shapes, open is the
4.19- shape, setuid the 4.17- shape, sys_read the 4.19- shape.

Apply:
```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu/4.9 [patches/resukisu/4.9/<device>]
```
