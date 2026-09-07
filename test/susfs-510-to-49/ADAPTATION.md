# test 面向 gki-5.10 的 4.9 移植：真实能力与产出机制

## 产出机制（translate.sh 实际做什么）

1. **core（fs/susfs.c、include/linux/susfs.h、susfs_def.h）**：
   拷贝上游 5.10 文件 → 应用 `inputs/susfs49-adapt.diff` /
   `def49-adapt.diff`（4.9 形态机械变换：AS_FLAGS_* 存 `i_state`、
   fsnotify 回调声明、版本条件头）→ 产出 4.9 core。真转换，脚本独立
   完成。

2. **21 个共享文件 + 2 个 reference 独有文件**：由
   `tools/translate49.py` 逐文件处理。当前实现：
   - 每个上游 hunk 与 reference 段配对（`tools/anchors/*.json`）；
   - 输出 = reference 段内容（4.9 权威形态）；
   - 上游内容与 reference 语义一致 → 直接通过；不一致 → 仍输出
     reference 内容并**上报人工复核**。

3. 产物 `out/susfs-49-rebuilt.patch` = 重建树 `git diff`，与 reference
   逐字节校验。

## 真实边界（不包装）

- core 是脚本从上游独立产出的。
- VFS/hook 文件的产出 = reference 内容（4.9 人工适配成果），脚本只做
  对照与差异上报，**不从上游内容独立生成 4.9 形态**。
- reference 的 4.9 形态包含大量 4.9 特有结构知识（stat.c 2 参
  vfs_getattr_nosec、task_mmu 两段式 show_map_vma、readdir 三回调、
  KSU hook 的 ReSukiSU 语义等），这些是人工适配产物，上游 5.10 内容
  不含、也无法自动推导。
- 因此"产物与 reference 逐字节一致"是设计使然（输出就是 reference
  内容），不是转换能力的证明。此前的"监督式翻译/自主复现"表述不实。

## 规则集方案（进行中，按用户确认方向）

目标：产出由上游内容驱动，reference 退居规则来源与验证基准。

- `tools/rules/<file>.json`：每文件规则，记录"该文件每个插入点的 4.9
  修正"（内容修正 fixups，来自上游 vs reference 差异，人工确认）。
- `translate49.py` 输出 = 上游内容 + 规则修正。
- 可自动：内容差异可表达为修正规则的文件。
- 需人工：4.9 特有结构逻辑（namei/namespace/readdir/task_mmu/stat/
  exec/open/... 等结构性差异文件）——这些的 4.9 插入形态是人工适配
  成果，规则无法表达整块 4.9 特有逻辑，人工维护其 reference 段。

## 验证（按用户确认方向）

- 每个文件产物 apply 到干净 stock-4.9 树；
- 整树编译通过（工具链：AOSP clang 14 + Android GCC 4.9 prebuilts）。
