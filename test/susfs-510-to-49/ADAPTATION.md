# test 面向 gki-5.10 的 4.9 移植：产出机制与设备参考

## 角色

- `translate.sh` 在干净 stock-4.9（polaris 基线）上重建 SuSFS 4.9 移植，
  产物逐字校验于 `vendor/reference-polaris-susfs-final.patch`。
- `vendor/reference-{polaris-susfs-final,beryllium,daisy,vince}.patch`
  是各设备树上的 4.9 SuSFS 参考（CI `hook_mode=susfs-test` 的应用对象）。
  polaris 参考同时是 translate.sh 的重建校验基准；beryllium/daisy/vince
  参考是维护者在各自设备树上按同一监督原则人工产出，随设备树更新。

## 产出机制（translate.sh，polaris）

1. **core（fs/susfs.c、include/linux/susfs.h、susfs_def.h）**：
   拷贝上游 5.10 文件 → 应用 `inputs/susfs49-adapt.diff` /
   `def49-adapt.diff`（4.9 形态机械变换：AS_FLAGS_* 存 `i_state`、
   fsnotify 回调声明、版本条件头）→ 产出 4.9 core。由脚本独立完成。

2. **VFS/hook 文件**（21 个上游共有文件 + 2 个参考独有文件）：
   `tools/translate49.py` 逐文件处理：
   - 每个上游 hunk 与参考段配对（`tools/anchors/*.json`）；
   - 上游内容与参考**语义一致** → 输出参考内容（4.9 规范格式）。
     参考是"上游内容 + 4.9 格式/结构适配"的已验收结果；
   - 上游内容与参考**语义不一致** → 输出参考内容并上报人工适配
     （上游变化点，人工把新内容适配成 4.9 后更新参考）。

   参考独有文件（4.9 独有 hook 点：`fs/proc/cmdline.c`、
   `security/selinux/ss/services.c`）原样应用。

3. **产物校验**：`git diff` → `out/susfs-49-rebuilt.patch`，与
   `vendor/reference-polaris-susfs-final.patch` 在相同 base 上逐文件
   比对（26 文件 hash 一致）。

## 设备参考构成

四份参考相对各自 CI 树基线生成，段集合随设备树原生状态而定：

| 参考 | 段数 | 相对 polaris 的差异 |
|---|---|---|
| `reference-polaris-susfs-final.patch` | 26 | 基线（LOS lineage-22.2，非 stateful selinux、树无 KSU su 放行块） |
| `susfs-beryllium-test.patch`（4.9 设备落位） | 25 | CI 树（Flyme66 thirteen @333bf83）为 stateful selinux：`avc_dump_query` 签名带 `struct selinux_state *state`，`security_sid_to_context(state, ...)`；avc/hooks 注入按该签名落位。树无原生 KSU su 放行块，hooks.c 段为注入。 |
| `susfs-daisy-test.patch`（4.9 设备落位） | 26 | CI 树（Flyme66 lineage-20）为非 stateful selinux，与 polaris 同签名；`fs/proc/cmdline.c` 基线形态不同，段按树落位。daisy 树 `security/selinux/hooks.c` 的 `check_nnp_nosuid` 原生带 KSU su 放行块（与 polaris 参考注入内容一致），参考的 hooks.c 段与之同内容。 |
| `susfs-vince-test.patch`（4.9 设备落位） | 24 | CI 树（OctaviOS 13，先剥离树自带旧 KernelSU 布线）为 stateful selinux：avc 注入按 stateful 签名落位。树已带 KSU su 放行块（hooks.c），该文件与 services.c 无改动段。 |

说明：

- **stateful selinux**（beryllium/vince）与**非 stateful**（polaris/daisy）
  的差异集中在 `security/selinux/avc.c` / `hooks.c` 的注入落位：函数签名
  带 `struct selinux_state *state` 与锁位于 `state->ss` 内（4.9 后期
  形态），4 参版本锁为文件内 `policy_rwlock`。注入的 SuSFS 段内容
  （extern 声明、spoof 块、bypass 标签、KSU su 放行块）跨树一致，仅
  落位/签名随树形态。
- `security/selinux/ss/services.c` 仅在 polaris 参考中有段（`static`
  `DEFINE_RWLOCK(policy_rwlock)` 导出为全局）；stateful 树锁在
  `struct selinux_ss` 内，services.c 无改动段。
- vince 树自带 KernelSU su 放行块于 `check_nnp_nosuid`，参考不重复
  注入 hooks.c 段；剥离旧 KernelSU 布线由 CI 步骤完成（
  `patches/resukisu/4.9/vince/0000-remove-legacy-ksu-hooks.patch`）。
- daisy 与 polaris 同为非 stateful；daisy 树原生带 KSU su 放行块
  （check_nnp_nosuid 内），参考段集合同 polaris（26 段），其中
  hooks.c 段与树原生块内容一致。

## 能力边界

- core：translate.sh 从上游独立产出（真转换）。
- VFS/hook：translate.sh 重放 polaris 参考（已验收 4.9 形态）并精确
  检测上游语义变化；变化点的 4.9 适配由人工完成。参考中的 4.9 特有
  结构（stat.c 2 参 vfs_getattr_nosec、task_mmu 两段式 show_map_vma、
  readdir 三回调、KSU hook 的 ReSukiSU 语义等）是人工适配成果，无法
  从上游 5.10 自动推导。
- 各设备参考相对各自树的注入差异（stateful 签名、KSU 放行块归属、
  cmdline 基线）为人工落位，translate.sh 不覆盖；设备树上参考的
  可用性以 CI（`hook_mode=susfs-test`）编译为准。
- 上游未变化时 translate.sh 产物与 polaris 参考一致是上述机制的
  必然结果，工具不把它宣称成"从上游独立生成"。

## 验证

- 每个文件产物 apply 到干净 stock-4.9 树（git apply --check）。
- 整树编译经 GitHub Actions `hook_mode=susfs-test`（workflow_dispatch）
  验证（AOSP clang 14 + Android GCC 4.9 prebuilts，配方见仓库根
  README"工具链"）。状态：beryllium 通过；daisy/vince 待验证。
- 上游语义变化点以 MANUAL 上报，人工适配后更新参考再验证。
