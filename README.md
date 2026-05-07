# Neko云音乐 PC 客户端（旧版 Electron + Vue）

> [!IMPORTANT]
> 本分支 **`old`** 为历史遗留的 **Electron + Vite + Vue 3** 客户端，**不再与 `main`（Qt 6）同步维护**。  
> 新功能与发行版请以默认分支 **`main`** 为准。

克隆并切换到本分支：

```bash
git clone https://github.com/FantasyNetworkCN/NekoMusicForPc.git
cd NekoMusicForPc
git checkout old
```

---

## 环境

- **Node.js**：`^20.19.0` 或 `>=22.12.0`（与 `package.json` 中 `engines` 一致）
- **包管理器**：npm（随 Node 安装）

检查版本：

```bash
node -v   # 建议 v20.19+ 或 v22.12+
npm -v
```

### Linux 桌面集成（可选）

若托盘图标或状态栏菜单异常，可安装（Debian/Ubuntu 示例）：

```bash
sudo apt-get install libayatana-appindicator3-1 libappindicator3-1
```

`npm install` 后脚本里也会打印类似提示。

---

## 安装依赖

```bash
npm install
```

---

## 开发与调试

```bash
npm run dev
# 等价于 electron:dev：Vite + Electron
```

---

## 打包构建

| 目标 | 命令 |
| --- | --- |
| Windows | `npm run build:win` |
| Linux | `npm run build:linux` |
| macOS | `npm run build:mac` |
| 仅生成目录（不封装安装包） | `npm run build:dir` |
| Windows + Linux（脚本内配置） | `npm run build:all` |

通用构建（当前平台默认目标）：

```bash
npm run build
```

流程大致为：`vite build` → 复制 `electron/preload.cjs` → `electron-builder`。

---

## 构建产物

输出位于项目根目录下的 **`dist/`**、**`dist-electron/`** 等（具体以 `electron-builder` 配置为准），以及各平台安装包（如 `.exe`、`.AppImage`、`.dmg` 等）。

---

## 链接

- 官网：<https://music.cnmsb.xin>
- 当前 Qt 客户端：仓库 **`main`** 分支
