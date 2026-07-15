#Requires -Version 5.1

<#
.SYNOPSIS
    Runs the CLIProxyAPI management page from a Windows system tray icon.
.DESCRIPTION
    Opens the management page in Chrome app mode, keeps CLIProxyAPI running
    after the browser window closes, supports updating and restarting the
    backend, and stops the service only when Exit is selected from the tray menu.
#>

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Resolve every runtime file relative to this script so the directory is portable.
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultUrl = "http://127.0.0.1:8317/management.html"
$trayConfigPath = Join-Path $baseDir "cpa-tray.config.json"
$url = $defaultUrl
$userDataDir = Join-Path $baseDir "webui-profile"
$stopScript = Join-Path $baseDir "stop.bat"
$restartUpdateScript = Join-Path $baseDir "restart-and-update.ps1"
$serviceExe = Join-Path $baseDir "cli-proxy-api.exe"
$trayIconPath = Join-Path $baseDir "CPA.ico"
$powerShellExe = (Get-Process -Id $PID).Path

# Load a complete HTTP or HTTPS management URL from the optional tray config.
if (Test-Path -LiteralPath $trayConfigPath -PathType Leaf) {
    try {
        $trayConfig = Get-Content -LiteralPath $trayConfigPath -Raw | ConvertFrom-Json
        $configuredUrl = [uri]([string]$trayConfig.managementUrl).Trim()

        if (-not $configuredUrl.IsAbsoluteUri -or $configuredUrl.Scheme -notin @("http", "https")) {
            throw "managementUrl must be an absolute HTTP or HTTPS URL."
        }

        $url = $configuredUrl.AbsoluteUri
    }
    catch {
        $url = $defaultUrl
    }
}

# A named mutex prevents repeated start.bat calls from creating duplicate tray icons.
$createdNew = $false
$mutex = [System.Threading.Mutex]::new($true, "Local\CLIProxyAPI.Tray", [ref]$createdNew)

if (-not $createdNew) {
    $mutex.Dispose()
    exit 0
}

# Locate Chrome in its common machine-wide and per-user installation directories.
$chromeCandidates = @()

foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LocalAppData)) {
    if ($root) {
        $chromeCandidates += Join-Path $root "Google\Chrome\Application\chrome.exe"
    }
}

$chrome = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

function Show-ManagementWindow {
    # Chrome app mode provides a standalone window without normal browser chrome.
    if ($chrome) {
        Start-Process -FilePath $chrome -ArgumentList @(
            "--app=$url",
            "--user-data-dir=$userDataDir",
            "--no-first-run",
            "--window-size=1920,1200",
            "--window-position=250,150"
        )
        return
    }

    Start-Process $url
}

# Build the tray menu and notification icon without creating a visible form.
$contextMenu = [System.Windows.Forms.ContextMenuStrip]::new()
$openItem = $contextMenu.Items.Add("Open Management")
$restartUpdateItem = $contextMenu.Items.Add("Restart and Update")
$null = $contextMenu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())
$exitItem = $contextMenu.Items.Add("Exit")
$notifyIcon = [System.Windows.Forms.NotifyIcon]::new()

# Prefer CPA.ico, then the service executable icon, and finally a Windows default.
try {
    if (Test-Path -LiteralPath $trayIconPath) {
        $notifyIcon.Icon = [System.Drawing.Icon]::new($trayIconPath)
    } elseif (Test-Path -LiteralPath $serviceExe) {
        $notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($serviceExe)
    } else {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    }
}
catch {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
}

$notifyIcon.Text = "CLIProxyAPI"
$notifyIcon.ContextMenuStrip = $contextMenu
$notifyIcon.Visible = $true

$openAction = {
    Show-ManagementWindow
}

$restartUpdateAction = {
    try {
        if (-not (Test-Path -LiteralPath $restartUpdateScript -PathType Leaf)) {
            throw "restart-and-update.ps1 was not found."
        }

        Start-Process -FilePath $powerShellExe -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$restartUpdateScript`""
        ) -WindowStyle Hidden
    }
    catch {
        $notifyIcon.ShowBalloonTip(
            5000,
            "CLIProxyAPI restart failed",
            $_.Exception.Message,
            [System.Windows.Forms.ToolTipIcon]::Error
        )
    }
}

# Exit is the only tray action that intentionally stops the CLIProxyAPI service.
$exitAction = {
    $notifyIcon.Visible = $false

    if (Test-Path -LiteralPath $stopScript) {
        & $stopScript *> $null
    }

    [System.Windows.Forms.Application]::Exit()
}

$openItem.add_Click($openAction)
$notifyIcon.add_MouseClick({
    param($sender, $eventArgs)

    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        & $openAction
    }
})
$restartUpdateItem.add_Click($restartUpdateAction)
$exitItem.add_Click($exitAction)

try {
    Show-ManagementWindow

    # Keep the PowerShell process alive to receive tray and menu events.
    [System.Windows.Forms.Application]::Run()
}
finally {
    # Explicit disposal prevents a stale tray icon from remaining after shutdown.
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $contextMenu.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
