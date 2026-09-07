# ReSukiSU optional hooks — 4.19 kernel variants

Optional (alt) manual-hook source patches for 4.19 non-GKI kernels,
used only with `hook_extra=manual` (hook_mode=manual-source). On <6.8
kernels these three hooks are normally covered by ReSukiSU's AUTO
machinery (`hook_extra=lsm`), so these source variants exist for builds
that turn the AUTO options off.

Per the [ReSukiSU manual-integrate reference](https://resukisu.org/zh-Hans/guide/manual-integrate.html):

- `0010-input` — 沿用 `alt-hooks/0010` 的补丁文件（4.19
  `drivers/input/input.c` 保持文档 input hook 指向的 `input_event()`
  形态）。
- `0011-setuid` — 4.19 has the setresuid logic in
  `__sys_setresuid()` with a thin `SYSCALL_DEFINE3(setresuid)` wrapper
  (the 4.17+ shape). The 4.9 `alt-hooks/0011` hooks the inline syscall
  body, so this variant places `ksu_handle_setresuid` inside
  `__sys_setresuid()` instead.
- `0012-sysread` — 4.19 has `ksys_read()` with a thin
  `SYSCALL_DEFINE3(read)` wrapper (the 4.19+ shape). The 4.9
  `alt-hooks/0012` hooks the inline syscall body, so this variant places
  the `ksu_init_rc_hook` guard + `ksu_handle_sys_read` call inside the
  wrapper before `return ksys_read(...)`.

Apply together with the mandatory 4.19 hooks when using
`hook_extra=manual` on a 4.19 tree:

```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu-manual-hook/419 \
  patches/resukisu-manual-hook/419-alt
```
