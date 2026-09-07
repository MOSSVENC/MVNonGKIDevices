# Droidspace — kernel support for containers on 4.9 (non-GKI)

Droidspaces (https://github.com/ravindu644/Droidspaces-OSS) is a
lightweight Linux container tool. Support on this 4.9 non-GKI kernel is
a kernel config fragment plus one cgroup source fix.

## Contents

- `droidspace.config` — kernel config merged into the final `.config`
  (see `scripts/merge-defconfig.sh`), following the official non-GKI
  section of `Kernel-Configuration.md` with 4.9 symbol names:
  - `CONFIG_NF_CT_NETLINK` (4.9 name)
  - masquerade: `CONFIG_IP_NF_TARGET_MASQUERADE` (4.9 name)
  - `CONFIG_SECCOMP_FILTER` is a 5.x symbol; on 4.9 arm64,
    `CONFIG_SECCOMP=y` already provides filters
  - `CONFIG_ANDROID_PARANOID_NETWORK` turned off so container
    networking works
- `0001-cgroup-noprefix-4.9-port.patch` — cgroup `subsys.file`
  kernfs symlink restore for `noprefix` mounts (systemd/runc style),
  ported to the 4.9 layout (`kernel/cgroup.c`).

This tree carries the cgroup patch from the official non-GKI patch set;
the other patch of that set targets `net/netfilter/xt_qtaguid.c`, which
this sdm845 4.9 tree does not contain.

## Integration

```bash
bash scripts/integrate-droidspace.sh <kernel-root> \
  patches/droidspace/common/0001-cgroup-noprefix-4.9-port.patch
```
