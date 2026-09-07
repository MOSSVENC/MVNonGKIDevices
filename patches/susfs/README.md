# patches/susfs — SuSFS for 4.9 (Non-GKI)

4.9 SuSFS 移植资产：CI 依序应用的模块化补丁（0001-0004）、上游 gki-android12-5.10 镜像
（功能来源基准）、以及从上游派生 4.9 形态的重建工具。

## 文件

- CI 按序应用的模块化补丁（0001→0004，依序 git apply）：
  - `0001-susfs-core.patch` — core：fs/susfs.c、include/linux/susfs.h、
    susfs_def.h
  - `0002-susfs-vfs-hooks.patch` — VFS hook 点（namespace/proc/readdir/
    statfs/kallsyms/memory/avc 等 13 文件）
  - `0003-susfs-ksu-hooks.patch` — KSU 交互 hook 调用点（exec/open/
    read_write/input/reboot/hooks/services 等 7 文件）
  - `0004-susfs-overlay.patch` — namei/stat/sys（VFS 与 KSU hook 同文件
    叠加，整文件归此层）
- `polaris-susfs-final.patch` — 上述 4 补丁合并的冻结快照（参考/回归
  基准）。依序应用 4 补丁与整包逐字节一致（实测 23/23）。
- `susfs_patch_to_4.9.patch` — 4.9 hook 点基底的冻结参考（其在重建管线
  中的角色见 test/susfs-510-to-49/README.md）。
- `susfs_inline_hook_patches-4.9.sh` — KSU-inline-hook 调用点生成器
  （ReSukiSU 签名）。
- `susfs_inline_hook_patches.sh` — 上游生成器镜像（参考）。
- `upstream-5.10/` — susfs4ksu gki-android12-5.10 kernel_patches 镜像。
- `../../scripts/susfs-adapt-4.9.sh` — 两个文件的 stock-4.9 适配。
- `../../scripts/verify-susfs-parity.sh` — 上游刷新后的 parity 校验。
- `../../scripts/sync-susfs-510.sh` — 上游镜像 check / refresh。

## 重建路径

1. `bash scripts/susfs-adapt-4.9.sh`
2. `bash susfs_inline_hook_patches-4.9.sh`
3. `git diff` → `polaris-susfs-final.patch`

可复现构建器见 `test/susfs-510-to-49/translate.sh`：从上游镜像 + 适配
资产重建快照，并与 `polaris-susfs-final.patch` 做逐字校验。

## 上游跟踪（gki-android12-5.10）

- `upstream-5.10/` 是功能集合的基准。
- `scripts/sync-susfs-510.sh check|refresh` 对比 / 刷新镜像。
- 上游升版时：刷新镜像 → 跑 `verify-susfs-parity.sh` → 按重建路径
  重新派生 4.9 快照 → CI 构建（hook_mode=susfs）。

## 4.9 形态

9 个 Kconfig 特性 + susfs.c API 与上游一致。4.9 上 AS_FLAGS_* 存于
`inode->i_state` 高位（33/34/35/36/39）；sdcard fsnotify handler 经
`SUSFS_DECL_FSNOTIFY_OPS` 声明（旧 fsnotify API）；selinux-hide 用户态
查询伪造（setprocattr/context/access/status 节点）由 ReSukiSU 内建
fallback 基于 backup policydb 提供。4.9 与上游的 parity 校验结果见
`scripts/verify-susfs-parity.sh`。

## CI 应用

依序 `git apply 0001-susfs-core.patch 0002-susfs-vfs-hooks.patch
0003-susfs-ksu-hooks.patch 0004-susfs-overlay.patch` + config fragment
（CONFIG_KSU_SUSFS=y + 子项；hook_mode=susfs）。
