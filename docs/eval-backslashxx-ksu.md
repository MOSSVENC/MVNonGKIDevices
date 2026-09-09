# Backslashxx/KernelSU fork 评估与集成方案

审查对象：https://github.com/backslashxx/KernelSU（master = v3.3.0-26，
upstream KernelSU v3.3.0 深度衍生；代码与本仓库 sparse 快照
localworkspace/kernels/backslashxx-ksu 一致）。

## 1. 审查结论

### 1.1 fork 有类似 auto-hook 的机制——四层 hook 引擎

fork 的 `kernel/hook/` 提供四套可独立/组合的 hook 层（Kconfig 单选互斥对）：

| 选项 | 机制 | 适用范围（fork Kconfig 原文） |
|---|---|---|
| `KSU_KPROBES_KSUD` | 早期启动用 kprobes 动态 hook，boot complete 后注销 | 官方 non-GKI 路径的自动模式（官方指南推荐 kprobe） |
| `KSU_HACK_ARM64_BRANCH_LINK` | 扫描内核文本改写调用点 `bl` 指令直跳 hook（仿 ARM64 optprobe，免 trampoline/CFI） | 3.10~7.1 验证，**推荐 4.19+** |
| `KSU_TAMPER_SYSCALL_TABLE` | **篡改 sys_call_table**（zx2c4 kernel-assisted-superuser 手法）替换 syscall 入口 | 3.0~7.1 验证，**推荐 3.0~4.14**；直调无 blr 开销、兼容 Clang CFI |
| `KSU_LSM_SECURITY_HOOKS` | LSM security hooks（默认 y；`lsm_hooks_{static,manual,ultralegacy,list}.c` 按内核 LSM 结构分代落位） | 对应 ReSukiSU "LSM AUTO" 的同类物，覆盖更宽 |

对照：ReSukiSU 的 manual-hook AUTO 机制 = LSM 自动（setuid/initrc/input
AUTO_*）。fork 的 `KSU_LSM_SECURITY_HOOKS` + `setuid_hook.c` + selinux_hide
的 `ksu_input_hook` 覆盖同职责。

### 1.2 "tamper syscall hook 兼容很简单"——属实（机制级），且点名老内核

`kernel/hook/syscall_table_hook_arm64.c`（+ arm 版）：
- 替换入口：reboot / execve / execveat / faccessat / newfstatat /
  newfstat / read（AArch64 与 EABI compat 表各一套）
- hook 函数内直接调用 `ksu_handle_sys_reboot/execveat/...` 后回原实现
  ——**与树内注入调用点同语义，但调用点收敛到 KSU 侧**，目标树无需打
  manual-hook 源码补丁（4.14 上的 ReSukiSU 414 补丁注入可整块省掉）
- fork Kconfig 自述 verified 3.0~7.1、推荐 3.0~4.14 —— 正覆盖我们
  的 4.9/4.14 老内核面

### 1.3 与 susfs 组合的符号适配点（不可直接替换）

susfs（simonpunk 官方/ReSukiSU 链）对 KernelSU 侧符号的假设与 fork 未对齐：

| susfs 期待（素材/注入器） | fork 实际 | 适配 |
|---|---|---|
| `extern struct static_key_true ksu_su_compat_enabled` | `static bool` + accessor（sucompat.c） | 需要适配层或改用其 accessor |
| `ksu_handle_sys_read(fd, &buf, &count)`（initrc，3 参） | read hook 调 `ksu_handle_sys_read_fd(fd)` | read/initrc 相关段重接 |
| selinux hide 交互符号（fake_status 系） | fork 自有 `ksu_selinux_*` 实现（不同符号面） | susfs 的 selinux hide 段需要落位适配 |
| `ksu_handle_execveat_sucompat`（susfs sucompat 分支） | sucompat.c 有老签名 `ksu_handle_execveat`（filename**） | 需确认调用语义对应 |
| fork 无内置 SUSFS Kconfig | susfs 内核侧补丁自供 | susfs-port.patch 不打 KernelSU 目录（已核 0 处），Kconfig 面 OK |

结论：**tamper hook 单独用（KSU 原生，无 susfs）在 4.14 上机制简单；
与 susfs 组合需要一层符号适配**，不是开箱直插。

## 2. 集成方案（加入本仓库 action 构建）

### 2.1 新增 workflow_dispatch 输入（全部 6 workflow 统一加）
```
ksu_source:            # choice: resukisu (default) | backslashxx
  description: KernelSU 内核来源：resukisu（ReSukiSU main）| backslashxx（fork v3.3.0-26，含 syscall-table/branch-link hook 引擎）
```
env 推导 `KSU_SOURCE`；susfs/manual 集成步骤按 `KSU_SOURCE` 分支。

