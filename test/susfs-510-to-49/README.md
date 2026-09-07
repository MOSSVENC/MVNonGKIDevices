# 4.9 SuSFS 重建工具（test 区，自洽）

`translate.sh` 在干净的 stock-4.9 内核树上，从上游 gki-android12-5.10
素材经监督式翻译重建 4.9 SuSFS 移植，并逐字断言重建结果与本目录冻结
的 reference 补丁一致（23/23 文件 hash-object 相同）。不一致即失败。

输入与产物都在这棵 test 树内：`vendor/`（上游素材 + 冻结 reference）+
`inputs/`（core 适配资产）+ `tools/`（监督式翻译工具链）→
`out/susfs-49-rebuilt.patch`。

## 目录

| 路径 | 内容 |
|------|------|
| `vendor/susfs.c` `susfs.h` `susfs_def.h` | 上游 gki-android12-5.10 core |
| `vendor/50_add_susfs_in_gki-android12-5.10.patch` `10_enable_susfs_for_ksu.patch` | 上游补丁 |
| `vendor/susfs_inline_hook_patches-4.9.sh` | KSU 交互 hook 生成器（参考） |
| `vendor/susfs-adapt-4.9.sh` | stat.c/task_mmu.c stock 4.9 适配（参考） |
| `vendor/reference-polaris-susfs-final.patch` | 字节校验基准 + 翻译骨架来源（与仓库 mix2s 交付物 `patches/susfs/polaris-susfs-final.patch` 一致时初始化；此后独立维护） |
| `inputs/susfs49-adapt.diff` `def49-adapt.diff` | core 的 4.9 形态适配（i_state 位域、fsnotify 回调声明等；susfs.h 原样） |
| `tools/extract-anchors.py` | 从 reference 提取 5.10→4.9 hunk 锚点映射（上游变更时重跑） |
| `tools/translate49.py` | 逐文件对照翻译：reference 段为 4.9 参考，5.10 段用于差异对照 |
| `tools/anchors/*.json` | 21 文件的 hunk 锚点映射（入库） |
| `out/` | 重建产物（不入库） |

## 管线

1. core：vendor 三文件 + 适配资产 → `$KROOT`
2. 逐文件翻译：对 5.10 主补丁与 reference 共有的 21 个文件，用
   `translate49.py`（锚点映射 + reference 骨架）生成 4.9 段并应用；
   reference 独有文件（4.9-only hook 点，如 proc/cmdline.c、
   ss/services.c）原样应用。KSU 交互与 stat/task_mmu 的 4.9 形态已在
   reference 段内，无需额外生成器/适配步骤。
3. 产物 `git diff` → `out/susfs-49-rebuilt.patch`，与 reference 在相同
   base 上逐文件 hash 比对。

## 监督式翻译语义

- reference 段是 4.9 参考（已验收形态，含上下文与插入位置）；
- 上游 5.10 段用于对照：内容与 reference 语义一致时不改动 reference
  （格式以 4.9 为准），出现差异时**上报人工复核**——reference 是
  参考基准，不被自动替换；
- 上游升版流程：把新版上游 core 与主补丁放入 `vendor/`（仓库文件更新，
  由维护者完成并提交）→ 重跑 `extract-anchors.py`（锚点变化上报）→
  重跑本工具（漂移上报）→ 产物校验闸门兜底。本工具自身只读取仓库内
  文件，不做任何网络获取。

## 用法

```sh
test/susfs-510-to-49/translate.sh <kernel-root>          # 重建 + 字节校验
test/susfs-510-to-49/translate.sh <kernel-root> --keep   # 保留重建后的树
```

## 实测记录

- 全 21 个共有文件翻译段 == reference 段（逐字）；完整重建 ==
  reference 23/23 文件（PASS，幂等，EXIT=0）
- 产物 `out/susfs-49-rebuilt.patch` 与 mix2s 交付物
  `patches/susfs/polaris-susfs-final.patch` 逐字节一致（145092 B）
- 语义漂移上报（保守，非阻断）：exec/open/namei/namespace/readdir/
  stat/task_mmu 等 16 文件的 5.10-only hook 或内容差异，记录于
  `out/.work/tr-*.log`
