# 4.9 SuSFS 重建工具（test 区，自洽）

`translate.sh` 在干净的 stock-4.9 内核树上重建 4.9 SuSFS 移植，并逐字
断言重建结果与本目录冻结的 reference 补丁一致（23/23 文件 hash-object
相同）。不一致即失败。

本目录全部输入与产物都在这棵 test 树内：`vendor/`（冻结快照）+
`inputs/`（4.9 适配资产）→ `out/susfs-49-rebuilt.patch`。不读取也不
写入仓库其他任何位置。

## 目录

| 路径 | 内容 |
|------|------|
| `vendor/susfs.c` `susfs.h` `susfs_def.h` | 上游 gki-android12-5.10 core |
| `vendor/50_add_susfs_in_gki-android12-5.10.patch` `10_enable_susfs_for_ksu.patch` | 上游补丁（参考） |
| `vendor/susfs_patch_to_4.9.patch` | 冻结的 4.9 VFS hook 点基底 |
| `vendor/susfs_inline_hook_patches-4.9.sh` | KSU 交互 hook 调用点生成器 |
| `vendor/susfs-adapt-4.9.sh` | fs/stat.c、fs/proc/task_mmu.c 的 stock 4.9 适配 |
| `vendor/reference-polaris-susfs-final.patch` | 字节校验基准（与仓库 mix2s 交付物 `patches/susfs/polaris-susfs-final.patch` 内容一致时初始化；此后独立维护） |
| `inputs/susfs49-adapt.diff` `def49-adapt.diff` | core 的 4.9 形态适配（i_state 位域、fsnotify 回调声明等；susfs.h 原样） |
| `inputs/delta_stat.diff` `delta_sys.diff` | 生成器在裸 4.9 树上跳过的残余 |
| `out/` | 重建产物（不入库） |

## 管线

1. core：vendor 三文件 + 适配资产 → `$KROOT`
2. VFS hook 点基底：vendor `susfs_patch_to_4.9.patch`（core 三文件除外）
3. vendor `susfs-adapt-4.9.sh`（stock 4.9 的 stat.c/task_mmu.c）
4. vendor 生成器（KSU 交互 hook 点）
5. `inputs/delta_*.diff`（残余）
6. `git diff` → `out/susfs-49-rebuilt.patch`；与 vendor reference 在
   相同 base 上逐文件 hash 比对

## 用法

```sh
test/susfs-510-to-49/translate.sh <kernel-root>          # 重建 + 字节校验
test/susfs-510-to-49/translate.sh <kernel-root> --keep   # 保留重建后的树
```

## 上游刷新

更新 `vendor/` 中的 core 三文件与上游补丁（内容以 susfs4ksu
gki-android12-5.10 为准），重跑本工具；字节校验闸门会列出漂移文件。
core 走 vendor + 适配资产自动派生；VFS hook 点的漂移由闸门暴露。

## 实测记录

- 完整重建 == vendor reference 23/23 文件逐字一致（PASS，幂等）
- 模拟上游新增函数：core 适配资产干净应用、新代码保留
