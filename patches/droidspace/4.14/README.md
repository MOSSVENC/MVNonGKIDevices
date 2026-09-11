# Droidspace 4.14（MTK realme AndroidS 树）

面向 realme AndroidS common-source（MTK 4.14.186，
`MOSSVENC/realme_...AndroidS-kernel-source`）的 Droidspace/LXC 内核支持。

## 组成

| 文件 | 作用 |
|---|---|
| `../official/0002-official-fix-restore-cgroup-file-prefix-handling.patch` | 官方 non-GKI 补丁的唯一副本（版本目录不存放副本；workflow 直接引用 official 路径）。对 MTK 4.14 树 `kernel/cgroup/cgroup.c` 直接可应用（真实 git apply 验证，落位 `cgroup_add_file`），为 NOPREFIX 挂载下的子系统文件补回 `subsys.name` 前缀名符号链接，供容器工具链按带前缀名查找 |
| `droidspace.config` | 官方 Kernel-Configuration.md 的 4.14 落位；与 4.9 片段（`patches/droidspace/4.9/droidspace.config`）的差异见文件头 |

## 应用

- 补丁：`git apply patches/droidspace/official/0002-*.patch`（构建时由
  workflow 在 CI 内应用）
- config：`merge-defconfig.sh` 以 fragment 合并
  （BASE_DEFCONFIG=k6853v1_64_6360_defconfig、ENABLE_DROIDSPACE=true），
  断言组校验命名空间 / cgroup / 设备节点符号

## 上游核对（快照 v6.5.5）

符号存在性逐一对照 MTK 4.14.186 树 Kconfig，片段按上游 Step 1 必选面（48 项）落位；
`CGROUP_NET_PRIO`（`net/Kconfig:257`）与 `BRIDGE_NETFILTER`（`net/Kconfig:180`）在本树存在，
已随必选块显式置 `=y`。本树 Kconfig 不提供的四项（`ANDROID_PARANOID_NETWORK`、
`FW_LOADER_COMPRESS`、`NETFILTER_XT_TARGET_MASQUERADE`、`NF_CONNTRACK_NETLINK`）在片段注释中列明。
上游快照：`localworkspace/mirrors/Droidspaces-OSS` @`2280b59`（v6.5.5）。
