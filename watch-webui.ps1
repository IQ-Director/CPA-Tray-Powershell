#Requires -Version 5.1

<#
.SYNOPSIS
    Runs the CLIProxyAPI management page from a Windows system tray icon.
.DESCRIPTION
    Opens the management page in Chrome app mode, keeps CLIProxyAPI running
    after the browser window closes, and stops the service only when Exit is
    selected from the tray menu.
#>

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Resolve every runtime file relative to this script so the directory is portable.
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$url = "http://127.0.0.1:8317/management.html"
$userDataDir = Join-Path $baseDir "webui-profile"
$stopScript = Join-Path $baseDir "stop.bat"
$serviceExe = Join-Path $baseDir "cli-proxy-api.exe"
$trayIconPath = Join-Path $baseDir "CPA.ico"

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

# Exit is the only tray action that intentionally stops the CLIProxyAPI service.
$exitAction = {
    $notifyIcon.Visible = $false

    if (Test-Path -LiteralPath $stopScript) {
        & $stopScript *> $null
    }

    [System.Windows.Forms.Application]::Exit()
}

$openItem.add_Click($openAction)
$notifyIcon.add_DoubleClick($openAction)
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
