# MVNonGKIDevices — Android 内核 Action 仓库

构建脚本、补丁与配置片段在本仓库维护；内核源码固定在外部仓库（下表），
由 GitHub Actions 检出、按特性开关集成并编译，产物是 AnyKernel3 zip。
构建只通过 workflow_dispatch 手动触发。

本仓库只产内核，不产 ROM。刷机顺序是"先刷目标 ROM，再刷本仓库的内核 zip"。

## 支持设备

| 设备 | 代号 | 内核 | 内核源 / 分支 | workflow |
|---|---|---|---|---|
| Xiaomi Mi MIX 2S | `polaris` (sdm845) | 4.9.337 | [MOSSVENC/android_kernel_xiaomi_sdm845](https://github.com/MOSSVENC/android_kernel_xiaomi_sdm845) @ `lineage-22.2` | `build-polaris.yml` |
| Xiaomi POCO F1 | `beryllium` (sdm845) | 4.9.337 | [Flyme66/kernel_xiaomi_sdm845_tejas101k_beryllium](https://github.com/Flyme66/kernel_xiaomi_sdm845_tejas101k_beryllium) @ `thirteen` | `build-beryllium.yml` |
| Xiaomi Mi A2 Lite | `daisy` (msm8953) | 4.9.337 | [Flyme66/android_kernel_xiaomi_msm8953_ItsVixano_daisy](https://github.com/Flyme66/android_kernel_xiaomi_msm8953_ItsVixano_daisy) @ `lineage-20` | `build-daisy.yml` |
| Xiaomi Redmi 5 Plus | `vince` (msm8953) | 4.9.337 | [Flyme66/kernel_xiaomi_OctaviOS_vince](https://github.com/Flyme66/kernel_xiaomi_OctaviOS_vince) @ `13` | `build-vince.yml` |
| Xiaomi Redmi K40 / POCO F3 / Mi 11X | `alioth` (sm8250) | 4.19.325 | [MOSSVENC/android_kernel_xiaomi_sm8250](https://github.com/MOSSVENC/android_kernel_xiaomi_sm8250) @ `lineage-23.2` | `build-alioth.yml` |
| realme Q2 5G（国行） | `RMX2117` (mt6853) | 4.14.186 | [realme X7 系 AndroidS 综合源](https://github.com/MOSSVENC/realme_X7_X7Pro_X7ProExtreme_X7-5G_Q2Pro_V15_V5_Q2_Narzo30pro-5G_7-5G-AndroidS-kernel-source)（9 机共用）@ `master` | `build-RMX2117.yml` |

## 构建输入

所有设备共有：`kernel_ref`、`root_mode`、`localversion`、`build_time`、
`enable_bbg`、`enable_droidspace`、`auto_fix_49`。其余按设备追加：

| 输入 | 出现于 | 说明 |
|---|---|---|
| `cgroup_port` | polaris / beryllium / daisy / vince | 4.9 cgroup noprefix compat 补丁（需同时开 droidspace） |
| `enable_data_isolation` | polaris | sdcardfs per-uid `Android/data` 隔离 |
| `enable_battery_5000` | alioth | 5000mAh 电芯参数与快充电压上限 |

所有开关默认关闭，按构建需要手动选择。

## root_mode（root 管理器与 hook 组合）

| `root_mode` | root 管理器 | hook 形态 |
|---|---|---|
| `resukisu-manual-lsm` | BakaSU main | 源码补丁 + 自动 hook（input 经内核 input_handler；setuid/initrc 经 LSM AUTO） |
| `resukisu-manual-source` | BakaSU main | 源码补丁 + alt manual hooks（input/setuid/sys_read） |
| `resukisu-auto` | BakaSU auto-hook 分支 | 函数入口 inline-hook 引擎（免源码补丁，构建侧开 `KALLSYMS_ALL`；4.x 用 `auto_fix_49` kasan_reset_tag 门槛修正） |
| `resukisu-susfs` | BakaSU main | SuSFS inline hook（应用各设备树适配补丁） |
| `none`（默认） | — | stock，无 root 集成 |

值集六设备一致，共 5 值。`root_mode` 前缀沿用 `resukisu-`（workflow 接口名），
管理器本体是 BakaSU。

## BakaSU manual hook 七类

按 [bakasu.org manual-integrate](https://bakasu.org/zh-Hans/guide/manual-integrate.html)
（本地工作区 `localworkspace/evidence/resukisu-docs/` 有页面收录），
4 类必须改源码、3 类可选。

| hook | 内核文件 | 必打 | `resukisu-manual-lsm` | `resukisu-manual-source` |
|---|---|---|---|---|
| stat | fs/stat.c | 是 | 源码补丁 | 源码补丁 |
| execve | fs/exec.c | 是 | 源码补丁 | 源码补丁 |
| faccessat | fs/open.c | 是 | 源码补丁 | 源码补丁 |
| sys_reboot | kernel/reboot.c | 是 | 源码补丁（daisy/vince 用设备变体） | 同左 |
| input | drivers/input/input.c | 可选 | 内核 input_handler 自动 | `0010` 源码补丁 |
| setuid | kernel/sys.c | 可选 | LSM AUTO | `0011` 源码补丁 |
| sys_read(initrc) | fs/read_write.c | 可选 | LSM AUTO | `0012` 源码补丁 |

补丁按形态分目录存放，跨版本同形的单一真身存 `4.9/`，各版本只保留自己形态的件：

| 文件 | 4.9 | 4.14 | 4.19 |
|---|---|---|---|
| `0001-fs-stat` | 4.9 自有 | — | **4.19 自有** |
| `0002-fs-exec` | 共享 | 4.14 自有 | 取 4.9 |
| `0003-fs-open` | 共享 | 4.14 自有 | **4.19 自有** |
| `0004-kernel-reboot` | 共享 | — | 取 4.9 |
| `0010-input` | 共享 | 4.14 自有 | 取 4.9 |
| `0011-setuid` | 共享 | 4.14 自有 | **4.19 自有** |
| `0012-sysread` | 共享 | 4.14 自有 | **4.19 自有** |

alioth（4.19）由 workflow 以文件级清单跨目录引用：共享形态取 `4.9/`，
形态特有的取 `4.19/`。`fs/stat.c` 两版本差异在 include 形态
（4.9 `<asm/uaccess.h>`、4.19 `<linux/uaccess.h>`）与 64 位 stat 入口位置，
所以各自持有。

input hook 的自动面不经 LSM：input_handler 未损坏的内核只需
`CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y`，由内核 input_handler 特性
自动应用；setuid / initrc 两个自动面才走 LSM。

## 工具链

| 设备 | 配方 |
|---|---|
| polaris / alioth / beryllium / daisy / vince | AOSP clang 14（clang-r450784d，android13-release）+ GCC 4.9 binutils，`LD=ld.lld LLVM=1 LLVM_IAS=1`，4.9 另需 `CROSS_COMPILE_ARM32` 绝对前缀（compat vDSO） |
| RMX2117（4.14） | 官方 `build.config.mtk.aarch64` 配方：clang r383902 + GCC 4.9 的 `aarch64-linux-androidkernel-` 前缀，`LD=ld.lld NM=llvm-nm OBJCOPY=llvm-objcopy` |

## 特性细节

### Android/data 隔离（sdcardfs per-uid，仅 polaris）

顶层 mask 挡 readdir 枚举，但已知包路径的 stat/open 仍可探测其它应用的
`Android/data/<pkg>`。补丁 `patches/sdcardfs/0001-sdcardfs-android-data-isolation.patch`
把 AOSP data-isolation 语义搬进 sdcardfs：

- `uid < AID_APP_START` → 放行
- 包 owner（及其子树任意节点）→ 放行
- 其它 app 访问 → lookup/getattr/open 统一 `-EACCES`（与原生作用域存储对他人 `Android/data/<pkg>` 的报错一致）

owner 判定复用 vold 经 configfs 填的 packagelist。`Android/obb` 保持共享。

### 特性开关

| 特性 | 输入 | 说明 |
|---|---|---|
| BBG | `enable_bbg` | Baseband-guard 防格机 LSM（无本地补丁，官方 setup.sh） |
| Droidspace | `enable_droidspace` | 容器/LXC 内核支持（各树 port 不同） |
| Android/data 隔离 | `enable_data_isolation` | sdcardfs per-uid 隔离（仅 polaris） |
| 5000mAh 电池 | `enable_battery_5000` | 电池参数卡（容量/JEITA/表征）与快充电压上限按 5000mAh 电芯（仅 alioth；电池认证行为不变） |
| 自定义版本名 | `localversion` | 写进 `uname -r`（例如 `-MyKernel`；留空沿用 defconfig 值） |
| 自定义构建时间 | `build_time` | 写进 `uname -v` 的日期段（UTC，例 `Tue, 08 Sep 2026 21:01:02 +0000`；留空用构建时刻的 UTC 值） |

`auto_fix_49`：`resukisu-auto` 的 4.x kasan_reset_tag 门槛修正（auto-hook
分支对 <5.0 树的本征修正，4.9/4.14 设备构建 auto 模式时需勾选）。

susfs 应用路径（全部为树适配 port）：

| 设备 | port |
|---|---|
| polaris | `patches/susfs/4.9/susfs-port.patch` |
| alioth | `patches/susfs/4.19/susfs-port.patch` |
| beryllium / daisy / vince | `patches/susfs/4.9/<设备>/susfs-port.patch` |
| RMX2117 | `patches/susfs/4.14/susfs-port.patch` |

### 静态符号

selinux 静态符号由 `CONFIG_KALLSYMS_ALL=y` 的 kallsyms 解析（合并阶段无条件强制）。

## .config 合并顺序

`merge-defconfig.sh` 拼接各层后去重（同名后者胜出），再
`alldefconfig` + `olddefconfig` + 关键符号断言：

```
<BASE_DEFCONFIG>
  + <DEVICE_FRAGMENTS>
  + resukisu.config.fragment / susfs.config.fragment（按 root_mode）
  + bbg / droidspace fragment（按特性开关）
  + 强制覆盖：CC_WERROR off、KALLSYMS(+ALL)=y
  → 断言（缺失即失败）
```

顺序要点：root/特性的 Kconfig 必须先由 setup/补丁挂进内核 Kconfig 树
再合并，否则新符号会被静默丢弃。管线固定为：打补丁 → setup → 合并 →
断言 → 编译。

基线：

| 设备 | BASE_DEFCONFIG | DEVICE_FRAGMENTS |
|---|---|---|
| polaris | `vendor/xiaomi/mi845_defconfig` | `vendor/xiaomi/polaris.config` |
| alioth | `vendor/kona-perf_defconfig` | `vendor/debugfs.config`、`vendor/xiaomi/sm8250-common.config`、`vendor/xiaomi/alioth.config` |
| beryllium / daisy / vince | 自带自包含 defconfig | 见各自 workflow |
| RMX2117 | `k6853v1_64_6360_defconfig` | 见 workflow |

## 目录结构

```
patches/
  droidspace/          official/ 官方 non-GKI 补丁 + 4.9/4.14/4.19 config
  resukisu/            4.9/4.14/4.19 树适配补丁（文件级清单跨目录引用）
  susfs/               4.9/4.14/4.19 树适配补丁（含设备子目录）
  bbg/                 集成说明（无本地补丁）
  sdcardfs/            Android/data 隔离（仅 polaris）
  alioth/              min-tool-version.sh（构建辅助）
scripts/               编排脚本（apply-patches / integrate-* / merge-defconfig /
                       ak3-display 等）
localworkspace/        本机工作区（gitignored；布局见 localworkspace/README.md、条目索引见 INDEX.md）
.github/workflows/     每设备 CI
```

上游素材镜像（susfs / resukisu）、旧 shipped 归档与维护工具（sync/parity/管线）
均位于本地工作区（`localworkspace/`），不随仓库分发；官方补丁中 CI 直接应用的
（droidspace）保留在 `official/`。

## RMX2117（MTK 4.14）要点

- 源树 clone 到 `kernel-4.14/` 目录（oplus 电源头文件经
  `../../../../kernel-4.14/...` 相对路径引用，依赖该目录名）
- defconfig `k6853v1_64_6360_defconfig`（ARCH_MTK_PROJECT / appended-dtb /
  mt6360 PMIC 集）；合并强制 DEBUG_KERNEL / KALLSYMS(+ALL) 链
- 产物：`Image` + `mt6853.dtb`（boot 内 base dtb）+ AK3 zip
  （`Image.gz-dtb`：自编内核 + appended base dtb，与社区 Q2 构建同形态；
  dtb 与官方 boot 内 dtb 逐字节一致）
- boot 链：boot 内 base dtb + 独立 dtbo 分区（32 项目 overlay）；
  dtbo 内容沿用 stock 固件（源树缺项目 cust/overlay 层）
- 只刷 kernel 段（AK3/整 boot 重打包）、dtb/dtbo 保留的可用性为推断级，
  待真机验证
- 树内 Kconfig 带 CRLF 与老代码告警，warnings-only 编译

## 手动复现（polaris 示例）

其它设备换 clone 源 / 分支 / defconfig / 补丁清单（见各 workflow）：

```bash
KROOT=/path/to/kernel-clone   # git clone -b lineage-22.2 .../android_kernel_xiaomi_sdm845
cd "$KROOT"

# 1. BakaSU manual hook 源码补丁（root_mode=resukisu-auto / susfs 时跳过）
#    参数是补丁目录：目录内 0001-0004 / 0010-0012 按序应用
bash <repo>/scripts/apply-resukisu-manual-hooks.sh "$KROOT" \
  <repo>/patches/resukisu/4.9 <repo>/patches/resukisu/4.9

# 2. 集成（manual 示例；auto / susfs 换 integrate-resukisu.sh 参数）
bash <repo>/scripts/integrate-resukisu.sh "$KROOT" ./resukisu.config.fragment lsm manual true
bash <repo>/scripts/integrate-bbg.sh "$KROOT" ./bbg.config.fragment
PORT=<repo>/patches/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch
bash <repo>/scripts/integrate-droidspace.sh "$KROOT" "$PORT"

# 3. 合并 defconfig
FRAGS="./resukisu.config.fragment ./bbg.config.fragment <repo>/patches/droidspace/4.9/droidspace.config"
BASE_DEFCONFIG=arch/arm64/configs/vendor/xiaomi/mi845_defconfig \
DEVICE_FRAGMENTS="arch/arm64/configs/vendor/xiaomi/polaris.config" \
ROOT_MANAGER=resukisu ENABLE_BBG=true ENABLE_DROIDSPACE=true \
  bash <repo>/scripts/merge-defconfig.sh "$KROOT" /tmp/out $FRAGS

# 4. clang 14 编译（配方见"工具链"）
make -j$(nproc) O=/tmp/out ARCH=arm64 CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=<gcc64>/bin/aarch64-linux-android- \
  CROSS_COMPILE_ARM32=<gcc32>/bin/arm-linux-androideabi- \
  LD=ld.lld LLVM=1 LLVM_IAS=1
# 产物: /tmp/out/arch/arm64/boot/Image.gz-dtb
```

## 边界

- susfs：`resukisu-susfs`；各设备落位件由本地管线（`localworkspace/pipelines/`）维护
- Android/data 隔离仅 polaris；alioth（4.19 kona）无 sdcardfs
- vince 树自带旧 KernelSU：集成前用
  `patches/resukisu/4.9/vince/0000-remove-legacy-ksu-hooks.patch` 剥离
- Droidspace cgroup 移植补丁非致命：apply 失败自动跳过
- BakaSU 管理器（Manager APK）版本需自行匹配；setup.sh 按 root_mode
  分支拉取（manual=main、auto=auto-hook）
- 32 位兼容：`CONFIG_COMPAT=y`，fstat64/fstatat64 hook 在 `0001-fs-stat` 内
