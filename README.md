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
| Android/data 隔离 | `features.data_isolation.enabled` | sdcardfs per-uid 隔离 `Android/data/<pkg>`：非 owner app lookup/getattr 得 ENOENT | on |

`workflow_dispatch` 里同名布尔输入可单次覆盖；`configs/mix2s.yaml` 是默认值。

### Android/data 隔离（sdcardfs per-uid ENOENT）

背景：4.9 非 GKI 机器上 `/storage/emulated/0/Android/{data,obb}` 是 **sdcardfs
bind-mount**（`/dev/fuse` 只服务到 `/storage/emulated` 上层），MediaProvider
FUSE daemon 的 data-isolation 判权（`isUidAllowedAccessToDataOrObbPath`）**永远
看不到这些 lookup**——它在 AOSP 里是为 GKI 5.10+ FUSE daemon 设计的，且 4.9
无 FUSE BPF。sdcardfs 自身只把顶层 mask 成 0711：挡住 readdir 枚举，但
**已知包路径的 stat/open 仍成功**，于是任何 app 都能探测任意已装应用的
`Android/data/<pkg>` 是否存在（包名泄漏）。

补丁 `patches/sdcardfs/0001-sdcardfs-android-data-isolation.patch` 把 AOSP
语义搬进 sdcardfs：
- `uid < AID_APP_START`（root/系统/媒体/shell）→ 放行
- 包 owner（或该包 `Android/data/<pkg>` 子树内任意节点）→ 放行
- 其它 app 访问 `Android/data/<pkg>` → lookup/getattr 返回 **ENOENT**（干净
  "不存在"，stat 类探测不会误判 EACCES 为存在），open 返回 EACCES

owner 判定复用 vold 经 configfs 填的 packagelist（`get_appid` + userid），与
sdcardfs 自身 `derived_perm.c` 算 `d_uid` 同源。`Android/obb` 保持共享（本机
挂载无 `unshared_obb`）。已知边界：能拿到"所有文件访问"的特权 app 不在这条
链路内（那是 Android 的授权语义，非本补丁范围）。

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

### 静态符号：由 CONFIG_KALLSYMS_ALL 代替手动导出

manual-integrate 文档的 [static-symbol-export](https://resukisu.org/zh-Hans/guide/manual-integrate.html#static-symbol-export)
章节要求对部分 selinux 静态符号去 static（write_op / sel_handle_status_ops /
selinux_status_page / selinux_status_lock / sel_mutex / policy_rwlock / selinux_ops /
security_dump_masked_av / context_struct_compute_av），但这只在
`CONFIG_KALLSYMS_ALL` **关闭**时才是必须的：

- 官方 `kernel/Kbuild`：`ifneq ($(CONFIG_KALLSYMS_ALL),y) → include static_export_check.mk`
  —— 开了 KALLSYMS_ALL 连导出检查都跳过；
- ReSukiSU 源码对所有符号都是 `#ifdef CONFIG_KALLSYMS_ALL` → kallsyms 查表 /
  `#else` → `extern` 直接引用的双路径；KALLSYMS_ALL=y 恒走查表，static 与否无关；
- 基线 `mi845_defconfig` 自带 `CONFIG_KALLSYMS_ALL=y`（本仓库不做覆盖），
  4.9 内核导出 `kallsyms_lookup_name`/`kallsyms_on_each_symbol`（EXPORT_SYMBOL_GPL），
  查表链路完整可用。

因此**本仓库不打任何去 static 的导出补丁**（不再有 0005），selinux 静态符号
全部由 KALLSYMS_ALL 的 kallsyms 查表解析。若未来某次构建关闭
KALLSYMS_ALL，需按官方 static_export_check.mk 清单补回手动导出。

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
patches/resukisu-manual-hook/common/  4 个内核源码补丁（stat/exec/open/reboot；静态符号靠 KALLSYMS_ALL，不导出）
patches/bbg/common/                   集成说明（无本地补丁，跑官方 setup.sh）
patches/droidspace/common/            droidspace.config + 说明
patches/droidspace/polaris/            cgroup 前缀 4.9 移植补丁（官方 02 的移植）
patches/sdcardfs/                     Android/data per-uid 隔离补丁（data_isolation）
scripts/                              编排脚本（见下）
.github/workflows/build-mix2s.yml     CI
```

CI 里所有补丁应用后会先 `git commit` 一次内核树，让 `setlocalversion` 看到
干净 git 状态——**版本串不再带 `-dirty` 后缀**，同时保留 `git describe` 的
提交号（如 `4.9.337-perf-g<sha>`）。


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
