# Re:Kernel 特性补丁

来源：Sakion-Team/Re-Kernel（GPL-2.0，github.com/Sakion-Team/Re-Kernel）。
本目录为内核内嵌形态（≤5.4 非 GKI 路线；≥5.10 用其 ko/Magisk 模块，不在本仓库）。

## 原理

墓碑（后台冻结）进程被系统触碰时可能被误杀或卡事务。Re:Kernel 在
内核插桩检测"冻结进程被 binder 事务触碰 / async 满 / 被杀"，经
netlink（unit 22-26 探测、user port 100）上报事件文本
（type=Binder/Signal + pid/uid）给用户态墓碑（官方对接库
Develop/librekernel）。上报前统一过滤：目标非冻结组
（frozen/cgroup_freezing）或与源同 uid 则丢弃。

## 结构（上游素材与树适配分置）

- `upstream/`：上游原味素材镜像（Integrate/rekernel/ 四件，逐字节）。
  上游更新 → 人工替换本目录 → 重新生成 4.9/ 适配补丁。
- `4.9/`：4.9 树适配补丁（mix2s 先行，真实 git apply 校验过）：
  - 0001：新增 drivers/rekernel/（内容与 upstream 同源；4.9 无 proc_ops，
    走 file_operations，无需转换）
  - 0002：drivers/android/binder.c binder_transaction()（target_proc
    建立后按 reply 标志分派 binder_reply_handler /
    binder_trans_handler）+ binder_alloc.c async 空间不足段调
    binder_overflow_handler
  - 0003：kernel/signal.c do_send_sig_info()（SIGKILL/TERM/ABRT/QUIT
    且目标冻结时经 rekernel_report(SIGNAL,...) 上报）
  - 0004（无）：drivers/Kconfig source 与 drivers/Makefile obj 由工作流
    步骤幂等注入（这些文件会被 root 集成先改，补丁 context 会漂移）


调用点仅传参（proc/target 的 pid 与 tsk、oneway、tr）；uid 域与冻结
判定集中在 drivers/rekernel/rekernel.c（rekernel_report 统一过滤）。

## 接入（build-polaris.yml）

`enable_rekernel`（默认 off）：apply 4.9/0001-0003 + tree Kconfig/Makefile wiring (idempotent sed in the workflow step) + fragment
`CONFIG_REKERNEL=y`（`# CONFIG_REKERNEL_NETWORK is not set`——接收
解冻面默认关）；merge 断言 REKERNEL=y。

## 边界

- 4.9 树 API 核对：frozen()/freezing 原生、binder_alloc.c 分离、
  file_operations（无 proc_ops）。
- JOBCTL_TRAP_FREEZE：4.9 树无此宏，`jobctl_frozen()` 在
  `#ifdef JOBCTL_TRAP_FREEZE` 兜底（预 freezer-v2 树退化为
  `cgroup_freezing()` 判定），已在 0001 内处理。
- 用户态墓碑与 librekernel 对接不在本仓库（引上游 Develop/）。
- 其余设备同法接入：4.9 系同树族共用本补丁；树差异再适配。
