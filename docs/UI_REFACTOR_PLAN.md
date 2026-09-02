# NekoMusicForPc UI 重构规划文档

> **版本**: v2.0（已按原版剔除）
> **日期**: 2026-08-10
> **目标**: 以 NekoMusicOrigin（原版）为基线，剔除原版没有的模块与特性后，完成现代化 UI 重构。

> ✂️ **2026-08-10 剔除记录**（依据用户指令："还原项目 → 剔除 UI_REFACTOR_PLAN.md 中原版没有的部分 → 再进行重构"）：
> 已确认 **NekoMusicForPc git HEAD == NekoMusicOrigin**（完全一致），以此作为基线。
> 剔除章节（原版 NekoMusicOrigin **没有**这些模块/特性）：
> - **§3 显卡加速策略**：原版 main.cpp 强制软件渲染，无 gpuaccel 模块
> - **§4.2 新主题体系**：原版无 palette/stylegen，仅 thememanager System/Dark/Light 三模式 + 两套 .qss
> - **§5.1 侧边栏折叠/动画指示条**：原版侧边栏为 240px 毛玻璃 + 自绘选中指示条，无折叠
> - **§5.2 悬浮播放栏/毛玻璃化/迷你频谱**：原版播放栏为 80px 停靠式，无 Floating/Spectrum
> - **§5.4 弹窗 NekoDialog 基类**：原版各对话框为 QDialog + 局部 polish，无统一基类
> - **§5.7 页面转场动画**：原版无转场，QStackedWidget 直接切换
> - **§6 性能与体积优化专项**：原版无 streaming 媒体流式模块、无极致体积专项（保持原版构建）
> - **§0 源码目录整理**：原版为扁平结构 src/core/*.cpp，不子目录聚类、不拆分 i18n
> - **§8.1 差异化清单（D1-D9）**：原版 theme.h 已固定玫红/樱花粉/薄荷绿三件套，无 stylegen 依赖实现
> 保留章节：§1 概述、§2 设计原则、§5.3 主窗口（图片背景框架原版已有）、§5.5 全局 QSS 微调、§5.6 设置页基础项。

---

## 1. 项目概述

### 1.1 背景

原作者认可 ArchoeraMusic 的 UI 设计，希望对 NekoMusicForPc 进行 UI 重构。由于技术栈差异（Flutter vs Qt6 C++），需要对设计元素进行**适应性修改与重绘**，而非直接照搬，以规避设计争议。

### 1.2 约束条件（不可逾越）

| 指标 | 上限 | 目标值（越小越好） | 说明 |
|------|------|-------------------|------|
| **运行内存 (RSS)** | **300 MiB** | ≤260 MiB（满载） | 空闲态 ≈36 MiB；普通播放 ≤80 MiB（保留原版优化成果） |
| **Windows NSIS 安装包** | **50 MiB** | **≤30 MiB** | LZMA 固实压缩 + Qt 依赖裁剪 |
| **macOS 单架构 .dmg** | **50 MiB** | **≤35 MiB** | strip + dmg 极致压缩 |
| **Linux .deb（不含 Qt 依赖）** | **8 MiB** | **≤4 MiB** | deb 本身 xz 压缩 + 可执行文件 LTO + strip |
| **兼容性** | — | — | 仍需支持无 GPU 加速的老旧机器（回退到软件渲染） |

> ⚠️ **原版约定**：打包体积越小越好；RSS 从 100 MiB 放宽到 300 MiB；服务器 CDN Cache + 最小 1 MiB Range 分片兜底。

---

## 2. 设计原则

### 2.1 核心原则：适应性迁移，而非复制

> 直接照搬 Flutter 侧的 UI 设计到 Qt 上可能引发版权/设计争议。必须进行**二次创作式的适配**。

**具体策略：**

| 元素 | ArchoeraMusic (Flutter) | NekoMusicForPc (Qt) — 适应性修改 |
|------|--------------------------|------------------------------------|
| **主色** | 亮蓝 `#4DA3FF` + 紫蓝 `#9B8CFF` | 沿用 Neko 原有玫红主色 `#F05E7A`，不换主色 |
| **深色底** | 近黑偏蓝 `#0E1117` 四层结构 | 保留原版深夜蓝基调（theme.h kBgDeep/kBgMid/kBgSurface） |
| **毛玻璃** | `BackdropFilter blur(16) + saturate(1.4)` | 使用 Qt `QPainter` 自绘（glasspaint/glasswidget），弱化模糊避免内存爆涨 |
| **图片背景模式** | 全屏封面 + 模糊 + dim 遮罩 | **原版已有** shellBackdrop 框架（mainwindow.cpp paintShellBackdrop）；保持默认关闭 |
| **侧边栏宽度** | 240 / 折叠 64 | 原版 240px 固定（不引入折叠） |
| **圆角规范** | 控件 10 / 卡片 12 / 弹窗 16 | 沿用原版 theme.h 圆角常量（kRSm=10/kRMd=14/kRLg=18/kRXl=22） |
| **封面取色** | 64px 中心加权取样 + 色桶评分 | 不引入（省内存 + CPU，原版无此功能） |

### 2.2 设计关键词

- **多层微差层级**：原版已有 surface 分层（kGlassBg/kGlassSidebar/kGlassPlayer）
- **统一圆角体系**：原版 theme.h 已定义（kRSm 10 / kRMd 14 / kRLg 18 / kRXl 22）
- **细滚动条**（8px 宽，hover 变深）
- **填充式无边框输入框**（描边 focus 态才显示）
- **克制的毛玻璃**：仅播放条 / 弹窗使用，不滥用

---

## 3. 显卡加速策略（重要改动）

✂️ **已剔除**：原版 NekoMusicOrigin 无 `gpuaccel` 模块。main.cpp 保持强制软件渲染（`QT_XCB_GL_INTEGRATION=none` + `QSG_RHI_BACKEND=software`），不引入 GPU 三档检测/设置。

---

## 4. 主题系统重构

### 4.1 现状

当前 [thememanager.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/theme/thememanager.h) 有 3 种模式：System / Dark / Light，通过加载不同 .qss 文件实现（style.qss / style-light.qss）。

### 4.2 新主题体系

✂️ **已剔除**：原版无 `palette.{h,cpp}` / `stylegen.{h,cpp}`。保持 thememanager 三模式 + 两套静态 .qss，不引入运行时调色板生成器。

---

## 5. 主要组件重构方案

### 5.1 侧边栏 [sidebar.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/sidebar.h)

✂️ **已剔除**：原版侧边栏为 240px 毛玻璃 + 自绘选中指示条（薄荷绿竖条，paintEvent），无折叠 240↔64 动画、无 animated 指示条、无底部折叠按钮。保持原版现状。

### 5.2 播放栏 [playerbar.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/playerbar.h)

✂️ **已剔除**：原版播放栏为 80px 停靠式（顶栏进度条 + 封面/中控/时间，已有毛玻璃 refreshGlassBackdrop），无 Floating 悬浮胶囊、无迷你频谱视图。保持原版现状。

### 5.3 主窗口骨架 [mainwindow.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/mainwindow.h)

#### 5.3.1 图片背景模式

**原版已有** shellBackdrop 框架（`paintShellBackdrop` / `shellBackdropPixmapForSize` / `scheduleShellBackdropRebuild` + ShellBackdropSettings）。重构仅做微调：
- 整窗背景使用当前播放歌曲封面（降采样缩略图，不用原图，省内存）
- 叠 dim 遮罩
- 默认关闭；开启时内容区 surface 分层半透明
- 切歌时背景图交叉淡入淡出（已有实现，保持）

#### 5.3.2 导航顶栏（TitleBar 微调）

Neko 现有 `TitleBar` 已包含搜索框和头像。微调项：
- 搜索框圆角 pill 样式
- 账号头像按钮：增加 1px 描边
- 搜索框 focus 态：填充 + 主色描边（对齐 Archoera `InputDecorationTheme`）

### 5.4 弹窗 / 对话框通用样式

✂️ **已剔除**：原版无 `NekoDialog` 基类。各对话框（LoginDialog / AddToPlaylistDialog / LineInputDialog / UpdateDialog / NeteaseImportDialog / QQImportDialog / DefaultMusicPlayerDialog）保持 QDialog + 局部 polish 现状，不引入统一基类。

### 5.5 滚动条 / 滑块 / 输入框（全局 QSS 覆盖）

**直接修改 style.qss / style-light.qss，不引入 stylegen。** 对齐 Archoera 思路：

**滚动条**：
- 宽 8px（现状不变）
- 颜色 `onSurface 22%`（暗）/ `28%`（亮）
- **新增**：hover 时变深（`onSurface 35%`）
- 最小长 36px（不变）

**滑块**：
- 轨道高 3px（现状 4px → 改为 3px）
- 滑块半径 6px（保留）
- 颜色 `primary`（现状一致）

**输入框**：
- 填充式（现状已有）
- 圆角 10px（一致）
- focus 态 1.2px 描边（现状 `border-color 120 alpha` → 改为 `primary 70% alpha`）

### 5.6 设置页扩展项 [settingspage.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/settingspage.h)

**保留基础设置项**（剔除 GPU / 主题三维 / 封面取色 / 页面转场 / 毛玻璃强度等原版没有的项）：

| 设置分组 | 选项 | 默认值 | 说明 |
|----------|------|--------|------|
| **外观** | 主题模式 | System | 跟随系统/暗色/亮色（原版已有） |
| | 图片背景 | 关 | 原版已有 ShellBackdropSettings |

> 其余项（主题色来源、外观风格、全局着色、播放栏样式、侧边栏折叠、指示条动画、页面转场、显卡加速、封面取色、毛玻璃强度）**均为原版没有的配置项，不引入**。

### 5.7 页面转场动画

✂️ **已剔除**：原版无页面转场。QStackedWidget 直接切换，不引入 pagetransitionhelper。

---

## 6. 性能与体积优化策略

✂️ **已剔除**：原版无媒体流式（streaming）模块（RangeBitmap / StreamingRingBuffer / AdaptiveHttpStreamer / DiskAudioCache）、无极致体积专项（NEKO_SIZE_OPTIMIZED）。维持原版构建流程与体积优化成果不变。

---

## 7. 实施阶段与优先级

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase A | **基线还原**：NekoMusicForPc 完全还原为 NekoMusicOrigin | ✅ 已完成（2026-08-10） |
| Phase B | **计划剔除**：剔除 UI_REFACTOR_PLAN 中原版没有的部分（本文档） | ✅ 已完成 |
| Phase C | **布局修复**：每日推荐入口占位异常（高度被全局 QSS 压扁）、各页标题排头对齐 | 待做 |
| Phase D | **QSS 微调**（§5.5）：滚动条 hover / 滑块轨道 / 输入框 focus 描边 | 待做 |
| Phase E | **顶栏微调**（§5.3.2）：搜索框 pill、头像描边、focus 态 | 待做 |
| Phase F | **设置页 i18n 补齐 + 布局统一**（§5.6） | 待做 |
| Phase G | **编译 + 离屏几何验证**（每日推荐高度/标题对齐/毛玻璃/QSS 无警告） | 待做 |

---

## 0. 源码目录整理 & 章节映射表

✂️ **已剔除**：原版为扁平结构（src/core/*.cpp 单目录、src/theme 3 文件、src/ui 无新增）。不进行 7 子目录聚类、不拆分 i18n.cpp（保持原版 src/core/i18n.{h,cpp} 单文件）。

---

## 8. 风险与注意事项

### 8.1 设计争议规避

✂️ **已剔除**：原版 theme.h 已固定「玫红主色 `#F05E7A` + 樱花粉描边 + 薄荷绿辅色」三件套，与 Archoera「紫蓝 + 天蓝」体系天然区分。无需 D1-D9 差异化清单（其实现依赖已剔除的 palette/stylegen）。

### 8.2 技术风险

| 风险 | 严重度 | 缓解措施 |
|------|--------|----------|
| 全局 QSS 覆盖破坏自绘控件 | 高 | 自绘类（SongCardWidget/CoverListCard/GlassWidget）零改动；QSS 仅加选择器优先级明确的规则 |
| 图片背景模式内存爆 | 高 | 256px 缩略图 + 默认关闭 |
| QSS 覆盖把按钮压扁 | 中 | **不设全局 QPushButton min-height/min-width**（历史教训：92px 每日推荐入口曾被压到 42px） |

### 8.3 不做的事情（避免范围蔓延）
- ❌ 不引入 QML / Qt Quick（体积 + 内存 + 学习成本爆炸）
- ❌ 不内嵌中文字体（体积 > 10 MiB）
- ❌ 不做 DWM / 系统标题栏材质集成
- ❌ 不替换现有 SVG 图标集（保持资源零新增）
- ❌ 不改播放引擎 / 网络逻辑（纯 UI 重构）
- ❌ 不引入 GPU 加速 / 主题调色板 / NekoDialog / 页面转场 / 媒体流式（原版均无）

---

## 9. 验收清单

### 功能验收
- [ ] 每日推荐入口高度正确（≥92px，封面 70×70 不被压扁）
- [ ] 各页面标题排头对齐（x=24）
- [ ] 主题（暗/亮/跟随系统）切换正常
- [ ] 图片背景模式保持原版行为（默认关）
- [ ] 滚动条 hover 变深、滑块轨道 3px、输入框 focus 主色描边
- [ ] 设置页全部文案 i18n 化

### 硬指标验收（保持原版成果不变）
- [ ] Linux 空闲态 RSS ≤ 55 MiB（保持原版）
- [ ] 打包体积（Windows ≤50 MiB / macOS ≤50 MiB / Linux .deb ≤8 MiB，保持原版）
- [ ] 冷启动耗时 ≤ 1.2s（SSD）

---

## 10. 参考文件速查

### NekoMusic (Qt) 核心 UI 文件（原版基线）
| 文件 | 作用 |
|------|------|
| [src/main.cpp](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/main.cpp) | 入口，软件渲染 |
| [src/theme/thememanager.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/theme/thememanager.h) | 主题管理器（System/Dark/Light） |
| [src/theme/theme.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/theme/theme.h) | 主题常量（玫红/樱花/薄荷 + 尺寸 + 动画） |
| [src/resources/style.qss](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/resources/style.qss) | 暗色 QSS（微调点：滚动条/滑块/输入框） |
| [src/resources/style-light.qss](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/resources/style-light.qss) | 亮色 QSS |
| [src/ui/mainwindow.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/mainwindow.h) | 主窗口骨架（含 shellBackdrop 框架） |
| [src/ui/sidebar.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/sidebar.h) | 侧边栏（240px，现状保持） |
| [src/ui/playerbar.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/playerbar.h) | 播放栏（80px 停靠，现状保持） |
| [src/ui/titlebar.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/titlebar.h) | 顶栏搜索框 / 头像（微调点） |
| [src/ui/settingspage.h](file:///home/betastudio2/文档/SPlayer-Next/NekoMusicForPc/src/ui/settingspage.h) | 设置页（外观分组，i18n 补齐） |
