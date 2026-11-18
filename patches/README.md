# patches — 补丁分类与序列

补丁按**归属面**分三域，域内按**组件 → 内核版本 → 设备**下钻；每个可直接应用的补丁集合带一份
`series`（quilt 约定：一行一个补丁，路径相对该 `series` 所在目录，`#` 起注释，默认 strip 1）。
目录名承载分类结论，文件名只描述补丁本身。

```
patches/
├── root-manager/                  # 1) root 管理器面（与内核功能解耦）
│   └── bakasu/
│       ├── checkout/              #    与目标内核版本无关的 checkout 级补丁（01xx）
│       ├── manual/4.9/            #    源码 hook 补丁（按内核版本分目录）
│       └── device/                #    设备覆盖件
│           ├── daisy/4.9/   vince/4.9/
├── kernel/                        # 2) 内核功能面（按特性）
│   ├── susfs/                     #    SuSFS port，按内核版本、再按设备
│   │   └── 4.9/{polaris,beryllium,daisy,vince}/susfs-port.patch
│   ├── droidspace/                #    Droidspaces 面
│   │   ├── 4.9/                   #    树适配补丁 + config + README
│   │   └── upstream/              #    上游官方 non-GKI 补丁
│   ├── sdcardfs/                  #    sdcardfs Android/data 隔离
│   └── bbg/                       #    Baseband-guard（无本地补丁，CI 跑上游 setup.sh）
```

## 选择规则

1. **先看归属**：补丁改的是 root 管理器的集成面 → `root-manager/`；改内核功能面 → `kernel/`；
   只与某台设备的树或打包相关 → `device/`。
2. **再看版本**：同一功能在不同内核版本形态不同，必须落在对应版本目录；`checkout/` 下的是
   与版本无关的 checkout 级补丁。
3. **设备差异只落在设备子目录**：设备 port 与公共形态同构时也各自独立成文件，不放在版本目录根上，
   便于逐台 apply/parity 核对。
4. **一个目录一个应用单元**：`series` 与补丁同目录；workflow 只引用具体文件或该目录本身，
   不跨目录拼名单。

## 编号约定

| 前缀 | 用途 |
|---|---|
| `0000`–`0009` | 必加组（按应用顺序） |
| `0010`–`0019` | 可选组（`hook_extra=manual` 等开关打开时才应用） |
| `01xx` | checkout 级补丁（与内核版本无关，按管理器 checkout 顺序） |

## 非补丁文件

- `kernel/droidspace/*/droidspace.config`：内核 config 片段，由 `merge-defconfig.sh` 并入，不是补丁。

## series 校验

`series` 是给人看与机械校验用的清单：`localworkspace/maintain/check-patch-series.py` 检查
「`patches/` 下每个 `*.patch` 恰好出现在一份 `series` 里」且「`series` 的每个条目都存在」，
不参与 CI 应用顺序（应用顺序由各 `scripts/integrate-*.sh` 与 workflow 参数决定）。
