$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        RepoMind 停止" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "[1/2] 停止后端 ..." -ForegroundColor Yellow
& (Join-Path $PSScriptRoot 'stop-backend.ps1')

Write-Host "[2/2] 停止前端 ..." -ForegroundColor Yellow
$conns = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
foreach ($c in $conns) {
  taskkill /F /T /PID $c.OwningProcess | Out-Null
  Write-Host "      stopped frontend pid=$($c.OwningProcess)" -ForegroundColor Green
}
if (-not $conns) { Write-Host "      前端未运行" -ForegroundColor Gray }

Write-Host ""
Write-Host "已停止后端与前端。" -ForegroundColor Green
Write-Host "PostgreSQL / etcd / Milvus 与 Ollama 保持运行（下次启动更快）。"
Write-Host "如需彻底停止基础设施：docker compose stop"
Write-Host "如需停止 Ollama：taskkill /IM ollama.exe /F"
