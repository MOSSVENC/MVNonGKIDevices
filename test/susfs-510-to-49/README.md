# 4.9 SuSFS 重建工具（test 区，不与 patches/susfs 交付物混淆）

`translate.sh` 在干净的 stock-4.9 内核树上重建 4.9 SuSFS 移植，并**逐字断言**
重建结果与交付物 `patches/susfs/polaris-susfs-final.patch` 一致（23/23
文件 hash-object 相同，实测通过）。不一致即失败——无假阳性。

## 上游更新的应对（为什么不是"用人家的补丁"）

上游 susfs4ksu 只维护 gki-android12-5.10+，Non-GKI 4.9 依赖第三方
(JackA1ltman) patch。本工具的依赖分层把第三方依赖降到最小：

| 层 | 来源 | 更新上游时 |
|----|------|-----------|
| **core**（susfs.c/h/def.h） | `upstream-5.10/` mirror + **自有适配资产** `inputs/susfs49-adapt.diff`、`def49-adapt.diff` | 刷 mirror → 自动套适配。实测：模拟上游新增函数后适配仍干净应用、新代码保留 |
| **VFS tier-1**（Makefile/readdir/memory） | 5.10 段 == 4.9 段（100% 同源实测） | 直接用 5.10 段 |
| **VFS tier-2**（statfs/kallsyms/proc_namespace/avc/base） | 5.10 段 + 可枚举小改写（`%px`→`%pK`、`sad->tsid`→`tsid` 等，实测差异 1-9 行/文件） | 规则化改写 |
| **VFS tier-3**（namei/namespace/task_mmu/stat/fdinfo/fd） | 冻结的 Jack patch（作为参考基底） | 仍依赖 Jack——剩余待消除项 |
| **KSU hook 点** | `susfs_inline_hook_patches-4.9.sh` + `inputs/delta_{stat,sys}.diff` | 生成器 + 残余 delta |

**core 已完全独立于第三方**：mirror(5.10) susfs.h 与 4.9 逐字相同（0 差异）；
susfs.c / susfs_def.h 的 4.9 化 = 自有适配资产（从 mirror 应用到结果与
shipped core 逐字一致）。上游出新版时 core 无需等任何人。

## 为什么 VFS 段不能直接"翻译 5.10 主补丁"

实测（上游 v2.3.0 7373f8d8）：5.10 VFS 段虽为纯插入（0 删除），但其
上下文含 5.10-only 相邻行/API（`ida_alloc_min`、`d_alloc_parallel`、
`open_last_lookups` 等），在 stock 4.9 上 git apply 与 patch fuzz 均失败
（实测 namei.c）。机械重定位（v1 relocate-hunk.py）会产出假阳性代码，
已废弃。tier-3 的可靠 4.9 语义只能来自冻结参考（Jack patch 或人工模板）。

## 管线（四步 + 字节验证）

1. **A0 core**：mirror 三文件 → apply 自有适配资产（susfs.c/def.h）；
   susfs.h 原样
2. **A/B/C**：tier-3 参考基底（Jack patch，core 文件除外）→
   `scripts/susfs-adapt-4.9.sh`（stat.c/task_mmu.c stock 4.9）→
   KSU-interaction 生成器 → `inputs/delta_{stat,sys}.diff`
3. **E**：`git diff` 产出 `out/susfs-49-rebuilt.patch`
4. 在相同 base 应用 shipped port 作 ground truth，逐文件 hash 比对

## 用法

```sh
test/susfs-510-to-49/translate.sh <kernel-root>          # 重建 + 字节验证
test/susfs-510-to-49/translate.sh <kernel-root> --keep   # 保留树供检查
test/susfs-510-to-49/translate.sh --check-upstream       # 更新流程说明
```

## 实测记录（2026-09-07）

- mirror core + 自有适配资产 == shipped port core 逐字一致（hash OK）
- 模拟上游新增函数：适配资产干净应用、新代码保留（升级路径可用）
- 完整重建 == shipped port 23/23 文件逐字一致（v3，PASS）
- tier-2 各文件与 5.10 段差异：statfs 1 行、kallsyms 1 行、avc 1 行、
  base 3 行、proc_namespace 9 行（show_options2 分支形态）
