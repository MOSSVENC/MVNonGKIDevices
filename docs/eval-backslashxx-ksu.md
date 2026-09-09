# Backslashxx KernelSU fork 评估与集成状态

审查对象：<https://github.com/Backslashxx/KernelSU>（KernelSU 深度衍生，
跟随 master；源码快照见本地 localworkspace/reference/backslashxx-ksu）。

## 1. fork hook 引擎（四层）

fork `kernel/hook/` 提供四套 hook 层（Kconfig 互斥或常开）：

| 选项 | 机制 | 适用范围（fork Kconfig 原文） |
|---|---|---|
| `KSU_KPROBES_KSUD` | 早期启动 kprobes 动态 hook，boot complete 后注销 | 官方 non-GKI 路径的自动模式（官方指南推荐 kprobe） |
| `KSU_HACK_ARM64_BRANCH_LINK` | 扫描内核文本改写调用点 `bl` 指令直跳 hook（仿 ARM64 optprobe，免 trampoline/CFI） | 3.10~7.1 验证，推荐 4.19+ |
| `KSU_TAMPER_SYSCALL_TABLE` | 篡改 sys_call_table（zx2c4 kernel-assisted-superuser 手法）替换 syscall 入口 | 3.0~7.1 验证，推荐 3.0~4.14；直调无 blr 开销、兼容 Clang CFI |
| `KSU_LSM_SECURITY_HOOKS` | LSM security hooks（默认 y；按内核 LSM 结构分代落位） | 对应 ReSukiSU "LSM AUTO" 的同类物，覆盖更宽 |

tamper 的替换入口：reboot / execve / execveat / faccessat / newfstatat /
newfstat / read（AArch64 与 EABI compat 表各一套）。hook 函数内直接调用
`ksu_handle_*` 后回原实现——调用点收敛到 KSU 侧，目标树无需打
manual-hook 源码补丁。

## 2. 与 susfs 组合的符号适配

susfs（simonpunk 官方/ReSukiSU 链）对 KernelSU 侧符号的假设与 fork
未对齐，不能直接替换：

| susfs 期待 | fork 实际 | 适配 |
|---|---|---|
| `extern struct static_key_true ksu_su_compat_enabled` | `static bool` + accessor | 适配层或改用 accessor |
| `ksu_handle_sys_read(fd, &buf, &count)`（3 参） | read hook 用 `ksu_handle_sys_read_fd(fd)` | read/initrc 面重接 |
| selinux hide 交互符号（fake_status 系） | fork 自有 `ksu_selinux_*` 实现 | susfs selinux hide 段落位适配 |
| `ksu_handle_execveat_sucompat` | sucompat 有老签名 `ksu_handle_execveat` | 按官方 10_enable 分派段并入 |
| SUSFS Kconfig | fork 无内置 | susfs-port.patch 不打 KernelSU 目录（已核 0 处），Kconfig 面 OK |

适配路线以官方 `10_enable_susfs_for_ksu.patch`（gki-android12-5.10）为
蓝本、KernelSU-Next legacy-susfs 为老树参考；逐文件映射与实施建议见
本地草案 localworkspace/reference/xxksu-susfs-plan.md。

## 3. 集成形态（当前实现）

- 输入：`root_mode` 值 `xxksu-syscall_table` / `xxksu-branch_link`
  （六设备一致，默认 resukisu-manual-lsm）
- 集成：clone fork **master**（跟随上游，不锁 tag）→
  `drivers/kernelsu` 布线 → fragment（`CONFIG_KSU=y` +
  `KSU_LSM_SECURITY_HOOKS=y` + 所选引擎互斥位）
- 断言：`merge-defconfig.sh` 按 ROOT_MANAGER/ROOT_ENGINE 分支
  （xxksu 面校验 KSU + LSM + 引擎，不跑 ReSukiSU 专属符号断言）
- 刷机展示：AK3 kernel.string 经 `scripts/ak3-display.py` 输出
  `XXKSU SYSCALL-TABLE-HOOK` / `XXKSU BRANCH-LINK-HOOK`

## 4. 验证状态

- polaris（4.9）：xxksu 两引擎各一次 CI 编译通过（config 断言 +
  编译 + 链接产物完整）；merge 断言行双向校验引擎互斥
- 其它设备：接入同模板，编译验证随 workflow_dispatch 触发
- 运行级（dmesg hook 安装日志 / 刷机行为）：待真机

## 5. 风险与证据级别

- fork Kconfig/文档的 "verified 3.0~7.1" 是维护者声明（静态证据）；
  仓库集成只表述 CI 编译结果（真实工具执行级），不表述运行可用
- fork master 高频演进（staging-* 研究分支多）：跟随 master 的构建在
  每次升级时核对 hook 面与符号差异
- tamper 直接改 sys_call_table：CFI 兼容按 fork 文档；SELinux 策略/
  审计面差异需真机阶段验证

## 6. 外部证据

- DeepWiki 对该 fork 的自动文档（Non-GKI Device Support、Kernel
  Initialization & LSM Hooks 章节）：佐证 hook 层结构与官方 non-GKI
  路径的关系
- 上游官方 non-GKI 指南（kernelsu.org 归档）：fork 的 kprobe 路径沿
  官方；syscall-table / branch-link 为其 downstream 扩展
- 第三方跟进 fork（col83/backslashxx-KernelSU 打包镜像）：社区使用面
  存在（非本项目实测依据）
