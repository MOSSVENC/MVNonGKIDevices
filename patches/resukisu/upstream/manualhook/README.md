# ReSukiSU manual hooks — upstream doc reference

Excerpts of the [ReSukiSU manual-integrate guide](https://resukisu.org/zh-Hans/guide/manual-integrate.html)
(live snapshot Sep 2026), one markdown file per hook and per kernel-
version shape the guide distinguishes:

- `stat-hook/` — no version split in the guide; includes the optional
  newfstat/fstat64 ret-hook hunk whose lines are `X` placeholders in the
  guide (locate by pattern).
- `execve-hook/3.14-/` — `ksu_handle_execve` on `do_execve` /
  `compat_do_execve`. `execve-hook/3.14+/` holds the recommended shape
  (hook inside `do_execveat_common`) and the doc-marked deprecated
  variant (hook `do_execve` / `compat_do_execve` with an `AT_FDCWD`
  pseudo fd), which the guide warns cannot acquire root on Android 17
  QPR2 and newer.
- `faccessat-hook/4.19+/` (thin wrapper over `do_faccessat`) and
  `4.19-/` (inline `SYSCALL_DEFINE3` body).
- `sys_reboot-hook/3.11+/` (`kernel/reboot.c`) and `3.11-/`
  (`kernel/sys.c`).
- `setuid-hook/4.17+/` (`__sys_setresuid`) and `4.17-/`
  (`SYSCALL_DEFINE3(setresuid)` body).
- `sys_read-hook/4.19+/` (wrapper over `ksys_read`) and `4.19-/`
  (inline `SYSCALL_DEFINE3(read)`).
- `input-hook/` — no version split in the guide.

These files reproduce the guide's code blocks verbatim (including
placeholder hunk numbers and whitespace as rendered on the web page);
they are reference material for understanding each shape. The
tree-adapted patches that CI actually applies live in the sibling
version directories (`patches/resukisu/4.9/`, `4.14/`, `4.19/`), where
each file was generated from the real target tree.
