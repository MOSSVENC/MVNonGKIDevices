# 4.14 SuSFS 移植候选（test 区，面向 realme MTK 4.14.186 树）

目标：把 SuSFS（上游 gki-android12-5.10 素材，仓库
`patches/susfs/upstream/`）移植到 realme MTK AndroidS 综合源
（`MOSSVENC/realme_...AndroidS-kernel-source`，4.14.186）并最终经 CI
编译验证。落位骨架采用 simonpunk non-GKI 补丁家族的 4.14 版
（JackA1ltman/NonGKI_Kernel_Build_2nd@mainline
`Patches/Patch/susfs_patch_to_4.14.patch`，本目录
`vendor/reference-414-mainline.patch`）。

## 组成

- `vendor/reference-414-mainline.patch` — non-GKI 4.14 落位参考
  （mainline 4.14 树形态，19 文件）。
- `susfs-414-test.patch` — 对 realme MTK 4.14.186 树适配后的候选补丁
  （19 文件；CI 应用对象）。
  - core（fs/susfs.c、include/linux/susfs.h、susfs_def.h）：与 4.9
    shipped（`patches/test/susfs-shipped-4.9/0001-*`）逐字一致（1491/241/210 行
    全等）——同一份版本条件适配 core（AS_FLAGS_* 存 `i_state`
    高位、按 LINUX_VERSION_CODE 分派），4.14 落于通用分支，直接
    沿用；
  - 落位文件：15 个文件（Makefile/namei/proc base/cmdline/fd/
    proc_namespace/readdir/stat/statfs/kallsyms/sys/avc 等）沿用
    reference 对 mainline 4.14 的排布，对 MTK 树可直接应用（真实
    `git apply` 验证，仅行号偏移）；
  - 4 个文件按 MTK 树形态适配：
    - `fs/namespace.c`：h0 锚点含 OPLUS 安全宏段（CONFIG_OPLUS_*
      条件块位于 include 与注释之间），插入点移至该段之后；
    - `fs/proc/task_mmu.c`：include 区无 `<linux/ctype.h>`；
      `show_map_vma` 无 `is_pid` 参数（签名两行式）；`show_smap`
      为 MTK 单 vma 直渲形态（`smap_gather_stats` + oplus
      `android.bg` 特判），SUS_MAP 提前返回插在 `smap_gather_stats`
      之后；KSTAT/OPEN_REDIRECT 注入点按 `dev/ino` 赋值前后语义
      排布；pagemap 两处沿用 reference；
    - `fs/notify/fdinfo.c`：MTK 无 `inotify_mark_user_mask` helper
      （mask 计算内联于调用点），SUS_MOUNT 分支内输出改用与
      MTK 调用点一致的 `mark->mask & IN_ALL_EVENTS` 形式；
    - `mm/memory.c`：无 `#define CREATE_TRACE_POINTS`，include
      锚点截短。

## 验证状态

- `git apply`（真实工具执行）：上述 19 文件补丁对 MTK 树快照
  （23 文件稀疏树，内容取自仓库对应路径）整体应用通过；
  适配前 reference 原样应用失败于 4 文件
  （namespace/fdinfo/task_mmu/memory），失败 hunk 与上述差异一一
  对应。
- 编译验证（CI，`.github/workflows/build-RMX2117.yml`,
  workflow_dispatch, hook_mode=susfs-test）：vmlinux/Image/mt6853.dtb
  全链路产出，fs/susfs.o 与 drivers/kernelsu 各目标编译通过
  （build.log 实测）。
- 补丁本体已提升至 `patches/susfs/4.14/susfs-414-test.patch`
  （仓库补丁集合按版本分置；本 test 目录保留落位记录与
  reference）。

## manual hook（ReSukiSU 文档，4.17- 内核形态）

ReSukiSU 手册（resukisu.org manual-integrate）对 4.14（4.17-
内核）的专属要求，落位时按此核对：

- setuid：hook `SYSCALL_DEFINE3(setresuid)`（4.17- 形态；
  MTK 树 kernel/sys.c 无 `__sys_setresuid` 拆分）；
- execveat：hook `do_execveat_common`（3.14+ 通用）；
- faccessat：hook `SYSCALL_DEFINE3(faccessat)` wrapper
  （`do_faccessat` 在 4.14 无 ksys 拆分）；
- sys_read：hook `SYSCALL_DEFINE3(read)`（4.19- 形态）；
- reboot：`kernel/reboot.c` `SYSCALL_DEFINE4(reboot)`（3.11+
  位置）；
- 上述调用点由 `susfs_inline_hook_patches.sh`（仓库 shipped，
  tested 列表含 4.14）在构建时注入，属 CI 步骤而非本补丁
  内容；kernel/sys.c 的 4.14 hook 落点与 4.9 参考一致。

## 后续（CI 验证后）

把本候选固化为监督翻译管线的 reference（对齐
`test/susfs-510-to-49/`：inputs 适配资产 + tools 锚点 + translate
脚本 + 逐字校验），并据 CI 结果把 4 文件适配写入 `inputs/`。
