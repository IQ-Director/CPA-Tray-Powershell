# CPA-Tray-Powershell

使用 PowerShell 将 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 以 Windows 系统托盘形式运行，并可在每次启动时检查和更新 CLIProxyAPI。

主仓库提供启动、停止、重启、托盘和更新脚本、默认配置文件，并通过 Git 子模块引用 RunHiddenConsole 源码；不包含 CLIProxyAPI 程序本体、账号数据或其他运行数据。项目发布的 Release 压缩包会附带默认 `config.yaml` 和 `RunHiddenConsole.exe`，便于直接使用。

## 功能

- 隐藏启动 CLIProxyAPI，不显示终端窗口
- 可配置启动时是否检查 CLIProxyAPI 最新版本
- 下载更新前验证官方 SHA-256 校验
- 更新失败时自动恢复上一版本
- 使用 Chrome 应用模式打开管理界面
- 关闭管理窗口后继续在托盘后台运行
- 左键单击托盘图标重新打开管理界面
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
- 账号认证数据、浏览器资料和其他本地运行数据

Release 包和源码仓库均包含默认 `config.yaml`，使用前应根据实际环境修改。

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

`cli-proxy-api.exe` 可以预先从 CLIProxyAPI 官方 Release 下载，也可以在首次运行 `start.bat` 时由更新脚本自动下载。

### 默认 CLIProxyAPI 配置

项目包含一份可供修改的默认 `config.yaml`。首次启动前至少应检查以下设置：

- `host`：默认值为空，会监听所有 IPv4 和 IPv6 接口；如果只在本机使用，建议改为 `127.0.0.1`
- `port`：默认使用 `8317`
- `api-keys`：默认值是公开示例，请替换为自己的访问密钥
- `remote-management.secret-key`：需要使用管理 API 时请设置自己的管理密钥
- `auth-dir`、代理、插件和其他选项：按实际环境调整

不要在公共仓库中提交包含真实 API Key、管理密钥、代理凭据或其他敏感信息的配置文件。

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

1. 按配置从 CLIProxyAPI 官方 GitHub Releases 检查更新。
2. 隐藏启动 `cli-proxy-api.exe`。
3. 创建系统托盘图标。
4. 打开 `cpa-tray.config.json` 中配置的管理页面。

关闭管理窗口不会停止服务。点击托盘图标，或右键选择 `Open Management`，可重新打开管理界面。

### 自定义管理页面 URL

编辑项目根目录中的 `cpa-tray.config.json`，可以配置需要打开的完整管理页面 URL：

```json
{
  "managementUrl": "http://127.0.0.1:8317/management.html",
  "autoUpdate": true
}
```

`managementUrl` 必须是完整的 HTTP 或 HTTPS URL，可以同时自定义协议、主机、端口、路径和查询参数，例如：

```json
{
  "managementUrl": "https://example.com:9443/custom/management.html?mode=tray"
}
```

如果配置文件不存在、JSON 格式错误、地址不是绝对 URL，或协议不是 HTTP/HTTPS，托盘会回退到默认地址 `http://127.0.0.1:8317/management.html`。

将 `autoUpdate` 显式设为 `false` 可以禁止所有更新：

```json
{
  "managementUrl": "http://127.0.0.1:8317/management.html",
  "autoUpdate": false
}
```

关闭后，普通启动、托盘操作以及直接运行 `update-cli-proxy-api.ps1` 都不会更新 `cli-proxy-api.exe`，托盘中的更新菜单会显示为 `Updates Disabled` 并处于禁用状态。未配置 `autoUpdate` 或设为 `true` 时保持自动更新。

启用更新时，右键托盘图标并选择 `Restart and Update`，会终止当前 `cli-proxy-api.exe` 进程，并在重新启动时完成更新。

右键托盘图标并选择 `Exit`，会停止 CLIProxyAPI 并退出托盘程序。

也可以单独运行 `stop.bat` 停止 CLIProxyAPI 服务。

## 默认路径和端口

当前脚本使用以下默认值：

- PowerShell 查找顺序：`PATH` 中的 `pwsh.exe` → PowerShell 7 默认安装目录 → Windows PowerShell 5.1
- 管理页面：读取 `cpa-tray.config.json` 中的完整 URL，默认使用 `http://127.0.0.1:8317/management.html`
- Chrome 独立资料目录：`webui-profile`

如果需要使用其他 PowerShell，可将 `pwsh.exe` 所在目录加入 `PATH`，或修改 `start.bat` 中的查找逻辑。

## 自动更新

`update-cli-proxy-api.ps1` 从以下官方接口获取最新版本：

```text
https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest
```

更新脚本仅下载 Windows AMD64 版本，并使用官方 `checksums.txt` 验证下载文件。如果本地尚无 `cli-proxy-api.exe`，脚本会直接安装最新版本；更新已有版本时，更新前的程序会保存为 `backups/cli-proxy-api.previous.exe`。每次更新都会覆盖该文件并清理旧备份，因此只保留上一个版本用于失败回滚。

如需固定当前版本，请在 `cpa-tray.config.json` 中设置 `"autoUpdate": false`。该开关必须是 JSON 布尔值；配置文件无法解析或值类型错误时，更新脚本会安全退出，不会下载或替换程序。
