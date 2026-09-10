# patches/rmx2117 — RMX2117（MTK 4.14.186）树件修正

面向 `MOSSVENC/realme_X7_...-kernel-source`（`master`），构建前由 `build-RMX2117.yml`
以 `scripts/apply-patches.sh` 严格应用（`git apply --check` 通过才落盘）。

| 文件 | 作用 |
|---|---|
| `0001-vendor-code-fixes.patch` | 三处旧式函数定义补 `(void)`：`kernel/sched_assist/sched_assist_slide_v1.c:127`、`sound/soc/codecs/audio/sia81xx/sia81xx.c:1653`、`:1657`。内核顶层 `KBUILD_CFLAGS` 的 `-Werror=strict-prototypes` 在 clang 14 下把它们提升为构建错误 |
| `0002-vendor-werror-normalization.patch` | 厂商追加在 73 个 `Makefile`/`Kbuild` 里的 blanket `-Werror`（133 行）改为 `-Wno-error`。其余五台树的这些文件没有该行；clang 14 新增 `-Wunused-but-set-variable` 后，`mm/vmscan.c`、`drivers/devfreq/helio-dvfsrc-v3/helio-dvfsrc-sysfs.c` 等存量代码在该行作用下成为构建错误 |

## 证据

统一工具链（AOSP clang 14 `clang-r450784d`）+ 统一告警门的构建日志读数：

```
mm/vmscan.c:3470:6: error: variable 'nid' set but not used [-Werror,-Wunused-but-set-variable]
kernel/sched_assist/sched_assist_slide_v1.c:127:36: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
sound/soc/codecs/audio/sia81xx/sia81xx.c:1653:19: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
sound/soc/codecs/audio/sia81xx/sia81xx.c:1657:18: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
drivers/devfreq/helio-dvfsrc-v3/helio-dvfsrc-sysfs.c:262:23: error: variable 'dvfsrc' set but not used [-Werror,-Wunused-but-set-variable]
```

- `0002` 只替换 `-Werror` 记号，同一行其余内容（如 `-I$(srctree)/...`）保留；应用后该树
  blanket `-Werror` 命中数为 0。跨树比对：`polaris` / `beryllium` / `daisy` / `vince` / `alioth`
  的 `Makefile`、`Kbuild` 中同类行命中数均为 0。
- 两个补丁都在原始树件副本上通过 `git apply --check` 与完整应用（落位：`sched_assist_slide_v1.c`
  第 127 行、`sia81xx.c` 第 1653/1657 行、`0002` 覆盖的 73 个文件）。