### 2.2 backslashxx 分支集成步骤（替换现有 ReSukiSU setup 调用）
```
- clone Backslashxx/KernelSU@master → KernelSU/（深度 1）
- ln -s KernelSU/kernel drivers/kernelsu + drivers/Kconfig/Makefile 注入
  （同 ReSukiSU setup.sh 的布线方式，改成指向 fork）
- hook 引擎选择由 defconfig fragment 表达：
    4.9/4.14 目标：CONFIG_KSU_TAMPER_SYSCALL_TABLE=y
    4.19 目标：   CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y
  （两者 Kconfig 互斥；KSU_KPROBES_KSUD 默认 n 可选）
- 跳过 inline-hook 生成器（fork hook 引擎代调 ksu_handle_*）
```

### 2.3 merge-defconfig 断言分支
`merge-defconfig.sh` 按 `KSU_SOURCE` 加断言面：
- resukisu：现有链不变（KALLSYMS_ALL + KSU/KSU_MANUAL_HOOK/AUTO）
- backslashxx：`CONFIG_KSU=y` + `CONFIG_KSU_TAMPER_SYSCALL_TABLE=y`
  （4.9/4.14）或 `KSU_HACK_ARM64_BRANCH_LINK=y`（4.19）+ LSM hooks 默认；
  ReSukiSU 专属符号断言（KSU_MANUAL_HOOK 等）在 backslashxx 面跳过

### 2.4 实施顺序（每个阶段以 CI 编译实测为准）
1. **阶段 A：fork 原生验证**（不加 susfs）：RMX2117（4.14，
   tamper）与 alioth（4.19，branch-link）各跑一次
   `ksu_source=backslashxx` + `hook_mode=none` 面 → 编译通过 = fork 树
   在 MTK/LOS 树可构建（vendor verified 声明不代替实测）
2. **阶段 B：fork + susfs 组合**（RMX2117 4.14 优先）：在 A 的基线上
   叠加 susfs-port.patch + KSU_SUSFS 片段 → 用编译错误清单驱动符号
   适配层（1.3 表），收敛后 CI 绿
3. 阶段 C（可选）：4.9 系设备同法扩展；行为/刷机验证另计（本方案
   只到 CI 编译级）

### 2.5 风险与证据级别
- fork Kconfig/文档的 "verified 3.0~7.1" 是维护者声明（静态证据）；
  本仓库集成只宣称 CI 编译结果（真实工具执行级），不宣称运行可用
- tamper 模式直接改 sys_call_table：CFI 兼容按 fork 文档；SELinux
  策略/审计面行为差异需真机阶段验证（阶段 C 后）
- 分支稳定性：fork master 高频演进（staging-* 研究分支多），集成时
  锁 tag（v3.3.0-26）而非 master

## 3. 网络与外部证据
- DeepWiki 对该 fork 的自动文档（
  deepwiki.com/backslashxx/KernelSU，1.2 Non-GKI Device Support、
  2.1 Kernel Initialization & LSM Hooks）—— 佐证 hook 层结构与
  官方 non-GKI（kprobe/手动）路径的关系
- 上游官方 non-GKI 指南（kernelsu.org 归档）：fork 的 kprobe 路径
  沿官方；syscall-table/branch-link 为其 downstream 扩展
- 第三方跟进 fork：col83/backslashxx-KernelSU（arm32/arm64 打包镜像）
  表明社区使用面存在（非我们实测依据）

## 4. 落地状态（mix2s）

- build-polaris.yml 增加 `root_manager`（none/resukisu/xxksu）与
  `hook_engine`（syscall_table/branch_link）输入；xxksu 分支锁 fork tag
  v3.3.0-26，fragment 写 CONFIG_KSU=y + KSU_LSM_SECURITY_HOOKS=y + 所选
  引擎；跳过 manual 源码补丁与 inline 注入器（fork 引擎代调
  ksu_handle_*）。susfs 组合在 xxksu 分支暂未提供（需符号适配层，见
  上文 1.3）。
- scripts/merge-defconfig.sh 支持 ROOT_MANAGER/ROOT_ENGINE 分支断言
  （缺省按 ENABLE_RESUKISU 推导，其它设备向后兼容）。
- CI 验收：root_manager=xxksu + syscall_table / branch_link 两条路径
  编译通过记录待填（workflow_dispatch 手动触发）。
