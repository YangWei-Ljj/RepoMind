param([Parameter(Mandatory = $true)][int]$LauncherPid)

$root = Split-Path -Parent $PSScriptRoot
$log = Join-Path $root '.data\controller.log'

Start-Sleep -Seconds 2
while (Get-Process -Id $LauncherPid -ErrorAction SilentlyContinue) {
  Start-Sleep -Seconds 2
}

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') controller pid=$LauncherPid exited; stopping project" |
  Out-File -Append -Encoding ascii $log

& (Join-Path $PSScriptRoot 'stop-all.ps1') *> $null