# MVNonGKIDevices — Android 内核 Action 仓库（补丁 + 构建编排）

本仓库**不包含内核源码**，只存放构建脚本 / 补丁 / 配置片段，通过
GitHub Actions 在 CI 中拉取内核源码后按特性开关集成并编译。

当前目标设备：**Xiaomi Mi Mix 2S（`polaris` / sdm845）**
内核源：`https://github.com/MOSSVENC/android_kernel_xiaomi_sdm845`
分支：`lineage-22.2`（Linux **4.9.337**, arm64）

## 特性开关（编译时可组合）

| 特性 | YAML 键 | 说明 | 默认 |
|---|---|---|---|
| ReSukiSU | `features.resukisu.enabled` | KernelSU 系 root（**manual hook**，4.9 唯一支持项；susfs 预留未做） | on |
| BBG | `features.bbg.enabled` | Baseband-guard 防格机 LSM | on |
| Droidspace | `features.droidspace.enabled` | 容器/LXC/Docker 内核支持 | on |

`workflow_dispatch` 里同名布尔输入可单次覆盖；`configs/mix2s.yaml` 是默认值。

### ReSukiSU 的 7 类 hook 与覆盖方式

按 [resukisu.org manual-integrate](https://resukisu.org/zh-Hans/guide/manual-integrate.html)，
manual hook 共 7 类；4 类必须改内核源码，3 类可选：

| hook | 内核文件 | 是否必打 | 本仓库做法 |
|---|---|---|---|
| stat | fs/stat.c | 必 | `common/0001` |
| execve | fs/exec.c | 必 | `common/0002` |
| faccessat | fs/open.c | 必 | `common/0003` |
| sys_reboot | kernel/reboot.c | 必 | `common/0004` |
| input | drivers/input/input.c | 可选 | `hook_extra: lsm` → input_handler AUTO；`manual` → `alt-hooks/0010` |
| setuid | kernel/sys.c | 可选 | `hook_extra: lsm` → LSM AUTO；`manual` → `alt-hooks/0011` |
| sys_read(initrc) | fs/read_write.c | 可选 | `hook_extra: lsm` → LSM AUTO；`manual` → `alt-hooks/0012` |

- `hook_extra: lsm`（默认，4.9 < 6.8 官方推荐）—— 3 个可选 hook 由 ReSukiSU 的
  LSM / input_handler AUTO 机制接管，fragment 置 `CONFIG_KSU_MANUAL_HOOK_AUTO_*=y`，
  不打源码补丁。
- `hook_extra: manual` —— 打 `patches/resukisu-manual-hook/alt-hooks/0010~0012`
  源码补丁，fragment 关掉三个 AUTO（`# ... is not set`），编译期
  `manual_hook_check.mk` 会改为校验手动符号。
- workflow_dispatch 输入 `hook_extra`（choice lsm/manual）可单次切换。

## 最终 .config 合并顺序

```
vendor/xiaomi/mi845_defconfig        ← 基线（LOS 官方为小米 845 全家维护）
  + vendor/xiaomi/polaris.config     ← 机型片段（LOS 设备树 +=）
  + patches/droidspace/common/droidspace.config   [droidspace on]
  + resukisu.config.fragment         [resukisu on] (CONFIG_KSU=y MANUAL_HOOK=y ...)
  + bbg.config.fragment              [bbg on]      (CONFIG_BBG=y)
  → scripts/kconfig/merge_config.sh -m   （同名项后者覆盖前者）
  → make olddefconfig                    （按 Kconfig 默认收敛新符号）
  → 关键项断言（缺失即失败）
```

顺序要点：resukisu/bbg 的 Kconfig 必须**先**由各自的 `setup.sh` 挂进内核
Kconfig 树，再执行合并，否则 `olddefconfig` 看不到新符号会静默丢弃；
所以管线固定为 打补丁 → 跑 setup → 合并 → 断言 → 编译。

## 为什么基线用 mi845_defconfig 而不是 sdm845-perf_defconfig

- LOS 官方钦定：`android_device_xiaomi_sdm845-common` 的
  `TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig`；
  `android_device_xiaomi_polaris` 再 `+= vendor/xiaomi/polaris.config`。
- `arch/arm64/configs/sdm845(-perf)_defconfig` 是 CAF 高通参考板配置：缺
  小米量产必需项（`QCA_CLD_WLAN`/WiFi、`MSM_QDSP6_*`/音频、指纹等 51 项），
  却带一堆评估板/调试项（`IOMMU_DEBUG`、`CORESIGHT_*`、板载网卡、强制模块
  签名等）。名字里的 "-perf" 只是高通 flavor 标签，不代表更优。

## 目录结构

```
configs/mix2s.yaml                    设备/特性配置（默认值）
patches/resukisu-manual-hook/common/  5 个内核源码补丁（stat/exec/open/reboot/selinux export）
patches/bbg/common/                   集成说明（无本地补丁，跑官方 setup.sh）
patches/droidspace/common/            droidspace.config + 说明
patches/droidspace/polaris/            cgroup 前缀 4.9 移植补丁（官方 02 的移植）
scripts/                              编排脚本（见下）
.github/workflows/build-mix2s.yml     CI
```

## 手动复现

```bash
KROOT=/path/to/kernel-clone   # git clone -b lineage-22.2 .../android_kernel_xiaomi_sdm845
bash scripts/apply-patches.sh "$KROOT" patches/resukisu-manual-hook/common
bash scripts/integrate-resukisu.sh "$KROOT" ./resukisu.config.fragment
bash scripts/integrate-bbg.sh "$KROOT" ./bbg.config.fragment
PORT=patches/droidspace/polaris/0001-cgroup-noprefix-4.9-port.patch
bash scripts/integrate-droidspace.sh "$KROOT" "$PORT"
FRAGS="./resukisu.config.fragment ./bbg.config.fragment patches/droidspace/common/droidspace.config"
ENABLE_RESUKISU=true ENABLE_BBG=true ENABLE_DROIDSPACE=true \
  bash scripts/merge-defconfig.sh "$KROOT" /tmp/out $FRAGS
bash scripts/build-kernel.sh "$KROOT" /tmp/out
```

## 已知取舍 / 边界

- **susfs inline hook**：ReSukiSU Kconfig 在 4.9 上可选（arm64 满足
  `THREAD_INFO_IN_TASK && 64BIT`），但 susfs4ksu 官方 `kernel-4.9` 分支基于
  原版 KernelSU、需自行移植到 ReSukiSU。本仓库**未实现**，`hook_mode` 字段
  预留。只交付 manual hook。
- **Droidspace 官方 01 补丁（xt_qtaguid）**：本内核树无该文件，不拉取。
- **Droidspace 02 移植补丁**：非致命；apply 失败自动跳过（4.9 原生
  `cgroup_file_name` 已处理大部分前缀语义）。
- ReSukiSU 与管理器（Manager APK）版本需自行匹配；仓库固定引用其
  `main` 分支的 `kernel/setup.sh`。
- 32 位兼容：`CONFIG_COMPAT=y`，故 `fstat64/fstatat64` 的 hook 也必须打
  （已包含在 0001）。
