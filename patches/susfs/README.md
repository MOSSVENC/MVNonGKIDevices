# patches/susfs — SuSFS 资产（非 GKI）

SuSFS 资产由三部分构成：

- **功能面**：gki-android12-5.10 上游快照（`50_add_susfs_in_gki-android12-5.10.patch`、
  `fs/susfs.c`、`include/linux/susfs.h`、`include/linux/susfs_def.h`、KernelSU 侧
  `10_enable_susfs_for_ksu.patch`）。功能集基准，当前同步到 `b0e474642c`
  （`SUSFS_VERSION "v2.3.0"`）。
- **各版本形态**：内核版本参考补丁（4.4 / 4.9 / 4.14 / 4.19 / 5.4 各一份）与目标树自身
  的头文件，决定声明位置、`fsnotify_ops.handle_event` 参数表、文件名类型、proc/fdinfo
  形态。
- **设备调用点**：九处 `ksu_handle_*` 调用点按目标树生成后固化进设备 port；workflow 只
  做面断言。

## port

新增行数按 diff 的 `+` 行计，不含 `+++` 文件头。

| 路径 | 树 | 规模 | 校验 |
|---|---|---|---|
| `4.9/susfs-port.patch` | polaris 4.9.337 | 31 文件 / 4775 新增行 | 严格 apply、parity OK、preflight 无静态检出；编译面见 `build-polaris` 的 susfs 模式 |
| `4.9/beryllium/susfs-port.patch` | beryllium 4.9.337 | 31 文件 / 4814 新增行 | 同上；设备属性段为 `security/selinux/avc.c` 与 `ss/services.c`，编译面见 `build-beryllium` |
| `4.9/daisy/susfs-port.patch` | daisy 4.9.337 | 31 文件 / 4776 新增行 | 同上；设备属性段为 `fs/proc/cmdline.c` 与 `ss/services.c`，编译面见 `build-daisy` |
| `4.9/vince/susfs-port.patch` | vince 4.9.337 | 31 文件 / 4797 新增行 | 同上；`fs/proc/cmdline.c` 用 vince 变体，编译面见 `build-vince` |
| `4.14/susfs-port.patch` | RMX2117 MTK 4.14.186 | 30 文件 / 4822 新增行 | 严格 apply、parity OK、preflight 无静态检出；编译面见 `build-RMX2117` 的 susfs 模式 |
| `4.19/susfs-port.patch` | alioth kona 4.19.325 | 30 文件 / 4794 新增行 | 同上，编译面见 `build-alioth` |

`security/selinux` 的 sus context→sid / compute_av 面按树内形态落地：无
`struct selinux_state` 的 4.9 树用全局 `policydb`/`sidtab`/`policy_rwlock`，带 state 的树
取 `state->ss`（4.14/4.19 与 beryllium/vince）。4.9 port 在 `security/selinux/hooks.c`
保留 `ksu_selinux_hide_running` 声明，BakaSU 的 `susfs_compat.mk` 据此导出
selinux-hide 符号。`setprocattr` 仅在 app 的 `current` 属性且 selinux-hide 正在运行时进入 SuSFS，否则回退原始 SELinux 实现。`priority_uid_filter` 的 cred 切换 helper 仅在对应 Kconfig 开启时编译，未开启时不产生 unused function。`fs/statfs.c` 与 `fs/susfs.c` 取目标树的
内核形态（4.19 的 `handle_event` 不带 mark 参数；文件名类型按树为 `const unsigned char *`
或 qstr）。

`b0e47464` 新增的 `priority_uid_filter` 面按 4.9/4.14 形态携带（`block/ioprio.c`、
`kernel/sys.c` 的守卫块；4.9 用 `vzalloc` 与偏移式 `kernel_read`）；该面的 Kconfig 与命令
由 BakaSU 侧提供，其未定义该符号时这一面不参与编译。

## 上游跟踪

上游 gki-android12-5.10 更新（`SUSFS_VERSION`、`susfs.c`、assembled patch）时：

1. 刷新素材快照并跑 parity 对照函数清单、函数体规模与调用点覆盖
   （本机工具 `localworkspace/maintain/sync-susfs-510.sh`、
   `verify-susfs-parity.sh`；不随仓库分发，仓库内不做网络获取）。
2. 4.9 四台由 `localworkspace/pipelines/susfs-k4.9/run.sh <device> <tree> --install`
   重放：translate → drift 判定（`vendor/judgements.json`）→ 与 reference 逐字节核对 →
   重复定义与调用点门 → 安装。
3. 4.14/4.19 由
   `localworkspace/maintain/derive-susfs-port.sh <device> <4.14|4.19> <tree> --install`
   重派生：版本参考基底（`localworkspace/mirrors/NonGKI_Kernel_Build_2nd/Patches/Patch/`）
   → 树锚定段 → 调用点 → `preflight-port.py` 静态门 → 安装。
4. 提交后由对应设备 workflow 的 susfs 模式编译验证。
