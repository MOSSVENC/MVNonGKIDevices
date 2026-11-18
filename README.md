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

## 构建输入

所有设备共有：`kernel_ref`、`root_mode`、`localversion`、`build_time`、
`enable_bbg`、`enable_droidspace`。其余按设备追加：

| 输入 | 出现于 | 说明 |
|---|---|---|
| `cgroup_port` | polaris / beryllium / daisy / vince | 4.9 cgroup noprefix compat 补丁（需同时开 droidspace） |
| `enable_data_isolation` | polaris | sdcardfs per-uid `Android/data` 隔离 |

所有开关默认关闭，按构建需要手动选择。

## root_mode（root 管理器与 hook 组合）

| `root_mode` | root 管理器 | hook 形态 |
|---|---|---|
| `bakasu-manual-lsm` | BakaSU main | 源码补丁 + 自动 hook（input 经内核 input_handler；setuid/initrc 经 LSM AUTO） |
| `bakasu-manual-source` | BakaSU main | 源码补丁 + alt manual hooks（input/setuid/sys_read） |
| `bakasu-susfs` | BakaSU main | SuSFS inline hook（应用各设备树适配补丁） |
| `xxksu-syscall_table` | XXKSU（Backslashxx KernelSU fork） | `KSU_TAMPER_SYSCALL_TABLE` 引擎（改 syscall 表项，免源码补丁） |
| `xxksu-branch_link` | XXKSU（Backslashxx KernelSU fork） | `KSU_HACK_ARM64_BRANCH_LINK` 引擎（改 `sys_call_table` 分支，免源码补丁） |
| `none`（默认） | — | stock，无 root 集成 |

值集六设备一致，共 6 值。前缀即管理器：`bakasu-` 走 BakaSU，`xxksu-` 走 Backslashxx fork；
两个 fork 引擎在 Kconfig 层互斥（`KSU_HACK_ARM64_BRANCH_LINK` 依赖
`!KSU_TAMPER_SYSCALL_TABLE`），一次构建只开一个，脚本按 `root_mode` 后缀只写一个。

### 上游锁定

CI 使用可复现的上游提交，不在每次构建时跟随移动分支：

| 组件 | 固定提交 |
|---|---|
| BakaSU main（manual / susfs） | `7b65bde0710b` |
| XXKSU fork（syscall_table / branch_link） | `1b8ce9e15a94` |
| Baseband-guard | `028ff7fd509e` |

`BAKASU_REF` / `XXKSU_REF` / `BBG_REF` 可显式覆盖对应提交，用于验证上游更新；默认构建保持锁定。

## BakaSU manual hook 七类

