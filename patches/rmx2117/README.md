# patches/rmx2117 — RMX2117（MTK 4.14.186）树件修正

面向 `MOSSVENC/realme_X7_...-kernel-source`（`master`）的最小树件修正，构建前由
`build-RMX2117.yml` 以 `scripts/apply-patches.sh` 严格应用（`git apply --check` 通过才落盘）。

| 文件 | 作用 |
|---|---|
| `0001-clang14-vendor-code-fixes.patch` | 统一工具链（AOSP clang 14 `clang-r450784d`）下暴露的两处树件问题 |

## 0001 的两处修正

1. `mm/Makefile`：厂商在该目录追加的 `subdir-ccflags-y += -Werror` 与其余五台树不一致
   （`polaris` / `beryllium` / `daisy` / `vince` / `alioth` 的 `mm/Makefile` 均无此行）。
   clang 14 新增 `-Wunused-but-set-variable`；`mm/vmscan.c` 的 `nid` 在非 NUMA 配置下经
   `NODE_DATA()` 宏丢弃（代码与上游主线一致），在该行作用下成为构建错误。
   该行去掉后，`mm/` 的告警级别与其余五台树相同。

2. `kernel/sched_assist/sched_assist_slide_v1.c:127`：`void adjust_sched_assist_input_ctrl()`
   为旧式函数定义，被内核顶层 `KBUILD_CFLAGS` 的 `-Werror=strict-prototypes` 提升为错误；
   改为 `(void)` 形式。

## 证据

- 失败读数（`logs/RMX2117-full.log`，统一工具链 + 统一告警门的构建）：

  ```
  mm/vmscan.c:3470:6: error: variable 'nid' set but not used [-Werror,-Wunused-but-set-variable]
  kernel/sched_assist/sched_assist_slide_v1.c:127:36: error: this old-style function definition is not preceded by a prototype [-Werror,-Wstrict-prototypes]
  ```

- `subdir-ccflags-y += -Werror` 的跨树比对：其余五台树 `mm/Makefile` 命中数均为 0。
- 本补丁在原始树件副本上通过 `git apply --check` 与完整应用（落位：`mm/Makefile` 第 5 行、
  `sched_assist_slide_v1.c` 第 127 行）。
