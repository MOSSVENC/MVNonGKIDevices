# Droidspace on 4.19 (non-GKI, kona/sm8250)

Droidspaces (https://github.com/ravindu644/Droidspaces-OSS) container
support for the 4.19 non-GKI kernel family (kona/sm8250 and other
4.19 CAF trees). The official Droidspaces "Non-GKI" instructions cover
4.19 directly (Kernel-Configuration.md: "Applies to: Kernel 3.18, 4.4,
4.9, 4.14, 4.19"), so this directory mirrors the official patch set and
config fragment instead of carrying a local port.

## Contents

- `droidspace.config` — official non-GKI mandatory configuration block
  (Step 1), verbatim. 4.19 has every symbol in the official block,
  including the 5.x-era names that 4.9 lacked (`CONFIG_SECCOMP_FILTER`,
  `CONFIG_NF_CONNTRACK_NETLINK`, `CONFIG_NF_TABLES`,
  `CONFIG_NETFILTER_XT_TARGET_MASQUERADE`). Explicit `=y` entries also
  override the kona stock baseline, which ships namespaces mostly off
  (e.g. `# CONFIG_PID_NS is not set`).
- `0001-official-fix-kernel-panic-in-xt_qtaguid.patch` — official
  non-GKI patch 1/2 (net/netfilter/xt_qtaguid.c). The LOS kona/sm8250
  4.19 tree does not contain xt_qtaguid at all, so this patch is inert
  on alioth; it is kept for other 4.19 trees that still carry qtaguid.
- `0002-official-fix-restore-cgroup-file-prefix-handling.patch` —
  official non-GKI patch 2/2 (kernel/cgroup/cgroup.c): re-creates the
  `subsys.name` kernfs symlink for files on `CGRP_ROOT_NOPREFIX`
  mounts, so runc/crun-style mounts see both names. The hunk context
  matches the 4.19 `cgroup_add_file()` verbatim and applies as-is on
  the LOS kona tree.

## Integration (alioth / LOS sm8250)

```bash
# patch 02 applies cleanly; patch 01 is a no-op on trees without qtaguid
for p in patches/droidspace/4.19/00*-*.patch; do
  git apply --check "$p" && git apply "$p" || echo "skip (no-op): $p"
done
```

The config fragment is merged by `scripts/merge-defconfig.sh` (pass
`patches/droidspace/4.19/droidspace.config` as a fragment), following
the same flow as the 4.9 devices' `patches/droidspace/common/`.
