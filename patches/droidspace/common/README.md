# Droidspace — kernel support for containers on 4.9 (non-GKI)

Droidspaces (https://github.com/ravindu644/Droidspaces-OSS) is a
lightweight Linux container tool. On a 4.9 non-GKI kernel, "support"
mostly means **kernel config** plus one small cgroup source fix.

## What is NOT applied and why

Official `Documentation/resources/kernel-patches/non-GKI/` ships two patches:

| patch | target | status here |
|---|---|---|
| `01.fix_kernel_panic_in_xt_qtaguid.patch` | `net/netfilter/xt_qtaguid.c` | **skipped** — this sdm845 4.9 tree has no `xt_qtaguid.c` in any branch (verified), the file simply does not exist. |
| `02.fix_restore cgroup file prefix handling .patch` | `kernel/cgroup/cgroup.c` (4.14+ layout) | **ported to 4.9** → `../polaris/0001-cgroup-noprefix-4.9-port.patch` (4.9 keeps this code in `kernel/cgroup.c`). Non-fatal if it fails to apply. |

The cgroup port recreates `subsys.file` kernfs symlinks when a cgroup root is
mounted `noprefix` (systemd/runc style), which is what runc/crun expect.
This matches the reference implementation used in the beryllium build
(`Flyme66/kernel_xiaomi_sdm845_tejas101k_beryllium`, commit `b2d517b90def`).

## Kernel config

`droidspace.config` in this directory is merged into the final `.config`
(see `scripts/merge-defconfig.sh`). It follows the official non-GKI section
of `Kernel-Configuration.md` with 4.9 corrections:

- `CONFIG_NF_CT_NETLINK` (4.9 name) instead of `CONFIG_NF_CONNTRACK_NETLINK`
- masquerade on 4.9 is `CONFIG_IP_NF_TARGET_MASQUERADE` (already =y in the
  mi845 baseline; the upstream `NETFILTER_XT_TARGET_MASQUERADE` does not exist)
- `CONFIG_SECCOMP_FILTER` is not a 4.9 symbol (arm64 selects
  `HAVE_ARCH_SECCOMP_FILTER`; `CONFIG_SECCOMP=y` already carries filters)
- `CONFIG_ANDROID_PARANOID_NETWORK` (defaults to y here) is explicitly turned
  off so container networking works

Enable via `configs/polaris.yaml` → `features.droidspace.enabled`.
