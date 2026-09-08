# ReSukiSU manual hook reference — upstream doc shapes

KernelSU/ReSukiSU manual-hook forms extracted from the ReSukiSU
manual-integrate reference (resukisu.org/zh-Hans/guide/manual-integrate.html,
live snapshot Sep 2026). Layout follows the upstream document's own
version tabs:

- `execve-hook/3.14+/` — hook `do_execveat_common` body (covers execve /
  execveat / compat paths) plus `...-deprecated` variant hooking the
  `do_execve` / `compat_do_execve` entries with an `AT_FDCWD` pseudo fd.
  The upstream doc marks the deprecated variant as unusable on Android 17
  QPR2 and newer (root acquisition fails there); the two variants are
  alternatives — wire one call site per tree.
- `execve-hook/3.14-/` — pre-3.14 shape using `ksu_handle_execve` on
  `do_execve` / `compat_do_execve`.
- `faccessat-hook/4.19+/` — syscall wrapper over `do_faccessat`;
  `faccessat-hook/4.19-/` — inline `SYSCALL_DEFINE3(faccessat)` body.
- `sys_reboot-hook/3.11+/` — `kernel/reboot.c`; `3.11-/` — `kernel/sys.c`.
- `setuid-hook/4.17+/` — `__sys_setresuid`; `4.17-/` — the
  `SYSCALL_DEFINE3(setresuid)` body.
- `sys_read-hook/4.19+/` — wrapper over `ksys_read`; `4.19-/` — inline
  `SYSCALL_DEFINE3(read)` body.
- `input-hook/`, `stat-hook/` — no version split in the upstream doc.

These files reproduce the document code blocks (including its sample
hunk line numbers). They are the reference/audit face: tree-adapted
patches that CI actually applies live in the sibling version
directories (`resukisu/4.9/`, `resukisu/4.14/`, `resukisu/4.19/`).
Hooks handled by the LSM/input_handler AUTO machinery on <6.8 kernels
(setuid / sys_read / input) have no source-patch requirement in
`hook_extra=lsm` mode.
