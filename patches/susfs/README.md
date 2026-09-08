# patches/susfs — SuSFS 资产（非 GKI）

SuSFS 相关补丁资产按"上游素材 / 树适配"分置：

## 组成

- `upstream/` — susfs4ksu gki-android12-5.10 kernel_patches 镜像
  （`50_add_susfs_in_gki-android12-5.10.patch`、KernelSU
  `10_enable_susfs_for_ksu.patch`、`fs/susfs.c`、
  `include/linux/susfs.h`、`include/linux/susfs_def.h`）。5.10 分支是
  功能集基准（SUSFS_VERSION 等）。
- `4.9/` — LOS 4.9 树适配（susfs-49-test.patch 供 polaris；beryllium/
  daisy/vince/ 设备子目录放各设备 reference）。编译产物见各设备
  workflow 的 susfs-test 日志。
- `4.14/susfs-414-test.patch` — realme AndroidS MTK 4.14.186 树适配
  补丁（编译产物见 build-RMX2117.yml susfs-test 日志）。
- `4.19/susfs-419-test.patch` — LOS 4.19 树适配补丁（build-alioth.yml
  susfs-test 应用）。
- `susfs_inline_hook_patches-4.9.sh` — KSU-inline-hook 调用点生成器
  （ReSukiSU 签名，CI 内应用）。
- `susfs_inline_hook_patches.sh` — 上游生成器镜像（参考）。

## 重建与校验工具（scripts/）

- `scripts/sync-susfs-510.sh` — 上游镜像 check / refresh。
- `scripts/verify-susfs-parity.sh` — 上游刷新后的 parity 校验。
- `scripts/susfs-adapt-4.9.sh` — 4.9 树适配。

4.9 重建管线与 shipped 旧移植归档见 `test/susfs-510-to-49/` 与
`patches/test/susfs-shipped-4.9/`（README 各述其角色）。

## 上游跟踪

当上游 gki-android12-5.10 更新（SUSFS_VERSION 变更、susfs.c 改动），
执行 `scripts/sync-susfs-510.sh refresh` 更新 `upstream/`，随后按各
树适配 README 重新落位。
