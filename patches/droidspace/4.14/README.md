# Droidspace 4.14（MTK realme AndroidS 树）

面向 realme AndroidS common-source（MTK 4.14.186，
`MOSSVENC/realme_...AndroidS-kernel-source`）的 Droidspace/LXC 内核支持。

## 组成

| 文件 | 作用 |
|---|---|
| `../official/0001-official-fix-kernel-panic-in-xt_qtaguid.patch` | 官方 non-GKI 补丁 1/2（`net/netfilter/xt_qtaguid.c`）。MTK 4.14 树不含 xt_qtaguid，对 RMX2117 为惰性（no-op）；保留供仍带 qtaguid 的其它 4.14 树 |
| `../official/0002-official-fix-restore-cgroup-file-prefix-handling.patch` | 官方 non-GKI 补丁的唯一副本（版本目录不存放副本；workflow 直接引用 official 路径）。对 MTK 4.14 树 `kernel/cgroup/cgroup.c` 直接可应用（真实 git apply 验证，落位 `cgroup_add_file`），为 NOPREFIX 挂载下的子系统文件补回 `subsys.name` 前缀名符号链接，供容器工具链按带前缀名查找 |
| `droidspace.config` | 官方 Kernel-Configuration.md 的 4.14 落位；与 4.9 片段（`patches/droidspace/4.9/droidspace.config`）的差异见文件头 |

## 应用

- 补丁：`bash scripts/integrate-droidspace.sh <kernel-root>
  patches/droidspace/official/0002-official-fix-restore-cgroup-file-prefix-handling.patch`
  （构建时由 workflow 在 CI 内应用；缺失或 apply 失败即中止）
- config：`merge-defconfig.sh` 以 fragment 合并
  （BASE_DEFCONFIG=k6853v1_64_6360_defconfig、ENABLE_DROIDSPACE=true），
  断言组校验命名空间 / cgroup / 设备节点符号

## 符号核对

符号存在性逐一对照 MTK 4.14.186 树 Kconfig，片段覆盖非-GKI 核心面并含
资源限额（`MEMCG_SWAP`、`CFS_BANDWIDTH`、`CGROUP_CPUACCT`）、IPv6 NAT 组
（`IPV6`、`IPV6_MULTIPLE_TABLES`、`IP6_NF_*`、`NF_CONNTRACK_IPV6`、
`NF_NAT_IPV6`）与 `MACVLAN`；`CGROUP_NET_PRIO`（`net/Kconfig:257`）与
`BRIDGE_NETFILTER`（`net/Kconfig:180`）在本树存在，已随必选块显式置 `=y`。
本树 Kconfig 不提供的四项（`ANDROID_PARANOID_NETWORK`、
`FW_LOADER_COMPRESS`、`NETFILTER_XT_TARGET_MASQUERADE`、`NF_CONNTRACK_NETLINK`）
在片段注释中列明。

## 上游核对（2026-11-07）

Droidspaces-OSS `main` / `dev` 当前快照为 `cdadb9eb5d0f`。non-GKI 的两个
官方补丁与仓库 `official/` 副本逐字节一致（补丁哈希仍为
`f71898942e0f` / `6d2c9dbe5aa3`）。上游 `Kernel-Configuration.md` 的必选块
包含内存 swap、CFS bandwidth、CPU accounting、IPv6 NAT 与 macvlan；本目录
片段按该清单落位。
