# Droidspace 4.9（非 GKI）容器内核支持

Droidspaces（<https://github.com/ravindu644/Droidspaces-OSS>）是轻量
Linux 容器工具。本 4.9 非 GKI 内核的支持 = 内核 config 片段 + 一处
cgroup 源码修复。

## 组成

| 文件 | 作用 |
|---|---|
| `droidspace.config` | 内核 config 片段（由 `merge-defconfig.sh` 并入最终 `.config`），按官方 non-GKI 配置（Kernel-Configuration.md）的 4.9 符号名落位：`CONFIG_NF_CT_NETLINK`、`CONFIG_IP_NF_TARGET_MASQUERADE`（4.9 名）；`CONFIG_SECCOMP_FILTER` 在 4.9 是 `def_bool y`（依赖 `SECCOMP && NET`），随 `CONFIG_SECCOMP=y` 自动成立；关闭 `CONFIG_ANDROID_PARANOID_NETWORK` 使容器网络可用 |
| `0001-cgroup-noprefix-4.9-port.patch` | cgroup `subsys.file` kernfs 符号链接恢复（`noprefix` 挂载、systemd/runc 风格），移植到 4.9 布局（`kernel/cgroup.c`） |

官方 non-GKI 补丁组中针对 `net/netfilter/xt_qtaguid.c` 的另一补丁
本 sdm845 4.9 树不包含，故未采用。

## 上游核对（快照 v6.5.5）

片段现按上游 `Kernel-Configuration.md` 的 **Step 1 必选面（48 项）** 逐项落位
（上游快照：`localworkspace/mirrors/Droidspaces-OSS` @`2280b59`，v6.5.5）；
本树 Kconfig 不提供的三项（`FW_LOADER_COMPRESS`、`NETFILTER_XT_TARGET_MASQUERADE`、
`NF_CONNTRACK_NETLINK`）在片段注释中列明对应的 4.9 名或缺失事实。

## 集成

```bash
bash scripts/integrate-droidspace.sh <kernel-root> \
  patches/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch
```
