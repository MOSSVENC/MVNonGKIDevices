# ReSukiSU manual hooks — 4.14 树

面向 4.14 非 GKI 内核（realme AndroidS MTK 树）的树适配必加 hook
补丁。跨版本相同形态只保留单一副本（在 `../4.9/`）；workflow 以
文件级清单跨目录引用，不复制。

| 文件 | 说明 |
|---|---|
| `0001-fs-stat` / `0004-kernel-reboot` | 与 4.9 共享（单一副本在 `../4.9/`；MTK 的 stat.c / reboot.c 区域匹配） |
| `0002-fs-exec` | MTK 本地：include 块以 `<trace/events/sched.h>` 后的 `<mt-plat/mtk_pidmap.h>` 布局为锚 |
| `0003-fs-open` | MTK 本地：内联 `SYSCALL_DEFINE3(faccessat)` 函数体（MTK 树 fallocate/注释上下文） |
| `0010-input` / `0011-setuid` / `0012-sysread` | MTK 本地可选组（MTK input_event / 4.17- setresuid 函数体 / 含 OPLUS_IOMONITOR 区的内联 read 函数体），`hook_extra=manual` 模式使用 |

文档形态参考（网页摘录）见 `../upstream/manualhook/`。

## 应用（必加组）

```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu/4.9/0001-fs-stat-ksu-manual-hook.patch \
  patches/resukisu/4.14/0002-fs-exec-ksu-manual-hook.patch \
  patches/resukisu/4.14/0003-fs-open-ksu-manual-hook.patch \
  patches/resukisu/4.9/0004-kernel-reboot-ksu-manual-hook.patch
```
