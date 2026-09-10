# patches/rmx2117 — RMX2117（MTK 4.14.186）树件修正

面向 `MOSSVENC/realme_X7_...-kernel-source`（`master`），构建前由 `build-RMX2117.yml`
以 `scripts/apply-patches.sh` 严格应用（`git apply --check` 通过才落盘）。

| 文件 | 作用 |
|---|---|
| `0001-vendor-code-fixes.patch` | 厂商代码里的旧式函数定义补 `(void)`（181 个 `.c`/`.h`，270 处）。内核顶层 `KBUILD_CFLAGS` 的 `-Werror=strict-prototypes` 在 clang 14 下把它们提升为构建错误；已出现的实例：`kernel/sched_assist/sched_assist_slide_v1.c`、`sound/soc/codecs/audio/sia81xx/sia81xx.c`、`drivers/gpu/drm/mediatek/mtk_drm_crtc.c` |
| `0002-vendor-werror-normalization.patch` | 厂商追加在 73 个 `Makefile`/`Kbuild` 里的 blanket `-Werror`（133 行）改为 `-Wno-error`。其余五台树的这些文件没有该行；clang 14 新增 `-Wunused-but-set-variable` 后，`mm/vmscan.c`、`drivers/devfreq/helio-dvfsrc-v3/helio-dvfsrc-sysfs.c` 等存量代码在该行作用下成为构建错误 |

`0001` 是全树同类的收敛：`-Wstrict-prototypes` 是各内核树共有的提升，逐处等 CI 报错会一轮只前进一两个文件。

## 证据

统一工具链（AOSP clang 14 `clang-r450784d`）+ 统一告警门的构建日志读数：

```
mm/vmscan.c:3470:6: error: variable 'nid' set but not used [-Werror,-Wunused-but-set-variable]
kernel/sched_assist/sched_assist_slide_v1.c:127:36: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
sound/soc/codecs/audio/sia81xx/sia81xx.c:1653:19 / :1657:18: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
drivers/gpu/drm/mediatek/mtk_drm_crtc.c:6908:42 / :6974:46: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
drivers/devfreq/helio-dvfsrc-v3/helio-dvfsrc-sysfs.c:262:23: error: variable 'dvfsrc' set but not used [-Werror,-Wunused-but-set-variable]
```

- `0001` 的候选集来自该树全量 `.c`/`.h`（34354 + 30874 个文件）的扫描：构建相关路径 270 处旧式定义，
  余下命中均为注释内文本或其他架构（alpha/mips/powerpc/sparc 等，不在 arm64 构建内）。
- `0002` 只替换 `-Werror` 记号，同一行其余内容（如 `-I$(srctree)/...`）保留；应用后该树
  blanket `-Werror` 命中数为 0。跨树比对：`polaris` / `beryllium` / `daisy` / `vince` / `alioth`
  的 `Makefile`、`Kbuild` 中同类行命中数均为 0。
- 两个补丁都在原始树件副本上通过 `git apply --check` 与完整应用（合计改动 254 个文件）。
