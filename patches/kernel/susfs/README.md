# patches/kernel/susfs — SuSFS 资产（非 GKI）

SuSFS 资产由三部分构成：

- **功能面**：gki-android12-5.10 上游快照（`50_add_susfs_in_gki-android12-5.10.patch`、
  `fs/susfs.c`、`include/linux/susfs.h`、`include/linux/susfs_def.h`、KernelSU 侧
  `10_enable_susfs_for_ksu.patch`）。功能集基准，当前同步到 `784ac9e6fd`
  （`SUSFS_VERSION "v2.4.0"`）。
- **本树形态**：4.9 上游参考补丁与目标树自身的头文件，决定声明位置、
  `fsnotify_ops.handle_event` 参数表、文件名类型、proc/fdinfo 形态。
- **设备调用点**：九处 `ksu_handle_*` 调用点按目标树生成后固化进设备 port；workflow 只
  做面断言。

## port

新增行数按 diff 的 `+` 行计，不含 `+++` 文件头。

| 路径 | 树 | 规模 | 校验 |
|---|---|---|---|
| `4.9/polaris/susfs-port.patch` | polaris 4.9.337 | 31 文件 / 4598 新增行 | 严格 apply、parity OK、preflight 无静态检出；编译面见 `build-polaris` 的 susfs 模式 |
| `4.9/beryllium/susfs-port.patch` | beryllium 4.9.337 | 31 文件 / 4637 新增行 | 同上；设备属性段为 `security/selinux/avc.c` 与 `ss/services.c`，编译面见 `build-beryllium` |
| `4.9/daisy/susfs-port.patch` | daisy 4.9.337 | 31 文件 / 4598 新增行 | 同上；设备属性段为 `fs/proc/cmdline.c` 与 `ss/services.c`，编译面见 `build-daisy` |
| `4.9/vince/susfs-port.patch` | vince 4.9.337 | 31 文件 / 4620 新增行 | 同上；`fs/proc/cmdline.c` 用 vince 变体，编译面见 `build-vince` |

`security/selinux` 的 sus context→sid / compute_av 面按树内形态落地：4.9 树用全局
`policydb`/`sidtab`/`policy_rwlock`。4.9 port 在 `security/selinux/hooks.c` 保留
`ksu_selinux_hide_running` 声明，BakaSU 的 `susfs_compat.mk` 据此导出 selinux-hide 符号。
`setprocattr` 仅在 app 的 `current` 属性且 selinux-hide 正在运行时进入 SuSFS，否则回退原始
SELinux 实现。PID 1 preinit 失败路径在 4.9 的 exec 形态中修正：handler 位于失败分支之前，
runner 返回 `ENOEXEC` 时清理本次 bprm 并重试原始 `/system/bin/init`。`priority_uid_filter`
的 cred 切换 helper 仅在对应 Kconfig 开启时编译，未开启时不产生 unused function；`v2.4.0`
的 `sus_path` uid filter 复用同一 helper，port 的守卫写成
`PRIORITY_UID_FILTER || SUS_PATH`。AVC 日志 spoof 分支在 `security_sid_to_context()` 成功后
释放临时 context；SUS_TYPE / SUS_AVD 的命中日志使用 ratelimit 版本。`fs/statfs.c` 与
`fs/susfs.c` 取目标树的 `handle_event`（不带 mark 参数）与 `const unsigned char *` 文件名形态。

功能集基准 `v2.4.0` 的 `sus_path` uid filter 面携带：`fs/susfs.c` 的 uid bitmap
（`SUSFS_UID_FILTER_MIN_UID..MAX_UID`）、应用串解析与 `susfs_sus_path_app_strings` 守护线程
重算，`CMD_SUSFS_SET_SUS_PATH_UID_FILTER` 由 BakaSU 侧命令面传入。stateful 树的
`inode_setxattr` / `inode_post_setxattr` 路由面在 4.9 非 stateful 树形上没有落点
（beryllium、vince 的树自带 `struct selinux_state`，该两面尚未随 port 落地，见
`localworkspace/pending.json`）。应用安装在 `/data/system/packages.list` 变更后由 BakaSU 的
throne 追踪路径触发重算
（`patches/root-manager/bakasu/checkout/0102-susfs-sus-path-uid-filter-renew.patch`）。

readdir hook 站点经 `susfs_get_data_path()` 解析 `/data`，该 helper 由 `translate.sh` 随核心
文件落地；`fs/statfs.c` 的 `statfs_by_dentry_wrapper` / `calculate_f_flags_wrapper` 随 port
落地。

`b0e47464` 新增的 `priority_uid_filter` 面按 4.9 形态携带（`block/ioprio.c`、`kernel/sys.c`
的守卫块；4.9 用 `vzalloc` 与偏移式 `kernel_read`）；该面的 Kconfig 与命令由 BakaSU 侧
提供，其未定义该符号时这一面不参与编译。

## 上游跟踪

上游 gki-android12-5.10 更新（`SUSFS_VERSION`、`susfs.c`、assembled patch）时：

1. 刷新素材快照并跑 parity 对照函数清单、函数体规模与调用点覆盖
   （本机工具 `localworkspace/maintain/sync-susfs-510.sh`、
   `verify-susfs-parity.sh`；不随仓库分发，仓库内不做网络获取）。
2. 四台由 `localworkspace/pipelines/susfs-k4.9/run.sh <device> <tree> --install`
   重放：translate → drift 判定（`vendor/judgements.json`）→ 与 reference 逐字节核对 →
   重复定义与调用点门 → 安装。
3. 提交后由对应设备 workflow 的 susfs 模式编译验证。
