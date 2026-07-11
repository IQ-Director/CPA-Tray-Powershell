#Requires -Version 5.1

<#
.SYNOPSIS
    Restarts CLIProxyAPI through the existing stop and start scripts.
.DESCRIPTION
    Runs stop.bat first and waits for it to finish, then runs start.bat. The
    start script performs the normal update check before starting the service.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stopScript = Join-Path $baseDir 'stop.bat'
$startScript = Join-Path $baseDir 'start.bat'

if (Test-Path -LiteralPath $stopScript -PathType Leaf) {
    & $stopScript *> $null
}

if (-not (Test-Path -LiteralPath $startScript -PathType Leaf)) {
    exit 1
}

& $startScript *> $null
exit $LASTEXITCODE
