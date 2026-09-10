# Droidspace 4.19（非 GKI，kona/sm8250）

Droidspaces（<https://github.com/ravindu644/Droidspaces-OSS>）容器支持，
面向 4.19 非 GKI 内核族（kona/sm8250 等 4.19 CAF 树）。官方
"Non-GKI" 说明直接覆盖 4.19（Kernel-Configuration.md：
"Applies to: Kernel 3.18, 4.4, 4.9, 4.14, 4.19"）。

官方补丁的唯一副本位于 `../official/`；本版本目录只放 config 片段，
workflow 直接引用 official 文件。

## 组成

| 文件 | 作用 |
|---|---|
| `droidspace.config` | 官方 non-GKI 必需配置块（Step 1），逐字采用。4.19 具备官方块的全部符号，包括 4.9 缺失的 5.x 时代名（`CONFIG_SECCOMP_FILTER`、`CONFIG_NF_CONNTRACK_NETLINK`、`CONFIG_NF_TABLES`、`CONFIG_NETFILTER_XT_TARGET_MASQUERADE`）。显式 `=y` 同时覆盖 kona 出厂基线（命名空间多关闭，如 `# CONFIG_PID_NS is not set`） |
| `../official/0001-official-fix-kernel-panic-in-xt_qtaguid.patch` | 官方 non-GKI 补丁 1/2（`net/netfilter/xt_qtaguid.c`）。LOS kona/sm8250 4.19 树不含 xt_qtaguid，对 alioth 为惰性（no-op）；保留供仍带 qtaguid 的其它 4.19 树 |
| `../official/0002-official-fix-restore-cgroup-file-prefix-handling.patch` | 官方 non-GKI 补丁 2/2（`kernel/cgroup/cgroup.c`）：为 `CGRP_ROOT_NOPREFIX` 挂载上的文件重建 `subsys.name` kernfs 符号链接，使 runc/crun 式挂载两种名称都可见。hunk 上下文与 4.19 `cgroup_add_file()` 逐字匹配，在 LOS kona 树上原样可应用 |

## 集成（alioth / LOS sm8250）

```bash
# 补丁 02 干净应用；补丁 01 在无 qtaguid 的树上是 no-op
for p in patches/droidspace/4.19/00*-*.patch; do
  git apply --check "$p" && git apply "$p" || echo "skip (no-op): $p"
done
```

config 片段由 `scripts/merge-defconfig.sh` 以 fragment 合并（传
`patches/droidspace/4.19/droidspace.config`），流程与 4.9 设备
（`patches/droidspace/4.9/`）相同。
