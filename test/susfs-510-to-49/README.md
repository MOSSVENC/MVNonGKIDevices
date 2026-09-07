# 5.10 -> 4.9 SuSFS 重建工具（test 区，不与 patches/susfs 交付物混淆）

`translate.sh` 在干净的 stock-4.9 内核树上从四个已验证来源重建 4.9 SuSFS
移植，并**逐字断言**重建结果与交付物 `patches/susfs/polaris-susfs-final.patch`
一致（23/23 文件 hash 相同，实测通过）。不一致即失败——无假阳性。

## 为什么不是"翻译 5.10 上游主补丁"

实测（上游 v2.3.0 7373f8d8，main patch 23 文件 / 121 hunk）：

- 上游 VFS hook 段使用 5.10-only API：`ida_alloc_min`（5.9+）、
  `GFP_KERNEL_ACCOUNT`（4.9 无）、`d_alloc_parallel`（4.16+）、
  `open_last_lookups`（5.4+）、`VMA_PAD_START`、`show_options2`/
  `sb_rdonly` 的 5.10 形态、statfs result_mask 语义。把它们重定位进 4.9
  只会产出编译不过或语义错误的代码，故 mirror(5.10) 的 VFS 段不作为
  4.9 翻译源。
- 上游 KSU-interaction 段（exec/open/stat/read_write/input/reboot/sys）
  同样含 5.10 语义（`is_su_session`、`ksu_install_su_fd`、裸
  `ksu_handle_setresuid` 等），4.9 上由 ReSukiSU 兼容的 inline-hook
  生成器注入正确语义。
- 上游 core（susfs.c/h/def.h）与 4.9 基底逐字同源（v2.3.0），4.9 化
  只需一组已实测的机械适配（见下）。

结论：**全自动"5.10 主补丁 → 4.9"不存在**；可靠路径是"上游 core 同步
+ 4.9 基底 + 生成器 + 残余 delta"的合成，即本工具。

## 管线（四源合成）

在 `<kernel-root>`（干净 stock 4.9 git 树）上：

| 步 | 来源 | 作用 |
|----|------|------|
| A | `patches/susfs/susfs_patch_to_4.9.patch` | 4.9 语义 VFS/core 基底（namei/namespace/proc/.../susfs.c/h/def.h）。stat.c/task_mmu.c 的 hunk 预期失败（该补丁针对带反向移植的 fork），由 B 修正 |
| B | `scripts/susfs-adapt-4.9.sh` | stock 4.9 语义改写 `fs/stat.c`（generic_fillattr 2 参、vfs_getattr_nosec 无 result_mask）与 `fs/proc/task_mmu.c`（show_map_vma 两段式） |
| C | `patches/susfs/susfs_inline_hook_patches-4.9.sh` | KSU-interaction hook 点（exec/open/read_write/input/reboot/hooks/stat 等） |
| D | `inputs/delta_stat.diff`、`inputs/delta_sys.diff` | 裸 4.9 树上生成器会跳过的残余：`fs/stat.c` EXPORT_SYMBOL 后的 kstat-spoof extern、`kernel/sys.c` 的 `ksu_handle_setresuid` CONFIG_KSU 块（供 ReSukiSU 集成后使用） |

产物：`out/susfs-49-rebuilt.patch`；随后在相同 base 上应用 shipped port
作为 ground truth，逐文件 hash-object 比对（23 文件）。

## 用法

```sh
# 在干净 4.9 worktree 上重建并验证（失败即退出非零）
test/susfs-510-to-49/translate.sh <kernel-root>

# 保留重建后的树供检查
test/susfs-510-to-49/translate.sh <kernel-root> --keep

# 上游核对：mirror(5.10) core 相对 shipped port 的变化分类
test/susfs-510-to-49/translate.sh --check-upstream
```

## 实测结论（2026-09-07）

- Jack patch（除 stat.c/task_mmu.c）+ adapt + 生成器 + 两 delta =
  shipped port，**23/23 文件逐字一致**（hash-object，绝对路径）。
- mirror(5.10) core 相对 shipped port：susfs.h 0 变更；susfs.c/def.h
  仅机械适配（`i_mapping->flags`→`i_state` 及日志、fsnotify 回调
  `SUSFS_DECL_FSNOTIFY_OPS` 宏 + qstr 降级、version/cred 条件头、
  `__kuid_val` 条件、add_inode_mark 版本分支），无能力裁剪。
- 上游有新版 susfs 时：跑 `--check-upstream` 看 core 是否出现结构差异；
  若出现，重跑本工具，PASS 条件会暴露需更新的 delta，不允许静默放行。
