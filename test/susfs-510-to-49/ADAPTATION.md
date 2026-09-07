# test 面向 gki-5.10 的 4.9 移植：产出机制与验证

## 产出机制（translate.sh）

1. **core（fs/susfs.c、include/linux/susfs.h、susfs_def.h）**：
   拷贝上游 5.10 文件 → 应用 `inputs/susfs49-adapt.diff` /
   `def49-adapt.diff`（4.9 形态机械变换：AS_FLAGS_* 存 `i_state`、
   fsnotify 回调声明、版本条件头）→ 产出 4.9 core。由脚本独立完成。

2. **VFS/hook 文件**（21 个上游共有文件 + 2 个 reference 独有文件）：
   `tools/translate49.py` 逐文件处理：
   - 每个上游 hunk 与 reference 段配对（`tools/anchors/*.json`）；
   - 上游内容与 reference **语义一致** → 输出 reference 内容（4.9
     规范格式）。reference 是"上游内容 + 4.9 格式/结构适配"的已验收
     结果，两者语义一致时输出 reference 与输出上游在功能上等价；
   - 上游内容与 reference **语义不一致** → 输出 reference 内容并
     上报人工适配（上游变化点，人工把新内容适配成 4.9 后更新
     reference）。

## 能力边界

- core：脚本从上游独立产出（真转换）。
- VFS/hook：脚本重放 reference（已验收 4.9 形态）并精确检测上游语义
  变化；变化点的 4.9 适配由人工完成。reference 中的 4.9 特有结构
  （stat.c 2 参 vfs_getattr_nosec、task_mmu 两段式 show_map_vma、
  readdir 三回调、KSU hook 的 ReSukiSU 语义等）是人工适配成果，无法
  从上游 5.10 自动推导。
- 上游未变化时产物与 reference 一致是上述机制的必然结果，工具不把
  它宣称成"从上游独立生成"。

## 验证

- 每个文件产物 apply 到干净 stock-4.9 树（git apply --check）。
- 整树编译通过（AOSP clang 14 + Android GCC 4.9 prebuilts，配方见
  仓库根 README"工具链"）。
- 上游语义变化点以 MANUAL 上报，人工适配后更新 reference 再验证。
