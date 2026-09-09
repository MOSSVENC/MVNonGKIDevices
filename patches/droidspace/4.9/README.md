# Droidspace 4.9（非 GKI）容器内核支持

Droidspaces（<https://github.com/ravindu644/Droidspaces-OSS>）是轻量
Linux 容器工具。本 4.9 非 GKI 内核的支持 = 内核 config 片段 + 一处
cgroup 源码修复。

## 组成

| 文件 | 作用 |
|---|---|
| `droidspace.config` | 内核 config 片段（由 `merge-defconfig.sh` 并入最终 `.config`），按官方 non-GKI 配置（Kernel-Configuration.md）的 4.9 符号名落位：`CONFIG_NF_CT_NETLINK`、`CONFIG_IP_NF_TARGET_MASQUERADE`（4.9 名）；`CONFIG_SECCOMP_FILTER` 是 5.x 符号，4.9 arm64 由 `CONFIG_SECCOMP=y` 提供过滤器；关闭 `CONFIG_ANDROID_PARANOID_NETWORK` 使容器网络可用 |
| `0001-cgroup-noprefix-4.9-port.patch` | cgroup `subsys.file` kernfs 符号链接恢复（`noprefix` 挂载、systemd/runc 风格），移植到 4.9 布局（`kernel/cgroup.c`） |

官方 non-GKI 补丁组中针对 `net/netfilter/xt_qtaguid.c` 的另一补丁
本 sdm845 4.9 树不包含，故未采用。

## 集成

```bash
bash scripts/integrate-droidspace.sh <kernel-root> \
  patches/droidspace/4.9/0001-cgroup-noprefix-4.9-port.patch
```
