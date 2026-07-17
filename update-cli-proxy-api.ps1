#Requires -Version 5.1

<#
.SYNOPSIS
    Updates the local CLIProxyAPI Windows executable from the official release.
.DESCRIPTION
    Queries the latest GitHub release, verifies the downloaded archive against
    the official SHA-256 checksum, backs up the installed executable, and rolls
    back automatically if replacement or version verification fails.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Keep downloaded binaries and runtime metadata beside the launcher scripts.
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$binaryPath = Join-Path $baseDir 'cli-proxy-api.exe'
$pidFile = Join-Path $baseDir 'cli-proxy-api.pid'
$backupDir = Join-Path $baseDir 'backups'
$trayConfigPath = Join-Path $baseDir 'cpa-tray.config.json'
$releaseApi = 'https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest'
$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'CLIProxyAPI-Windows-Updater'
    'X-GitHub-Api-Version' = '2022-11-28'
}

# Enforce the update switch here so every caller follows the same setting.
if (Test-Path -LiteralPath $trayConfigPath -PathType Leaf) {
    try {
        $trayConfig = Get-Content -LiteralPath $trayConfigPath -Raw | ConvertFrom-Json
        $autoUpdateProperty = $trayConfig.PSObject.Properties['autoUpdate']

        if ($autoUpdateProperty) {
            if ($autoUpdateProperty.Value -isnot [bool]) {
                throw 'autoUpdate must be a JSON boolean.'
            }

            if (-not $autoUpdateProperty.Value) {
                Write-Host 'CLIProxyAPI updates are disabled in cpa-tray.config.json.'
                exit 0
            }
        }
    }
    catch {
        Write-Warning "Could not read the auto-update setting: $($_.Exception.Message)"
        exit 1
    }
}

function Get-InstalledVersion {
    # CLIProxyAPI reports its semantic version through the --version argument.
    if (-not (Test-Path -LiteralPath $binaryPath -PathType Leaf)) {
        return $null
    }

    $output = (& $binaryPath --version 2>&1 | Out-String)
    if ($output -match 'CLIProxyAPI Version:\s*v?([0-9]+(?:\.[0-9]+){1,3})') {
        return [version]$Matches[1]
    }

    return $null
}

function Stop-InstalledProcess {
    # Trust the PID only after verifying that it still belongs to CLIProxyAPI.
    if (-not (Test-Path -LiteralPath $pidFile -PathType Leaf)) {
        return
    }

    $processIdText = (Get-Content -LiteralPath $pidFile -TotalCount 1).Trim()
    if ($processIdText -notmatch '^\d+$') {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        return
    }

    $process = Get-Process -Id ([int]$processIdText) -ErrorAction SilentlyContinue
    if (-not $process -or $process.ProcessName -ne 'cli-proxy-api') {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Host "Stopping CLIProxyAPI PID $processIdText for update..."
    & taskkill.exe /PID $processIdText /T /F
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stop CLIProxyAPI PID $processIdText. taskkill exit code: $LASTEXITCODE"
    }

    [void]$process.WaitForExit(10000)
    if (-not $process.HasExited) {
        throw "CLIProxyAPI PID $processIdText did not stop within 10 seconds."
    }

    Remove-Item -LiteralPath $pidFile -Force
}

$tempDir = $null
$backupPath = $null
$binaryReplaced = $false

try {
    # Resolve the expected Windows AMD64 asset from the latest official release.
    Write-Host 'Checking CLIProxyAPI updates...'
    $release = Invoke-RestMethod -Uri $releaseApi -Headers $headers
    $latestVersionText = ([string]$release.tag_name).TrimStart('v')
    $latestVersion = [version]$latestVersionText
    $installedVersion = Get-InstalledVersion

    if ($installedVersion -and $installedVersion -ge $latestVersion) {
        Write-Host "CLIProxyAPI is up to date: v$installedVersion"
        exit 0
    }

    $assetName = "CLIProxyAPI_${latestVersionText}_windows_amd64.zip"
    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    $checksumAsset = $release.assets | Where-Object { $_.name -eq 'checksums.txt' } | Select-Object -First 1
    if (-not $asset -or -not $checksumAsset) {
        throw "Release v$latestVersion does not contain $assetName or checksums.txt."
    }

    $currentLabel = if ($installedVersion) { "v$installedVersion" } else { 'unknown version' }
    Write-Host "Updating CLIProxyAPI from $currentLabel to v$latestVersion..."

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cliproxyapi-update-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    $archivePath = Join-Path $tempDir $assetName
    $checksumsPath = Join-Path $tempDir 'checksums.txt'
    $extractDir = Join-Path $tempDir 'extracted'

    # Download both the release archive and the publisher-provided checksum list.
    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $archivePath
    Invoke-WebRequest -Uri $checksumAsset.browser_download_url -Headers $headers -OutFile $checksumsPath

    $escapedAssetName = [regex]::Escape($assetName)
    $checksumLine = Get-Content -LiteralPath $checksumsPath | Where-Object {
        $_ -match "^([A-Fa-f0-9]{64})\s+\*?$escapedAssetName$"
    } | Select-Object -First 1
    if (-not $checksumLine -or $checksumLine -notmatch '^([A-Fa-f0-9]{64})') {
        throw "Could not find the SHA-256 checksum for $assetName."
    }

    $expectedHash = $Matches[1].ToUpperInvariant()
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "Checksum mismatch for $assetName."
    }

    # Extract to a temporary directory before touching the installed executable.
    New-Item -ItemType Directory -Path $extractDir | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir
    $newBinary = Get-ChildItem -LiteralPath $extractDir -Filter 'cli-proxy-api.exe' -File -Recurse | Select-Object -First 1
    if (-not $newBinary) {
        throw 'The downloaded archive does not contain cli-proxy-api.exe.'
    }

    Stop-InstalledProcess
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Preserve the current binary so a failed update can be rolled back safely.
    if (Test-Path -LiteralPath $binaryPath -PathType Leaf) {
        $backupPath = Join-Path $backupDir 'cli-proxy-api.previous.exe'
        Copy-Item -LiteralPath $binaryPath -Destination $backupPath -Force

        # Keep only the version that was installed immediately before this update.
        Get-ChildItem -LiteralPath $backupDir -Filter 'cli-proxy-api*.exe' -File |
            Where-Object { $_.FullName -ne $backupPath } |
            Remove-Item -Force
    }

    Copy-Item -LiteralPath $newBinary.FullName -Destination $binaryPath -Force
    $binaryReplaced = $true

    # Execute the replacement to ensure it reports the version that was requested.
    $updatedVersion = Get-InstalledVersion
    if (-not $updatedVersion -or $updatedVersion -ne $latestVersion) {
        throw "Updated binary version verification failed. Expected v$latestVersion, got v$updatedVersion."
    }

    Write-Host "CLIProxyAPI updated successfully to v$updatedVersion."
    if ($backupPath) {
        Write-Host "Backup: $backupPath"
    }
}
catch {
    Write-Warning "CLIProxyAPI update failed: $($_.Exception.Message)"

    # Restore the previous executable only when replacement had already occurred.
    if ($binaryReplaced -and $backupPath -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
        try {
            Copy-Item -LiteralPath $backupPath -Destination $binaryPath -Force
            Write-Warning 'The previous CLIProxyAPI executable was restored.'
        }
        catch {
            Write-Error "Rollback failed: $($_.Exception.Message)"
        }
    }

    exit 1
}
finally {
    # Temporary downloads and extracted files are never retained after the run.
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
