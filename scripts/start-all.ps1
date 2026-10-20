﻿$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Test-Port([int]$Port) {
  return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}
function Wait-Port([int]$Port, [int]$TimeoutSeconds = 120) {
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Port $Port) { return $true }
    Start-Sleep -Seconds 1
  }
  return $false
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        RepoMind 一键启动" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "[1/4] 等待 Docker 引擎并启动基础设施 ..." -ForegroundColor Yellow
$dockerDesktop = 'C:\Users\yangwei\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe'
$dockerReady = $false
for ($i = 0; $i -lt 90; $i++) {
  docker info *> $null
  if ($LASTEXITCODE -eq 0) { $dockerReady = $true; break }
  if ($i -eq 0 -and (Test-Path $dockerDesktop)) {
    Write-Host "      Docker 未就绪，正在启动 Docker Desktop ..." -ForegroundColor Gray
    Start-Process -FilePath $dockerDesktop
  }
  Start-Sleep -Seconds 2
}
if (-not $dockerReady) { throw 'Docker 引擎未就绪：请先打开 Docker Desktop，等待状态变为 Running 后重试。' }
docker compose up -d postgres etcd milvus | Out-Host
if (-not (Wait-Port 5432 120)) { throw 'PostgreSQL 未就绪（5432 未监听）' }
if (-not (Wait-Port 19530 120)) { throw 'Milvus 未就绪（19530 未监听）' }
Write-Host "      PostgreSQL / Milvus OK" -ForegroundColor Green

Write-Host "[2/4] 检查 Ollama (11434) ..." -ForegroundColor Yellow
if (-not (Test-Port 11434)) {
  & (Join-Path $PSScriptRoot 'start-ollama.ps1')
  for ($i = 0; $i -lt 30; $i++) { Start-Sleep -Milliseconds 500; if (Test-Port 11434) { break } }
}
if (-not (Test-Port 11434)) { throw 'Ollama 启动失败：11434 未监听' }
Write-Host "      Ollama OK" -ForegroundColor Green

Write-Host "[3/4] 检查后端 (8001) ..." -ForegroundColor Yellow
if (-not (Test-Port 8001)) {
  & (Join-Path $PSScriptRoot 'start-backend.ps1')
  for ($i = 0; $i -lt 60; $i++) { Start-Sleep -Milliseconds 500; if (Test-Port 8001) { break } }
}
if (-not (Test-Port 8001)) { throw '后端启动失败：8001 未监听' }
Write-Host "      后端 OK" -ForegroundColor Green

Write-Host "[4/4] 检查前端 (3000) ..." -ForegroundColor Yellow
if (-not (Test-Port 3000)) {
  $out = Join-Path $root '.data\frontend.out.log'
  $err = Join-Path $root '.data\frontend.err.log'
  $npm = (Get-Command npm.cmd).Source
  $p = Start-Process -FilePath $npm -ArgumentList 'run start -- -p 3000' -WorkingDirectory (Join-Path $root 'frontend') -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden -PassThru
  Set-Content -Path (Join-Path $root '.data\frontend.pid') -Value $p.Id
  for ($i = 0; $i -lt 120; $i++) { Start-Sleep -Milliseconds 500; if (Test-Port 3000) { break } }
}
if (-not (Test-Port 3000)) { throw '前端启动失败：3000 未监听' }
Write-Host "      前端 OK" -ForegroundColor Green

Start-Sleep -Seconds 2
Write-Host ""
Write-Host "启动完成！" -ForegroundColor Green
Write-Host "  前端页面 : http://localhost:3000"
Write-Host "  后端文档 : http://localhost:8001/docs"
Write-Host "  健康检查 : http://localhost:8001/health"
Write-Host ""
Start-Process "http://localhost:3000"