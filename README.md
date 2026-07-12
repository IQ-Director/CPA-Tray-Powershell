# CPA-Tray-Powershell

使用 PowerShell 将 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 以 Windows 系统托盘形式运行，并在每次启动时检查和更新 CLIProxyAPI。

主仓库提供启动、停止、重启、托盘和更新脚本，并通过 Git 子模块引用 RunHiddenConsole 源码；不包含 CLIProxyAPI 程序本体、配置文件、账号数据或其他运行数据。项目发布的 Release 压缩包会附带 `RunHiddenConsole.exe`，便于直接使用。

## 功能

- 隐藏启动 CLIProxyAPI，不显示终端窗口
- 启动时检查 CLIProxyAPI 最新版本
- 下载更新前验证官方 SHA-256 校验和更新失败时自动恢复上一版本
- 使用 Chrome 应用模式打开管理界面
- 关闭管理窗口后继续在托盘后台运行
- 双击托盘图标重新打开管理界面
- 从托盘一键停止服务、检查更新并重新启动
- 从托盘菜单退出并停止 CLIProxyAPI
- 防止重复创建托盘实例

## 环境要求

- Windows 10 或 Windows 11
- PowerShell 5.1 或更高版本，推荐使用 [PowerShell 7](https://github.com/PowerShell/PowerShell)
- Google Chrome，未安装时使用系统默认浏览器
- CLIProxyAPI 的 `cli-proxy-api.exe`
- [RunHiddenConsole](https://github.com/wenshui2008/RunHiddenConsole) 的 `RunHiddenConsole.exe`
- CLIProxyAPI 的 `config.yaml`

RunHiddenConsole 源码已作为 Git 子模块引用。本仓库的 Git 历史不直接提交其可执行文件，但本项目发布的 Release 压缩包会附带 `RunHiddenConsole.exe`。该文件来自 [RunHiddenConsole](https://github.com/wenshui2008/RunHiddenConsole)，并按其 MIT 许可证重新分发。

## 安装

### 使用 Release（推荐）

从本项目的 [Releases](https://github.com/IQ-Director/CPA-Tray-Powershell/releases) 页面下载最新压缩包并解压。Release 包会附带 `RunHiddenConsole.exe`，无需单独编译或下载。

Release 包不会包含：

- `cli-proxy-api.exe`，首次运行 `start.bat` 时可自动下载
- `config.yaml`，需要自行准备
- 账号认证数据、浏览器资料和其他本地运行数据

### 从源码使用

克隆本仓库及 RunHiddenConsole 子模块：

```powershell
git clone --recurse-submodules https://github.com/IQ-Director/CPA-Tray-Powershell.git
```

源码仓库不包含 `RunHiddenConsole.exe`。可以自行编译 `third_party/RunHiddenConsole`，或从 [RunHiddenConsole 上游 Release](https://github.com/wenshui2008/RunHiddenConsole/releases/tag/1.0) 下载，然后将 `RunHiddenConsole.exe` 放到项目根目录。

最终目录结构如下：

```text
CLIProxyAPI/
|-- cli-proxy-api.exe
|-- config.yaml
|-- cpa-tray.config.json
|-- CPA.ico
|-- RunHiddenConsole.exe
|-- restart-and-update.ps1
|-- start.bat
|-- stop.bat
|-- update-cli-proxy-api.ps1
|-- watch-webui.ps1
```

`cli-proxy-api.exe` 可以预先从 CLIProxyAPI 官方 Release 下载，也可以在首次运行 `start.bat` 时由更新脚本自动下载。`config.yaml` 需要自行准备。

源码仓库和 Release 包均包含默认的 `CPA.ico`。如需自定义托盘图标，可以用同名图标文件替换：

```text
CLIProxyAPI/CPA.ico
```

脚本的图标加载顺序为：

1. `CPA.ico`
2. `cli-proxy-api.exe` 内置图标
3. Windows 默认应用图标

## 使用

双击运行：

```text
start.bat
```

启动后会自动执行以下操作：

1. 从 CLIProxyAPI 官方 GitHub Releases 检查更新。
2. 隐藏启动 `cli-proxy-api.exe`。
3. 创建系统托盘图标。
4. 打开 `cpa-tray.config.json` 中配置的管理页面。

关闭管理窗口不会停止服务。双击托盘图标，或右键选择 `Open Management`，可重新打开管理界面。

### 自定义管理页面 URL

编辑项目根目录中的 `cpa-tray.config.json`，可以配置需要打开的完整管理页面 URL：

```json
{
  "managementUrl": "http://127.0.0.1:8317/management.html"
}
```

`managementUrl` 必须是完整的 HTTP 或 HTTPS URL，可以同时自定义协议、主机、端口、路径和查询参数，例如：

```json
{
  "managementUrl": "https://example.com:9443/custom/management.html?mode=tray"
}
```

如果配置文件不存在、JSON 格式错误、地址不是绝对 URL，或协议不是 HTTP/HTTPS，托盘会回退到默认地址 `http://127.0.0.1:8317/management.html`。

右键托盘图标并选择 `Restart and Update`，会在终止当前 `cli-proxy-api.exe` 进程，并在重新启动时完成更新。

右键托盘图标并选择 `Exit`，会停止 CLIProxyAPI 并退出托盘程序。

也可以单独运行 `stop.bat` 停止 CLIProxyAPI 服务。

## 默认路径和端口

当前脚本使用以下默认值：

- PowerShell 查找顺序：`PATH` 中的 `pwsh.exe` → PowerShell 7 默认安装目录 → Windows PowerShell 5.1
- 管理页面：读取 `cpa-tray.config.json` 中的完整 URL，默认使用 `http://127.0.0.1:8317/management.html`
- Chrome 独立资料目录：`webui-profile`

如果需要使用其他 PowerShell，可将 `pwsh.exe` 所在目录加入 `PATH`，或修改 `start.bat` 中的查找逻辑。

## 自动发布 Release

仓库中的 `.github/workflows/release.yml` 会在推送 `v*` 标签时自动创建 GitHub Release。例如发布 `v1.1.0`：

```powershell
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions 会自动执行以下操作：

1. 检出当前标签对应的主仓库文件，不检出 RunHiddenConsole 子模块。
2. 从 RunHiddenConsole 官方 `1.0` Release 下载预编译程序。
3. 验证 `RunHiddenConsole.exe` 的固定 SHA-256，防止下载内容被意外替换。
4. 将脚本、默认托盘配置、默认图标、README、`RunHiddenConsole.exe` 和第三方 MIT 许可证整理到发布目录。
5. 生成 Windows x64 ZIP 压缩包和对应的 `.sha256` 校验文件。
6. 使用 GitHub 自动生成的 Release Notes 创建 Release；重复运行时覆盖上传同名资产。

生成的文件名格式如下：

```text
CPA-Tray-Powershell-v1.1.0-windows-x64.zip
CPA-Tray-Powershell-v1.1.0-windows-x64.zip.sha256
```

Release 包不会包含 `cli-proxy-api.exe`、`config.yaml`、账号认证数据、浏览器资料或其他本地运行数据。

## 自动更新

`update-cli-proxy-api.ps1` 从以下官方接口获取最新版本：

```text
https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest
```

更新脚本仅下载 Windows AMD64 版本，并使用官方 `checksums.txt` 验证下载文件。如果本地尚无 `cli-proxy-api.exe`，脚本会直接安装最新版本；更新已有版本时，旧程序会备份到 `backups` 目录。