按 [bakasu.org manual-integrate](https://bakasu.org/zh-Hans/guide/manual-integrate.html)
（本地工作区 `localworkspace/evidence/bakasu-docs/` 有页面收录），
4 类必须改源码、3 类可选。

| hook | 内核文件 | 必打 | `bakasu-manual-lsm` | `bakasu-manual-source` |
|---|---|---|---|---|
| stat | fs/stat.c | 是 | 源码补丁 | 源码补丁 |
| execve | fs/exec.c | 是 | 源码补丁 | 源码补丁 |
| faccessat | fs/open.c | 是 | 源码补丁 | 源码补丁 |
| sys_reboot | kernel/reboot.c | 是 | 源码补丁（daisy/vince 用设备变体） | 同左 |
| input | drivers/input/input.c | 可选 | 内核 input_handler 自动 | `0010` 源码补丁 |
| setuid | kernel/sys.c | 可选 | LSM AUTO | `0011` 源码补丁 |
| sys_read(initrc) | fs/read_write.c | 可选 | LSM AUTO | `0012` 源码补丁 |

源码 hook 补丁落在 `patches/root-manager/bakasu/manual/4.9/`（必加组 `0001`–`0004`、
可选组 `0010`–`0012`），设备树对 `0004-kernel-reboot` 的变体放在
`patches/root-manager/bakasu/device/<设备>/4.9/`，workflow 以文件级清单引用。

input hook 的自动面不经 LSM：input_handler 未损坏的内核只需
`CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y`，由内核 input_handler 特性
自动应用；setuid / initrc 两个自动面才走 LSM。

## 工具链

| 设备 | 配方 |
|---|---|
| polaris / beryllium / daisy / vince | AOSP clang 14（clang-r450784d，android13-release）+ GCC 4.9 binutils，`LD=ld.lld LLVM=1 LLVM_IAS=1`，4.9 另需 `CROSS_COMPILE_ARM32` 绝对前缀（compat vDSO） |

## 特性细节

### Android/data 隔离（sdcardfs per-uid，仅 polaris）

顶层 mask 挡 readdir 枚举，但已知包路径的 stat/open 仍可探测其它应用的
`Android/data/<pkg>`。补丁 `patches/kernel/sdcardfs/0001-sdcardfs-android-data-isolation.patch`
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
| 自定义版本名 | `localversion` | 写进 `uname -r`（例如 `-MyKernel`；留空沿用 defconfig 值） |
| 自定义构建时间 | `build_time` | 写进 `uname -v` 的日期段（UTC，例 `Tue, 08 Sep 2026 21:01:02 +0000`；留空用构建时刻的 UTC 值） |

XXKSU 两个引擎都不加源码 hook 调用点：`syscall_table` 改系统调用表、`branch_link` 改写
`sys_call_table` 的分支，sucompat 入口由 fork 自身解析。fragment 由
`scripts/integrate-xxksu.sh` 生成（`CONFIG_KSU=y` + `CONFIG_KSU_LSM_SECURITY_HOOKS=y` +
一个引擎），fork 的 `kernel/` 同时链到 `KernelSU/kernel` 与 `drivers/kernelsu`。

susfs 应用路径（全部为树适配 port）：

| 设备 | port |
|---|---|
| polaris | `patches/kernel/susfs/4.9/polaris/susfs-port.patch` |
| beryllium / daisy / vince | `patches/kernel/susfs/4.9/<设备>/susfs-port.patch` |

### 静态符号

selinux 静态符号由 `CONFIG_KALLSYMS_ALL=y` 的 kallsyms 解析（合并阶段无条件强制）。

## .config 合并顺序

`merge-defconfig.sh` 拼接各层后去重（同名后者胜出），再
`alldefconfig` + `olddefconfig` + 关键符号断言：

```
<BASE_DEFCONFIG>
  + <DEVICE_FRAGMENTS>
  + bakasu.config.fragment / susfs.config.fragment（按 root_mode）
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
| beryllium / daisy / vince | 自带自包含 defconfig | 见各自 workflow |

## 目录结构

```
patches/               分类规则见 patches/README.md
  root-manager/bakasu/ checkout/（checkout 级）+ manual/4.9/（源码 hook）
                       + device/{daisy,vince}/4.9/（设备覆盖件）
  kernel/susfs/4.9/    每设备一份 susfs-port.patch
  kernel/droidspace/   4.9 树 port + config；upstream/ 为官方 non-GKI 补丁
  kernel/sdcardfs/     Android/data 隔离（仅 polaris）
  kernel/bbg/          集成说明（无本地补丁）
scripts/               编排脚本（apply-patches / integrate-* / merge-defconfig /
                       ak3-display 等）
localworkspace/        本机工作区（gitignored；布局见 localworkspace/README.md、条目索引见 INDEX.md）
.github/workflows/     每设备 CI
```

上游素材镜像（susfs / bakasu）、旧 shipped 归档与维护工具（sync/parity/管线）
均位于本地工作区（`localworkspace/`），不随仓库分发；官方补丁中 CI 直接应用的
（droidspace）保留在 `official/`。

## 手动复现（polaris 示例）

其它设备换 clone 源 / 分支 / defconfig / 补丁清单（见各 workflow）：

```bash
KROOT=/path/to/kernel-clone   # git clone -b lineage-22.2 .../android_kernel_xiaomi_sdm845
cd "$KROOT"

# 1. BakaSU manual hook 源码补丁（root_mode=bakasu-susfs / xxksu-* 时跳过）
#    目录模式只应用必加组；HOOK_EXTRA=manual 时再由第三参数选 0010-0012
HOOK_EXTRA=lsm bash <repo>/scripts/apply-bakasu-manual-hooks.sh \
  "$KROOT" <repo>/patches/root-manager/bakasu/manual/4.9 <repo>/patches/root-manager/bakasu/manual/4.9

# 2. 集成（manual 示例；susfs 换 integrate-bakasu.sh 的 hook_type，xxksu-* 改走
#    scripts/integrate-xxksu.sh 并按其 fragment 合并 defconfig）
bash <repo>/scripts/integrate-bakasu.sh "$KROOT" ./bakasu.config.fragment lsm manual
bash <repo>/scripts/integrate-bbg.sh "$KROOT" ./bbg.config.fragment
PORT=<repo>/patches/kernel/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch
bash <repo>/scripts/integrate-droidspace.sh "$KROOT" "$PORT"

# 3. 合并 defconfig
FRAGS="./bakasu.config.fragment ./bbg.config.fragment <repo>/patches/kernel/droidspace/4.9/droidspace.config"
BASE_DEFCONFIG=arch/arm64/configs/vendor/xiaomi/mi845_defconfig \
DEVICE_FRAGMENTS="arch/arm64/configs/vendor/xiaomi/polaris.config" \
ROOT_MANAGER=bakasu ENABLE_BBG=true ENABLE_DROIDSPACE=true \
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

- susfs：`bakasu-susfs`；各设备落位件由本地管线（`localworkspace/pipelines/`）维护
- Android/data 隔离仅 polaris
- vince 树自带旧 KernelSU：集成前用
  `patches/root-manager/bakasu/device/vince/4.9/0000-remove-legacy-ksu-hooks.patch` 剥离
- Droidspace cgroup 移植补丁在 `cgroup_port` 开启时缺失或 apply 失败即中止构建
- BakaSU 管理器（Manager APK）版本需自行匹配；构建从固定提交 checkout
  （BakaSU 取 main、XXKSU 取 fork 固定提交）并按当前仓库接线
- 32 位兼容：`CONFIG_COMPAT=y`，fstat64/fstatat64 hook 在 `0001-fs-stat` 内
- SuSFS `priority_uid_filter` 的内核端口已随 port 保留；BakaSU `7b65bde0` 未提供对应 Kconfig
  和用户态命令，当前功能集不启用这一面
