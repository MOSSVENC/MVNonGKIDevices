# MVNonGKIDevices — Android 内核 Action 仓库（补丁 + 构建编排）

构建脚本 / 补丁 / 配置片段在本仓库维护，内核源码按设备固定在外部
仓库（下表），由 GitHub Actions 检出后按特性开关集成并编译。

## 支持设备（4.9 / 4.14 / 4.19，arm64）

| 设备 | 代号 | 内核 | 内核源 / 分支 | workflow |
|---|---|---|---|---|
| Xiaomi Mi Mix 2S | `polaris` (sdm845) | 4.9.337 | [MOSSVENC/android_kernel_xiaomi_sdm845](https://github.com/MOSSVENC/android_kernel_xiaomi_sdm845) @ `lineage-22.2` | `build-polaris.yml` |
| Xiaomi Pocophone F1 | `beryllium` (sdm845) | 4.9.337 | [Flyme66/kernel_xiaomi_sdm845_tejas101k_beryllium](https://github.com/Flyme66/kernel_xiaomi_sdm845_tejas101k_beryllium) @ `thirteen` | `build-beryllium.yml` |
| Xiaomi Mi A2 Lite | `daisy` (msm8953) | 4.9.337 | [Flyme66/android_kernel_xiaomi_msm8953_ItsVixano_daisy](https://github.com/Flyme66/android_kernel_xiaomi_msm8953_ItsVixano_daisy) @ `lineage-20` | `build-daisy.yml` |
| Xiaomi Redmi Note 5 | `vince` (msm8953) | 4.9.337 | [Flyme66/kernel_xiaomi_OctaviOS_vince](https://github.com/Flyme66/kernel_xiaomi_OctaviOS_vince) @ `13` | `build-vince.yml` |
| Xiaomi Redmi K40 / POCO F3 | `alioth` (sm8250) | 4.19.325 | [MOSSVENC/android_kernel_xiaomi_sm8250](https://github.com/MOSSVENC/android_kernel_xiaomi_sm8250) @ `lineage-23.2` | `build-alioth.yml` |
| realme Q2（国行） | `RMX2117` (mt6853) | 4.14.186 | [realme_X7_..._AndroidS-kernel-source](https://github.com/MOSSVENC/realme_X7_X7Pro_X7ProExtreme_X7-5G_Q2Pro_V15_V5_Q2_Narzo30pro-5G_7-5G-AndroidS-kernel-source)（完整名见链接地址） @ `master` | `build-RMX2117.yml` |

workflow_dispatch 输入控制各特性开关（enable_resukisu / enable_bbg /
enable_droidspace / cgroup_port / enable_data_isolation / hook_mode /
auto_fix_49），默认值见各 workflow 的 input 定义。构建只通过
workflow_dispatch 手动触发（无 push 自动触发）。

RMX2117（MTK 4.14）与其它设备的输入编排一致（kernel_ref /
enable_resukisu / enable_bbg / enable_droidspace / hook_mode），
`hook_mode` 默认 manual-lsm；`enable_bbg` / `enable_droidspace` 默认
off；无 cgroup_port / enable_data_isolation / auto_fix_49 项
（MTK 树不适用），差异见下文 "RMX2117（MTK 4.14）" 一节。

## 特性开关（workflow_dispatch 输入）

| 特性 | 输入 | 说明 | 默认 |
|---|---|---|---|
| ReSukiSU | `enable_resukisu` | KernelSU 系 root（manual/auto 见 hook_mode） | on |
| BBG | `enable_bbg` | Baseband-guard 防格机 LSM | on |
| Droidspace | `enable_droidspace` | 容器/LXC/Docker 内核支持 | on |
| Droidspace cgroup 补丁 | `cgroup_port` | 4.9 cgroup noprefix compat 补丁（仅 droidspace 开启时生效） | on |
| Android/data 隔离 | `enable_data_isolation` | sdcardfs per-uid 隔离 `Android/data/<pkg>`：非 owner app lookup/getattr 得 ENOENT | polaris on；beryllium/daisy/vince 固定 off |

### 工具链

所有设备统一用 **AOSP clang 14（clang-r450784d）+ Android GCC 4.9
prebuilts**（aarch64-linux-android-4.9 / arm-linux-androideabi-4.9，作
binutils 用），编译命令：

```bash
make -j$(nproc) O=out ARCH=arm64 \
  CC="clang" \
  CLANG_TRIPLE="aarch64-linux-gnu-" \
  CROSS_COMPILE="<gcc64>/bin/aarch64-linux-android-" \
  CROSS_COMPILE_ARM32="<gcc32>/bin/arm-linux-androideabi-" \
  LD=ld.lld LLVM=1 LLVM_IAS=1
```

参数为 4.9 + clang 的必需组合：`LLVM_IAS=1`（stackprotector cc-option
检测走内置汇编器）、`CROSS_COMPILE_ARM32` 绝对路径前缀（compat vDSO
硬检查）、`LD=ld.lld`（AArch32 vDSO 链接）。

### Android/data 隔离（sdcardfs per-uid ENOENT）

该设备上 `/storage/emulated/0/Android/{data,obb}` 由 sdcardfs 服务：顶层
mask 挡 readdir 枚举，但已知包路径的 stat/open 仍可探测任意已装应用的
`Android/data/<pkg>`。补丁 `patches/sdcardfs/0001-sdcardfs-android-data-isolation.patch`
把 AOSP data-isolation 语义搬进 sdcardfs：
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
manual hook 共 7 类；4 类必须改内核源码，3 类可选。以下补丁清单适用于
`hook_mode: manual-lsm / manual-source`；`hook_mode: auto` 不提供源码补丁，
由 ReSukiSU auto-hook 分支的 inline-hook 引擎替代。

| hook | 内核文件 | 是否必打 | 本仓库做法 |
|---|---|---|---|
| stat | fs/stat.c | 必 | `common/0001` |
| execve | fs/exec.c | 必 | `common/0002` |
| faccessat | fs/open.c | 必 | `common/0003` |
| sys_reboot | kernel/reboot.c | 必 | `common/0004`（polaris/beryllium）；`{daisy,vince}/0004` 变体（树里 reboot.c 上下文不同） |
| input | drivers/input/input.c | 可选 | `manual-lsm` → input_handler AUTO；`manual-source` → `alt-hooks/0010` |
| setuid | kernel/sys.c | 可选 | `manual-lsm` → LSM AUTO；`manual-source` → `alt-hooks/0011` |
| sys_read(initrc) | fs/read_write.c | 可选 | `manual-lsm` → LSM AUTO；`manual-source` → `alt-hooks/0012` |

workflow_dispatch 的 `hook_mode` 选择控制集成方式（默认 manual-lsm）。
4.9 设备用 `patches/resukisu/4.9/`（daisy/vince 换用其 `daisy`/`vince`
设备子目录的 0004 变体）；alioth（4.19）用 `patches/resukisu/4.19/`；
RMX2117（4.14）用 `patches/resukisu/4.14/`（树区域相同者以单一真身
存 `4.9/`，workflow 文件级清单跨目录引用）：
- `manual-lsm`（默认）—— 源码补丁 + 3 个可选 hook 由 ReSukiSU 的
  LSM / input_handler AUTO 机制接管（fragment 置 `CONFIG_KSU_MANUAL_HOOK_AUTO_*=y`，
  < 6.8 适用）。
- `manual-source` —— 源码补丁 + 打可选 3 hook 源码补丁
  （各版本目录内 `0010~0012`），fragment 关掉三个 AUTO。
- `auto` —— ReSukiSU **auto-hook 分支**：hook 由运行时 inline-hook 引擎完成；
  `auto_fix_49`（默认开）修正 auto-hook 分支对 4.x 的 `kasan_reset_tag` 门槛。
- `susfs` —— SuSFS inline hook（全部设备）：polaris 应用 shipped 模块
  补丁（`patches/test/susfs-shipped-4.9/0001-0004`，重建产物可经维护
  切换）；beryllium/daisy/vince 应用
  `patches/susfs/4.9/<设备>/susfs-port.patch`；alioth 应用
  `patches/susfs/4.19/susfs-port.patch`；RMX2117 应用
  `patches/susfs/4.14/susfs-port.patch`。编译产物见各设备 workflow
  susfs 日志。

### 静态符号

selinux 静态符号由 `CONFIG_KALLSYMS_ALL=y` 的 kallsyms 查表解析（合并阶段无条件强制）。

## 最终 .config 合并顺序

`merge-defconfig.sh` 拼接各层后去重（同名项后者胜出），再
`make KCONFIG_ALLCONFIG=<allconfig> alldefconfig` + `olddefconfig`：

```
<BASE_DEFCONFIG>                         ← 设备基线（env 指定）
  + <DEVICE_FRAGMENTS>                   ← 机型片段（默认 mi845 + polaris.config）
  + resukisu.config.fragment   [resukisu on] (CONFIG_KSU=y MANUAL_HOOK=y ...)
  + bbg.config.fragment        [bbg on]      (CONFIG_BBG=y)
  + droidspace.config          [droidspace on]
  + 强制覆盖：CC_WERROR off、KALLSYMS(+ALL)=y、CLEAR_LOCALVERSION 可选
  → KCONFIG_ALLCONFIG alldefconfig → olddefconfig → 关键项断言（缺失即失败）
```

顺序要点：resukisu/bbg 的 Kconfig 必须**先**由各自的 `setup.sh` 挂进内核
Kconfig 树，再执行合并，否则 `olddefconfig` 看不到新符号会静默丢弃；
所以管线固定为 打补丁 → 跑 setup → 合并 → 断言 → 编译。

基线差异：polaris 用 `vendor/xiaomi/mi845_defconfig`（LOS 官方）+ polaris.config；
beryllium 用自带 `beryllium_defconfig`（自包含，`CLEAR_LOCALVERSION=true` 清
`-Helios™`）；daisy 用 `msm8953-perf_defconfig`（xiaomi/daisy.config 各项均在基线内）；vince 用 `vince-perf_defconfig`（自包含）。

## 目录结构

```
patches/
  droidspace/
    upstream/                 官方 non-GKI 补丁唯一副本（0001 xt_qtaguid / 0002 cgroup 前缀）
    4.9/ 4.14/ 4.19/          各内核版本 droidspace.config（符号差异按版本）
  resukisu/
    upstream/manualhook/      ReSukiSU 文档网页原文摘录（.md 参考；hook 目录 + 版本五级目录
                              3.14±/4.17±/4.19±；含弃置 execve 接法；X 占位行号为文档示意）
    4.9/                     4.9 树适配 manual hook（0001-0004 必加 + 0010-0012 可选）
       daisy/ vince/         设备专属 0004-reboot 变体 + vince 旧 KernelSU 埋点清理补丁
    4.14/ 4.19/              4.14/4.19 树适配（stat/exec/reboot/input 等树区域相同者
                              单一真身存 4.9/，workflow 以文件级清单跨目录引用）
  susfs/
    upstream/                gki-android12-5.10 上游素材（50_add/10_enable/susfs.c/.h 唯一副本）
    4.9/                     susfs-port.patch + ber/daisy/vince 设备子目录（4.9 树适配）
    4.14/ 4.19/              各树适配补丁（CI susfs 编译通过）
  （inline-hook 生成器为脚本，见 scripts/）
  bbg/                       集成说明（无本地补丁，跑官方 setup.sh）
  test/
    susfs-shipped-4.9/       shipped 旧移植归档（0001-0004 模块、polaris-susfs-final、susfs_patch_to_4.9）
  sdcardfs/                  Android/data per-uid 隔离补丁（仅 polaris 启用）
  alioth/                    min-tool-version.sh（构建辅助，注入 4.19 树）
localworkspace/              本机工作区（gitignored）：kernels/ 基线树、pipelines/ susfs 重建管线
                            （susfs-k4.9/4.14/4.19）、firmware/rmx2117-f12/ 固件、rmx2117/ 工程区、
                            maintain/ 维护工具、reference/ 资料（布局见 localworkspace/README）
scripts/                      编排脚本（见下）
.github/workflows/build-<代号>.yml     每设备 CI
```
## 手动复现

以 polaris 为例（其他设备换 clone 源/分支/defconfig，见各 workflow）：

```bash
KROOT=/path/to/kernel-clone   # git clone -b lineage-22.2 .../android_kernel_xiaomi_sdm845

# 1. ReSukiSU manual hook 源码补丁（daisy/vince 用各自设备目录的 0004 变体；
#    hook_mode=auto 时跳过本步）
bash scripts/apply-patches.sh "$KROOT" \
  patches/resukisu/4.9                        # polaris/beryllium
# daisy/vince: 传 4.9 目录 0001-0003 单文件 + <dev>/0004

# 2. 集成 ReSukiSU / BBG / Droidspace
# manual 模式（main 分支 + 源码补丁；hook_mode=manual-lsm / manual-source）
bash scripts/integrate-resukisu.sh "$KROOT" ./resukisu.config.fragment lsm manual true
# auto 模式（auto-hook 分支 + inline hook；跳过第 1 步源码补丁）
# bash scripts/integrate-resukisu.sh "$KROOT" ./resukisu.config.fragment lsm auto true
bash scripts/integrate-bbg.sh "$KROOT" ./bbg.config.fragment
PORT=patches/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch
bash scripts/integrate-droidspace.sh "$KROOT" "$PORT"

# 3. 合并 defconfig（基线/片段可用 env 覆盖，见下）
FRAGS="./resukisu.config.fragment ./bbg.config.fragment patches/droidspace/4.9/droidspace.config"
BASE_DEFCONFIG=arch/arm64/configs/vendor/xiaomi/mi845_defconfig \
DEVICE_FRAGMENTS="arch/arm64/configs/vendor/xiaomi/polaris.config" \
CLEAR_LOCALVERSION=false \
ENABLE_RESUKISU=true ENABLE_BBG=true ENABLE_DROIDSPACE=true \
  bash scripts/merge-defconfig.sh "$KROOT" /tmp/out $FRAGS

# 4. clang 编译（工具链配方见上）
export PATH="<clang>/bin:<gcc64>/bin:<gcc32>/bin:$PATH"
cd "$KROOT" && git add -A && git commit -qm "patched"   # 去 -dirty（可选）
make -j$(nproc) O=/tmp/out ARCH=arm64 CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=<gcc64>/bin/aarch64-linux-android- \
  CROSS_COMPILE_ARM32=<gcc32>/bin/arm-linux-androideabi- \
  LD=ld.lld LLVM=1 LLVM_IAS=1
# 产物: /tmp/out/arch/arm64/boot/Image.gz-dtb
```

`merge-defconfig.sh` 设备参数：`BASE_DEFCONFIG`（基线）、`DEVICE_FRAGMENTS`
（空格分隔片段，默认 polaris 组合）、`CLEAR_LOCALVERSION=true` 时强制
`CONFIG_LOCALVERSION=""`（beryllium 用，清 `-Helios™`）。KALLSYMS_ALL/
CC_WERROR 的强制与断言见脚本内注释。

## RMX2117（MTK 4.14）

realme Q2 国行（RMX2117，MT6853）走 realme AndroidS 综合源（9 机共用，
4.14.186 MTK）。与骁龙 4.9/4.19 设备的差异：

- **工具链**：官方 `build.config.mtk.aarch64` 配方 —— AOSP clang
  r383902（clang 11）+ GCC 4.9 binutils 的 `aarch64-linux-androidkernel-`
  前缀，`LD=ld.lld NM=llvm-nm OBJCOPY=llvm-objcopy`。
- **源树布局**：clone 到 `kernel-4.14/` 目录（oplus 电源头文件经
  `../../../../kernel-4.14/...` 相对路径引用 tcpm.h，依赖该目录名）。
- **defconfig**：`k6853v1_64_6360_defconfig` 为单项目基线（含
  CONFIG_ARCH_MTK_PROJECT / appended-dtb / mt6360 PMIC 集），经
  merge-defconfig.sh 合并 susfs fragment 并强制
  DEBUG_KERNEL/KALLSYMS/KALLSYMS_ALL 链（ReSukiSU 静态符号走 kallsyms
  表）。
- **特性**：susfs（ReSukiSU main + `patches/susfs/4.14/susfs-port.patch`
  树适配补丁 + inline-hook 生成器），编译产物见 build-RMX2117.yml 日志；
  BBG 走 integrate-bbg.sh 官方
  setup.sh（pre-5.1 无 DEFINE_LSM 路径，自动 patch security/selinux）；
  Droidspace 用 `patches/droidspace/4.14/`（官方 0002 补丁对 MTK
  cgroup.c 直接可应用 + 4.14 修正 config）。Android/data 隔离不适用
  （sdcardfs 隔离补丁是 mix2s 范围的特性）。
- **产物**：`Image` + `mt6853.dtb`（boot 内 base dtb）。dtbo 分区
  overlay 内容沿用设备 stock 固件（源树不含项目 cust/overlay 层：
  oplus6853_*.dts、k6853v1_64_6360/cust.dtsi）。boot 链为 boot 内 base
  dtb + 独立 dtbo 分区；只替换 boot 内 kernel、保留原 dtb 与 dtbo 的
  刷法是否可行，属推断（未实机验证）。
- 树内 Kconfig 文件带 CRLF 行尾与大量老代码告警（unused 变量等），
  编译以 warnings-only 进行（-Werror 提升在构建前关闭）。

## 已知取舍 / 边界

- **susfs**：经 hook_mode 的 `susfs` 集成。polaris 以 shipped 移植为
  基准；重建管线（localworkspace/pipelines/susfs-k4.9/）对 polaris 产
  出 susfs-port.patch 重建镜像并对各设备树产出落位件（设备树差异见
  管线 ADAPTATION.md）。
- **Android/data 隔离**：验证于 polaris；beryllium/daisy/vince 固定 off，
  alioth 无 sdcardfs（4.19 kona 树）不适用。
- **alioth（4.19）**：ReSukiSU manual hook 用 `patches/resukisu/4.19`
  （manual-source 时叠加 0010-0012）；droidspace 用
  `patches/droidspace/upstream/` 官方补丁 + `4.19/` config；susfs 走
  `hook_mode=susfs` 应用 `patches/susfs/4.19/susfs-port.patch`
  （4.19 树适配）。产物为 `Image` + `dtbo.img`（boot header v3、dtbo
  独立分区），AnyKernel3 按 slot 设备打包。
- **RMX2117（4.14 MTK）**：susfs 走 `hook_mode=susfs` 应用
  `patches/susfs/4.14/susfs-port.patch`（4.14 树适配，编译产物见
  build-RMX2117.yml 日志）；dtbo 分区内容沿用 stock 固件（源树不含项目 cust/overlay
  层），产物为 `Image` + `mt6853.dtb`。BBG/Droidspace 集成入口已接
  入 workflow（默认 off），其 selinux/cgroup 落位见对应 patches
  目录 README。
- **vince 旧 KernelSU**：workflow 剥离树自带旧 KSU 后集成 ReSukiSU；上游若更新旧
  KSU 代码，`patches/resukisu/4.9/vince/0000-remove-legacy-ksu-hooks.patch` 需同步重新生成。
- **Droidspace cgroup 移植补丁**：非致命；apply 失败自动跳过（见
  patches/droidspace/4.9/README.md）。
- ReSukiSU 与管理器（Manager APK）版本需自行匹配；setup.sh 按 hook_mode
  拉取：manual 用 `main` 分支，auto 用 `auto-hook` 分支（实验性，4.x 需
  `auto_fix_49`，见上）。
- 32 位兼容：`CONFIG_COMPAT=y`，`fstat64/fstatat64` 的 hook 已包含在 0001。
