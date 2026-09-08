# Droidspaces 4.14（MTK realme AndroidS 树）

面向 realme AndroidS common-source（MTK 4.14.186，
`MOSSVENC/realme_...AndroidS-kernel-source`）的 Droidspaces/LXC 内核支持。

## 组成

- `0002-official-fix-restore-cgroup-file-prefix-handling.patch` — 官方
  non-GKI 补丁（ravindu644/Droidspaces-OSS），对 MTK 4.14 树
  kernel/cgroup/cgroup.c 直接可应用（真实 git apply 验证，落位在
  `cgroup_add_file`）。NOPREFIX 挂载下为子系统文件补回 `subsys.name`
  前缀名 symlink，供容器工具链按带前缀名查找。
- `droidspace.config` — 官方 Kernel-Configuration.md 的 4.14 落位；
  相对 4.9 片段（`patches/droidspace/common/`）的差异见文件头。

## 应用

- 补丁：`git apply patches/droidspace/4.14/0002-*.patch`（构建时由
  workflow 在 CI 内应用，非致命：应用失败仅记录）
- config：`merge-defconfig.sh` 以 fragment 合并
  （BASE_DEFCONFIG=k6853v1_64_6360_defconfig, ENABLE_DROIDSPACE=true），
  断言组校验命名空间/cgroup/设备节点符号。

## 版本核对（2026-09）

符号存在性逐一对 MTK 4.14.186 树的 Kconfig 核对；4.14 无
CGROUP_NET_PRIO / BRIDGE_NETFILTER 独立符号，已在 config 中处理。
