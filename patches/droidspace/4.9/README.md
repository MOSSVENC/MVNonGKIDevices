# Droidspace 4.9（非 GKI）容器内核支持

Droidspaces（<https://github.com/ravindu644/Droidspaces-OSS>）是轻量
Linux 容器工具。本 4.9 非 GKI 内核的支持 = 内核 config 片段 + 一处
cgroup 源码修复。

## 组成

| 文件 | 作用 |
|---|---|
| `droidspace.config` | 内核 config 片段（由 `merge-defconfig.sh` 并入最终 `.config`），按官方 non-GKI 配置（Kernel-Configuration.md）的必选清单落位：含资源限额（`CONFIG_MEMCG_SWAP`、`CONFIG_CGROUP_CPUACCT`、`CONFIG_CFS_BANDWIDTH`）、IPv6 NAT 组（`CONFIG_IPV6`、`CONFIG_IP6_NF_*`、`CONFIG_NF_CONNTRACK_IPV6`、`CONFIG_NF_NAT_IPV6`）与 `CONFIG_MACVLAN`；片段关闭 `CONFIG_SCHED_WALT`，使 4.9 树可选 `CONFIG_CFS_BANDWIDTH` 并置 `=y`；4.9 符号名为 `CONFIG_NF_CT_NETLINK`、`CONFIG_IP_NF_TARGET_MASQUERADE`；`CONFIG_SECCOMP_FILTER` 在 4.9 是 `def_bool y`（依赖 `SECCOMP && NET`），随 `CONFIG_SECCOMP=y` 自动成立；关闭 `CONFIG_ANDROID_PARANOID_NETWORK` 使容器网络可用 |
| `0001-cgroup-noprefix-4.9-port.patch` | cgroup `subsys.file` kernfs 符号链接恢复（`noprefix` 挂载、systemd/runc 风格），移植到 4.9 布局（`kernel/cgroup.c`） |

官方 non-GKI 补丁组的两件原件收录在 `official/`；`01` 面向 `net/netfilter/xt_qtaguid.c`
（本树不带该文件），本 port 采用上表的 `0001` 形态。

## 符号核对

片段覆盖非-GKI 容器启动所需的命名空间、cgroup、资源限额、IPv4/IPv6 NAT、
macvlan 与设备节点核心面；4.9 树 Kconfig 不提供的 `FW_LOADER_COMPRESS`、
`NETFILTER_XT_TARGET_MASQUERADE`、`NF_CONNTRACK_NETLINK` 在片段注释中列明
对应的 4.9 名或缺失事实。片段关闭 `CONFIG_SCHED_WALT`，调度切回 PELT，
`CONFIG_CFS_BANDWIDTH` 因此可选并置 `=y`；厂商 WALT 调度调参在启用
Droidspace 的构建中不生效。

## 集成

```bash
bash scripts/integrate-droidspace.sh <kernel-root> \
  patches/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch
```

## 状态

polaris（mix2s）编译面实测通过：`build-polaris`（`dc8e718`，`enable_droidspace`
+ `cgroup_port`）中 `integrate-droidspace.sh` 落位该 4.9 cgroup port，合并阶段的
命名空间 / cgroup / 设备节点断言组全过（`CONFIG_SYSVIPC` 至 `CONFIG_BRIDGE`，
含 `CONFIG_ANDROID_PARANOID_NETWORK is not set`），并产出内核镜像与 AK3 包；
运行面（容器启动、网络模式）待刷机实测。

## 上游核对（2026-11-07）

Droidspaces-OSS `main` / `dev` 当前快照为 `cdadb9eb5d0f`。non-GKI 的两个
官方补丁与仓库 `official/` 副本逐字节一致（补丁哈希仍为
`f71898942e0f` / `6d2c9dbe5aa3`）。上游 `Kernel-Configuration.md` 的必选块
包含内存 swap、CFS bandwidth、CPU accounting、IPv6 NAT 与 macvlan；本目录
片段按该清单落位（4.9 片段关闭 `SCHED_WALT` 并置 `CFS_BANDWIDTH=y`）。
