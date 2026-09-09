# ReSukiSU manual hooks — 4.9 树

面向 4.9 非 GKI 内核（polaris / beryllium / daisy / vince，LOS/CAF 树）
的树适配必加 hook 补丁。

| 文件 | 说明 |
|---|---|
| `0001-fs-stat` / `0002-fs-exec` / `0003-fs-open` / `0004-kernel-reboot` | 必加组（本内核族所需形态；open 走内联 `SYSCALL_DEFINE3(faccessat)` 函数体） |
| `0010-input` / `0011-setuid` / `0012-sysread` | 可选组，仅 `hook_extra=manual` 模式应用；`hook_extra=lsm`（默认）由 ReSukiSU 的 LSM / input_handler AUTO 机制覆盖 |
| `daisy/0004` / `vince/0004` | reboot hook 的设备树变体（两者 reboot.c 上下文不同）；这两棵树用变体代替 `0004`。`vince/0000-remove-legacy-ksu-hooks.patch` 在集成前剥离树自带旧 KernelSU 埋点 |

文档形态参考（网页摘录）见 `../upstream/manualhook/`；文档版本页与
本目录文件的对应：stat/exec/reboot 为 3.14+ 形态，open 为 4.19- 形态，
setuid 为 4.17- 形态，sys_read 为 4.19- 形态。

## 应用

```bash
bash scripts/apply-patches.sh <kernel-root> \
  patches/resukisu/4.9 [patches/resukisu/4.9/<device>]
```
