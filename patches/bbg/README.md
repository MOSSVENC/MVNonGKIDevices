# BBG (Baseband-guard) — integration notes

BBG ("Baseband-guard") is an anti-format / anti-brick Linux Security Module
that blocks malicious userspace writes to critical partitions
(boot / recovery / modem etc.). Upstream: https://github.com/vc-teahouse/Baseband-guard

There is **no local source patch** required on 4.9. The upstream `setup.sh`
performs the whole integration when run from the kernel root:

1. clones the repo into `Baseband-guard/`
2. symlinks `security/baseband-guard`
3. wires `security/Makefile` (`obj-$(CONFIG_BBG) += baseband-guard/`) and
   `security/Kconfig` (`source "security/baseband-guard/Kconfig"`)
4. **4.9 path (pre-5.1, no `DEFINE_LSM`)**: automatically appends
   `sepatch.txt` to `security/selinux/Makefile` and injects `bbg_cred`
   into `security/selinux/include/objsec.h` (backups are created as `.bak`;
   `setup.sh --cleanup` reverts everything).

After the script, only `CONFIG_BBG=y` must reach the final `.config`
(handled by `scripts/integrate-bbg.sh` / `merge-defconfig.sh`).

Why no `CONFIG_LSM` change? On pre-5.1 kernels BBG registers through the
legacy `security_add_hooks(hooks, count, "baseband_guard")` API; the
`CONFIG_LSM=` ordering requirement only exists on modern (DEFINE_LSM)
kernels. The upstream Makefile aborts only when `DEFINE_LSM` exists but
`baseband_guard` is missing from `CONFIG_LSM` — not our case.

Optional hardening (leave at `n` unless intended): `CONFIG_BBG_BLOCK_BOOT`,
`CONFIG_BBG_BLOCK_RECOVERY` in the BBG Kconfig can additionally block writes
to boot/recovery from Android userspace (can interfere with in-ROM flashing).

Run integration with:
```bash
bash scripts/integrate-bbg.sh <kernel-root>
```
