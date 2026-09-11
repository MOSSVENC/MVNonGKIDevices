# BBG（Baseband-guard）集成说明

BBG 是防格机/防砖的 Linux 安全模块，阻止恶意用户态写入关键分区
（boot / recovery / modem 等）。上游：<https://github.com/vc-teahouse/Baseband-guard>

4.9 上**不需要本地补丁**。从内核根运行上游 `setup.sh` 完成全部集成：

1. 克隆仓库到 `Baseband-guard/`
2. 符号链接 `security/baseband-guard`
3. 挂接 `security/Makefile`（`obj-$(CONFIG_BBG) += baseband-guard/`）
   与 `security/Kconfig`（`source "security/baseband-guard/Kconfig"`）
4. 4.9 路径（pre-5.1，无 `DEFINE_LSM`）：自动把 `sepatch.txt` 追加到
   `security/selinux/Makefile`，并向 `security/selinux/include/objsec.h`
   注入 `bbg_cred`（备份为 `.bak`；`setup.sh --cleanup` 可全部还原）

集成后只需 `CONFIG_BBG=y` 进入最终 `.config`（由
`scripts/integrate-bbg.sh` / `merge-defconfig.sh` 处理）。

## 状态

polaris（mix2s）编译面实测通过：`build-polaris`（`dc8e718`，`enable_bbg`）中上游
`setup.sh` 完成 selinux 侧接线，`CONFIG_BBG=y` 合并断言通过，并产出内核镜像与
AK3 包；运行面（拦写分区行为）待刷机实测。

## 为何不改 CONFIG_LSM

pre-5.1 内核的 BBG 通过旧式 `security_add_hooks(hooks, count,
"baseband_guard")` API 注册；`CONFIG_LSM=` 排序要求只存在于现代
（DEFINE_LSM）内核。上游 Makefile 只在"存在 DEFINE_LSM 但 CONFIG_LSM
缺 baseband_guard"时中止——本场景不适用。

## 可选加固

以下选项默认保持关闭（会干扰 ROM 内刷机），需要时在 BBG Kconfig 打开：

- `CONFIG_BBG_BLOCK_BOOT`：阻止 Android 用户态写 boot
- `CONFIG_BBG_BLOCK_RECOVERY`：阻止写 recovery

## 用法

```bash
bash scripts/integrate-bbg.sh <kernel-root>
```
