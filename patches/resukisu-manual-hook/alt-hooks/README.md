# ReSukiSU optional hooks — manual (source-patch) variants

ReSukiSU's manual-integration reference lists 7 hook categories. 4 of them
**must** be added as kernel source patches and live in
`../common/` (stat / execve / faccessat / sys_reboot).

The remaining 3 are **optional**:

| hook | kernel side | default mechanism |
|---|---|---|
| input | `ksu_handle_input_handle_event` (drivers/input/input.c) | `CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y` → input_handler |
| setuid | `ksu_handle_setresuid` (kernel/sys.c) | `CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK=y` → LSM |
| sys_read (initrc) | `ksu_handle_sys_read` (fs/read_write.c) | `CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK=y` → LSM |

On kernels < 6.8 (this is 4.9) the AUTO/LSM machinery is the recommended,
documented default — **no source patch needed**.

These three patches are the **alternative**: apply the hook as a real inline
source call (matching resukisu.org/guide/manual-integrate.html) instead of
relying on LSM/AUTO. They are mutually exclusive with the AUTO options:

- `hook_extra: lsm`    → do NOT apply these; fragment sets the three `AUTO_*=y`
- `hook_extra: manual` → apply 0010–0012; fragment sets the three
  `# CONFIG_KSU_MANUAL_HOOK_AUTO_* is not set`, and ReSukiSU's compile-time
  check (`kernel/tools/manual_hook_check.mk`) verifies the manually added
  symbols instead.

## Files

- `0010-input-manual-hook.patch`  — `input_event()`: `if (unlikely(ksu_input_hook)) ksu_handle_input_handle_event(&type,&code,&value);`
- `0011-setuid-manual-hook.patch` — `SYSCALL_DEFINE3(setresuid)`: `ksu_handle_setresuid(ruid, euid, suid)` (4.17- uses setresuid, not `__sys_setresuid`)
- `0012-sysread-manual-hook.patch` — `SYSCALL_DEFINE3(read)`: `if (unlikely(ksu_init_rc_hook)) ksu_handle_sys_read(fd, &buf, &count);`

All three are written against the 4.9.337 (`lineage-22.2`) layout and verified
to `git apply --check` cleanly on pristine files.

## Wiring

- workflow_dispatch input `hook_extra` (choice lsm/manual, default lsm)
- configs/mix2s.yaml → `features.resukisu.hook_extra`
- scripts/integrate-resukisu.sh `[hook_extra_mode]` argument picks the fragment
- merge-defconfig.sh asserts the three AUTO symbols only in `lsm` mode (see
  its resukisu assertion block); in `manual` mode it asserts the AUTO options
  are NOT set.
