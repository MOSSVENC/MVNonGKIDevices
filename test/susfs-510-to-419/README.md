# 4.19 SuSFS 移植候选（test 区，面向 LOS sm8250 kona 树）

目标：把 SuSFS（上游 gki-android12-5.10 素材，仓库 `patches/susfs/upstream-5.10/`）
移植到 LineageOS `android_kernel_xiaomi_sm8250` lineage-23.2（4.19.325 CAF kona）
并最终经 CI（`build-alioth.yml` hook_mode=susfs-test）编译验证。

## 组成

- `vendor/reference-alioth.patch` — 候选落位补丁（19 文件）：
  - core（fs/susfs.c、include/linux/susfs.h、susfs_def.h）：与 4.9
    shipped（`patches/susfs/0001-*`）逐字一致——同一份 5.10→老内核
    适配 core（AS_FLAGS_* 存 `i_state` 高位、版本条件头），4.19
    直接沿用；
  - 落位文件：按 5.10 素材的 4.19 落位形态排布；其中 12 个文件
    （namei/readdir/avc/fdinfo/proc base/cmdline/fd/proc_namespace/
    stat/statfs/kallsyms/sys）对 LOS 树逐 hunk 匹配；`mm/memory.c`
    已按 LOS 的 `mmap_read_lock_killable` 形态适配；`fs/namespace.c`
    大部分 hunk 可经 3-way 容错应用，`fs/Makefile`、`fs/proc/task_mmu.c`
    有 LOS 行差。
- `susfs-419-test.patch` — 与 reference 同文件的 CI 应用副本
  （build-alioth.yml 的 susfs-test 步骤应用对象）。

## 验证状态

- 静态核对：core 三段与 4.9 已验收资产逐字一致；落位文件对 LOS
  4.19.325 树的 context 匹配如上。
- 应用/编译验证经 GitHub Actions `build-alioth.yml`
  （workflow_dispatch, hook_mode=susfs-test）完成；首轮报错按
  `.rej` 迭代修正本候选。当前为候选状态。

## 后续（CI 验证通过后）

把本候选固化为监督翻译管线的 reference（对齐 4.9 的
`test/susfs-510-to-49/`：inputs 适配资产 + tools 锚点 + translate
脚本 + 逐字校验）。
