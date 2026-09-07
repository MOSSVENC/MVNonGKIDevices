# 4.9 SuSFS 重建工具（test 区）

`translate.sh` 在干净的 stock-4.9 内核树上重建 4.9 SuSFS 移植，并逐字
断言重建结果与交付物 `patches/susfs/polaris-susfs-final.patch` 一致
（23/23 文件 hash-object 相同）。不一致即失败。

## 输入

| 输入 | 路径 | 用途 |
|------|------|------|
| 上游 core | `patches/susfs/upstream-5.10/`（susfs.c、susfs.h、susfs_def.h） | core 三文件 |
| core 4.9 适配 | `inputs/susfs49-adapt.diff`、`inputs/def49-adapt.diff` | susfs.c / susfs_def.h 的 4.9 形态（i_state 位域、fsnotify 回调声明等）；susfs.h 原样使用 |
| VFS hook 参考 | `patches/susfs/susfs_patch_to_4.9.patch` | 5.10 段上下文不适用于 stock 4.9 的文件的 4.9 hook 点 |
| KSU hook 生成器 | `patches/susfs/susfs_inline_hook_patches-4.9.sh` | KSU 交互调用点 |
| 残余 delta | `inputs/delta_stat.diff`、`inputs/delta_sys.diff` | 生成器在裸 4.9 树上跳过的部分 |
| stock-4.9 适配 | `scripts/susfs-adapt-4.9.sh` | fs/stat.c、fs/proc/task_mmu.c 的 stock 4.9 形态 |

## 为什么 VFS hook 点分两个来源

上游主补丁（gki-android12-5.10）的 VFS 段在 stock 4.9 树上不能直接
应用：其 hunk 上下文含 5.10-only 相邻行（如 namei.c 实测 git apply 与
patch fuzz 均失败）。core 三文件与上游逐字同源（v2.3.0），只需机械
适配；VFS hook 点中 5.10 段可应用的取自 mirror，其余取自冻结参考
补丁。上游升版时：core 走 mirror + 适配资产自动派生；VFS 段是否漂移
由重建的字节校验闸门暴露（失败会列出文件）。

## 用法

```sh
test/susfs-510-to-49/translate.sh <kernel-root>          # 重建 + 字节校验
test/susfs-510-to-49/translate.sh <kernel-root> --keep   # 保留重建后的树
test/susfs-510-to-49/translate.sh --check-upstream       # 上游 core 差异预览
```

## 实测记录

- core：mirror + 适配资产 == shipped port core 逐字一致（hash OK）
- 完整重建 == shipped port 23/23 文件逐字一致（PASS，幂等）
- 模拟上游新增函数：core 适配资产干净应用、新代码保留
- VFS 5.10 段 vs 4.9 参考段的内容差异（逐文件）：statfs 1 行、
  kallsyms 1 行、avc 1 行、base 3 行、proc_namespace 9 行
  （show_options2 分支形态）、namei/namespace 结构差异（由冻结参考
  提供 4.9 形态）
