$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$Host.UI.RawUI.WindowTitle = 'RepoMind 控制器 - 关闭此窗口即停止项目'

$lock = Join-Path $root '.data\controller.pid'
if (Test-Path $lock) {
  $oldPid = (Get-Content $lock | Select-Object -First 1).Trim()
  if ($oldPid -match '^\d+$' -and (Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue)) {
    Write-Host "RepoMind 控制器已在运行 (pid=$oldPid)。" -ForegroundColor Yellow
    Start-Process 'http://localhost:3000'
    Start-Sleep -Seconds 3
    exit 0
  }
}
Set-Content -Path $lock -Value $PID

$watchdog = Join-Path $PSScriptRoot 'repomind-watchdog.ps1'
$watchdogArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdog`" -LauncherPid $PID"
Start-Process -FilePath 'powershell.exe' -ArgumentList $watchdogArgs -WindowStyle Hidden

try {
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host "        RepoMind 一键打开" -ForegroundColor Cyan
  Write-Host "==========================================" -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot 'start-all.ps1')

  Write-Host ""
  Write-Host "项目已启动，浏览器已打开。" -ForegroundColor Green
  Write-Host "访问地址: http://localhost:3000" -ForegroundColor Green
  Write-Host ""
  Write-Host "==========================================" -ForegroundColor Yellow
  Write-Host "  关闭此窗口 = 停止后端与前端" -ForegroundColor Yellow
  Write-Host "  保持窗口打开 = 项目持续运行" -ForegroundColor Yellow
  Write-Host "==========================================" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "日志: .data\backend.out.log / .data\frontend.out.log" -ForegroundColor Gray
  Write-Host ""

  while ($true) {
    Start-Sleep -Seconds 5
  }
}
finally {
  Remove-Item $lock -ErrorAction SilentlyContinue
}
