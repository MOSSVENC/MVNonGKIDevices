# ReSukiSU manual hooks — 4.19 树

面向 4.19 非 GKI 内核（alioth / kona LOS 树）的树适配必加 hook
补丁。跨版本相同形态只保留单一副本（在 `../4.9/`）；workflow 以
文件级清单跨目录引用，不复制。

| 文件 | 说明 |
|---|---|
| `0001-fs-stat` / `0002-fs-exec` / `0004-kernel-reboot` / `0010-input` | 与 4.9 共享（单一副本在 `../4.9/`）：4.19 保持 3.14+ 的 `do_execveat_common` 形态，stat/reboot/input 区域匹配 |
| `0003-fs-open` | 4.19 本地：faccessat 函数体移入 `do_faccessat(dfd, filename, mode)`，hook 落在薄包装 `SYSCALL_DEFINE3(faccessat)`（4.19+ 形态） |
| `0011-setuid` | 4.19 本地：4.17+ 形态，hook `__sys_setresuid` |
| `0012-sysread` | 4.19 本地：4.19+ 形态，hook `ksys_read` 包装 |

文档形态参考（网页摘录）见 `../upstream/manualhook/`。

## 应用（必加组）

```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu/4.9/0001-fs-stat-ksu-manual-hook.patch \
  patches/resukisu/4.9/0002-fs-exec-ksu-manual-hook.patch \
  patches/resukisu/4.19/0003-fs-open-ksu-manual-hook.patch \
  patches/resukisu/4.9/0004-kernel-reboot-ksu-manual-hook.patch
```
