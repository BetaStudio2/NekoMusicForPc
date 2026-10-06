# Neko歌姬计划 PC版
![](https://count.getloli.com/get/@:NekoMusicPC?theme=moebooru)

> [!TIP]
> 🐾 **移动端入口**：[点击这里查看 Neko歌姬计划 安卓版仓库](https://github.com/MinecraftNekoServer/NekoMusicForAndroid)
> 🐾 **后端**：[点击这里查看 Neko歌姬计划 后端仓库](https://github.com/FantasyNetworkCN/NekoMusic)

# 本平台唯一官网 https://music.nekocore.cn
- ## 请勿通过非官方渠道获取安装包。本站被大量非法黑产生成盗版客户端诈骗，如你通过第三方平台获取安装包导致被骗本站拒绝一切赔偿

### 获取外部歌单api
获取qq歌单列表`https://music.nekocore.cn/loser1/getSongListDetail?disstid=歌单id`
获取网易云歌单列表`https://music.nekocore.cn/loser/playlist/track/all?id=歌单id`

> [!NOTE]
> 本仓库 **默认分支 `main`** 为 **Qt 6 + C++** 客户端。  
> 旧版 **Electron + Vue** 工程已单独放在 Git 分支 **`old`**（仅存档 / 按需构建），见该分支根目录的 [README](https://github.com/FantasyNetworkCN/NekoMusicForPc/blob/old/README.md)。

---

## 前置要求

| 依赖 | 最低版本 |
| --- | --- |
| CMake | ≥ 3.20 |
| Qt 6 | ≥ 6.2（需 Multimedia、Widgets 等，与 `CMakeLists.txt` 一致） |
| C++17 编译器 | GCC ≥ 9 / MSVC 2019 / Clang ≥ 10 |

**Debian / Ubuntu 示例：**

```bash
sudo apt install cmake qt6-base-dev qt6-multimedia-dev
```

---

## 配置与编译

项目可使用 CMake Presets，也可直接用脚本构建：

```bash
# Linux（推荐）
bash build_linux.sh

# Windows：在 Linux 上交叉编译（需自备 MinGW 版 Qt，见脚本内说明）
QT_WIN_ROOT=./qt-win/6.10.2/mingw_64 ./build_windows.sh
```

使用 Presets 时：

```bash
# Linux
cmake --preset linux-debug
cmake --preset linux-release
cmake --build build/linux-release -j"$(nproc)"

# Windows / macOS（需在对应系统或 CI 上）
cmake --preset windows-release
cmake --preset macos-release

# macOS 一键打通用 pkg（arm64 + x86_64）
./build_macos.sh
```

手动配置示例：

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

### 测试（若启用）

```bash
ctest --test-dir build/linux-debug --output-on-failure
```

### 安装（Linux）

```bash
cmake --install build/linux-release --prefix /usr/local
```

---

## MCP 服务端

桌面端内置一个本地 MCP（Model Context Protocol）服务器，可被 Claude Desktop、Cursor、Cherry Studio
等支持 MCP 的 AI 客户端调用，用于查询与控制播放。

### 开启方式

进入「设置 → MCP」：

- **启用内置 MCP 服务**：打开后在监听端口上启动服务。
- **监听端口**：默认 `7788`，取值 `1024-65535`。
- **访问令牌**：可选；填写后客户端需携带 `Authorization: Bearer <token>` 头。
- **允许局域网/远程设备访问**：默认仅监听 `127.0.0.1`，开启后监听所有网卡（请务必同时设置访问令牌）。
- **复制客户端配置**：一键把标准 `mcpServers` 配置写入剪贴板。

修改后点击「应用并重启服务」即时生效，状态栏会显示运行中地址或失败原因。

### 传输与端点

| 端点 | 方法 | 说明 |
| --- | --- | --- |
| `/mcp` | POST / GET / DELETE | Streamable HTTP（推荐） |
| `/sse` | GET | 旧版 SSE 连接入口 |
| `/messages?sessionId=…` | POST | 旧版 SSE 消息回传 |
| `/health` | GET | 健康检查 |

### 工具

`get_playback_state`、`get_current_track`、`get_queue`、`play`、`pause`、`toggle_playback`、
`stop`、`next_track`、`previous_track`、`seek`、`set_volume`、`set_play_mode`、
`search_music`、`play_music`、`play_search_result`。

### 客户端配置示例

```json
{
  "mcpServers": {
    "nekomusic": {
      "url": "http://127.0.0.1:7788/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

> `headers` 仅在设置了访问令牌时需要。

---

## 构建产物

| 平台 | 说明 |
| --- | --- |
| Linux | 可执行文件在构建目录；`build_linux.sh` 可用 CPack 打 deb（若已配置） |
| Windows | `build_windows.sh`（Linux 交叉编译）或 CI 原生构建，产物为 `dist/` 下的 NSIS 安装包 |
| macOS | `build_macos.sh` 完成后在 `dist/` 下生成通用架构 `.pkg`（arm64 + x86_64） |

---

## 贡献与反馈

构建或使用中遇到问题，欢迎提交 **Issue** 或 **Pull Request**。

---

## 法律与声明

- [用户协议](docs/user-agreement.md)
- [隐私政策](docs/privacy-policy.md)

应用内可在「设置 → 关于」中查看上述文档；首次启动需阅读并同意后方可使用本软件。
