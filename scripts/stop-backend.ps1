$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$pidFile = Join-Path $root '.data\backend.pid'
if (Test-Path $pidFile) {
  $pidVal = (Get-Content $pidFile | Select-Object -First 1).Trim()
  if ($pidVal -match '^\d+$') {
    $proc = Get-Process -Id ([int]$pidVal) -ErrorAction SilentlyContinue
    if ($proc) {
      taskkill /F /T /PID $pidVal | Out-Null
      Write-Output "stopped backend pid=$pidVal (tree)"
    } else {
      Write-Output "pid $pidVal 已不存在"
    }
  }
  Remove-Item $pidFile -ErrorAction SilentlyContinue
}
# 兜底：按命令行匹配清除残留 uvicorn
$left = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'python' -and $_.CommandLine -match 'uvicorn app\.main:app' }
foreach ($p in $left) { taskkill /F /T /PID $p.ProcessId | Out-Null; Write-Output "killed leftover pid=$($p.ProcessId)" }
