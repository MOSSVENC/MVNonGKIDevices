# patches/susfs — SuSFS 资产（非 GKI）

SuSFS 补丁资产按"上游素材 / 树适配"分置：

| 位置 | 内容 |
|---|---|
| 本地工作区上游素材镜像 | susfs4ksu gki-android12-5.10 kernel_patches 镜像（`50_add_susfs_in_gki-android12-5.10.patch`、KernelSU 侧 `10_enable_susfs_for_ksu.patch`、`fs/susfs.c`、`include/linux/susfs.h`、`include/linux/susfs_def.h`）。5.10 分支为功能集基准（SUSFS_VERSION 等） |
| `4.9/` | LOS 4.9 树适配。四个 port 同为 gki-android12-5.10 基线的 4.9 形态：polaris 由管线 translate 产出（与参考逐字一致），`beryllium/` `daisy/` `vince/` 与 polaris 的共享段落逐行同源，差异限于树属性段（stateful 树的 `security/selinux/{avc,hooks}.c`、daisy/vince 的 `fs/proc/cmdline.c`）。编译产物见各设备 workflow 的 susfs 日志 |
| `4.14/susfs-port.patch` | realme AndroidS MTK 4.14.186 树适配补丁：上游核心的 12–5.9 适配版 + 上游 kstat 面（详见 `localworkspace/pipelines/susfs-k4.14/README.md`；编译产物见 build-RMX2117.yml susfs 日志） |
| （4.9 素材基线） | polaris 4.9 树件重建自上游素材 gki-android12-5.10（789702e，含 7373f8d su-fd 修复）；并补齐 00:01 kstat refactor 的 6 个新符号面（inotify fdinfo / proc_fd seq / statfs spoof）4.9 移植，管线 verify 逐字节通过 |
| `4.19/susfs-port.patch` | LOS 4.19 树适配补丁：上游核心的 12–5.9 适配版 + 上游 kstat 面（详见 `localworkspace/pipelines/susfs-k4.19/README.md`；build-alioth.yml susfs 应用） |

KSU-inline-hook 调用点生成器为脚本（见 `scripts/susfs_inline_hook_patches-nongki.sh`：
跨 4.9/4.14/4.19 等非 GKI 内核的树适配版，运行时按目标树版本分派，CI 内应用）。

4.9 重建管线见本地 localworkspace/pipelines/susfs-k4.9/。

## 上游跟踪

上游 gki-android12-5.10 更新（SUSFS_VERSION 变更、susfs.c 改动）时：

1. 更新 本地工作区上游素材镜像 素材 + parity 校验：维护者本机工具
   （`localworkspace/maintain/` 的 `sync-susfs-510.sh` /
   `verify-susfs-parity.sh`，不随仓库分发——仓库内不做网络获取）
2. 按各树适配 README 重新落位并提交
