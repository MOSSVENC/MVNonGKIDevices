# 素材来源记录

本目录（`patches/rekernel/upstream/`）镜像 Sakion-Team/Re-Kernel 仓库的
`Integrate/rekernel/`（Kconfig / Makefile / rekernel.c / rekernel.h 四件，
逐字节一致）。

| 项 | 值 |
|---|---|
| 上游仓库 | <https://github.com/Sakion-Team/Re-Kernel> |
| 镜像来源 commit | `5adec48`（2026-09-07，Update REKERNEL_MAJOR_VERSION to 11.6） |
| 对应版本 | Re:Kernel 11.6（Integrate 内嵌形态，≤5.4 非 GKI） |
| 素材文件 | `Integrate/rekernel/` 四件 |

## 更新流程

上游更新（版本号变更、rekernel.c/netlink 逻辑改动、参数变化）时：

1. 拉上游目标 commit 的 `Integrate/rekernel/`，与本目录逐字节 diff
2. 替换本目录素材（单一真身，逐字节一致），并更新上表 commit/版本
3. 按 `patches/rekernel/README.md` 重新生成 `4.9/` 树适配补丁
   （0001 落位 + 4.9 适配面；0002/0003 调用点随 handler API 变化对齐）
4. 本机 git apply 验证，编译验证走 CI（workflow_dispatch）