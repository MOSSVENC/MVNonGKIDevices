# 5.10 -> 4.9 脚本翻译实验（test 区，不与 patches/susfs 混淆）

目的：确定"直接面对 gki-android12-5.10 上游"时，哪些翻译能脚本化、
哪些必须人工/由生成器负责。结论基于实测（2026-09-07，上游 v2.3.0
7373f8d8）。

## 实测数据

上游主补丁 23 文件 / 121 hunk，对 4.9 树：
- git apply 整包：失败（严格）
- patch 整包：83 hunk 失败
- **逐 hunk（有序重试）直接应用成功：57/121**
- 纯插入 hunk：110/121（绝大多数！）→ 理论上可重定位
- 含删除 hunk：1/121

## 脚本化边界（判定规则）

1. **可直接 patch**（50-57 hunk）：上下文偏移小，脚本 `patch -p1 -f`
   按序重试即可。
2. **纯 susfs 插入 hunk**（无 ksu_ 符号、无删除行）：上下文净化重定
   位可处理（见 apply-hunks.py），但**插入点需人工复核**——机械锚定
   会偏（exec.c include 插到 asm/ 区即为例证）。
3. **含 ksu_* 交互的 hunk**（ksu_handle_*/is_su_session/
   ksu_install_su_fd/ksu_su_compat 等）：**不由上游主补丁翻译**——4.9
   由 ReSukiSU 兼容的生成器注入（susfs_inline_hook_patches-4.9.sh，
   已验证产出正确语义）。
4. **不可移植**：selinuxfs.c/hooks.c my_*（state-ful API，4.9 无，
   ReSukiSU fallback 等价承担）；bootconfig（5.x）。
5. **结构/语义差异**（exec su-session、namei 深层重构）：脚本不可靠，
   需人工对照现有 port 翻译。

## 结论

"全自动 5.10->4.9"不可行（机械重定位会产出假阳性代码，exec.c 实证）。
可靠管线 = 脚本处理 1/2 类 + 生成器处理 3 类 + 人工复核 2 类插入点 +
人工翻译 5 类。verify-susfs-parity.sh（scripts/）是更新后的校验闸门。

## 文件

- translate.sh        — 主流程雏形（逐文件段 + patch/git apply 分层）
- apply-hunks.py      — 纯插入 hunk 锚定重定位（实验性，位置需复核）
- relocate-hunk.py    — 上下文净化重定位（实验性，效果有限）
- out/                — 最近一次运行的产物（含 manual-list.txt）
