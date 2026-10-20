$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# 已运行则直接返回，避免重复绑定端口
$existing = Get-NetTCPConnection -LocalPort 8001 -State Listen -ErrorAction SilentlyContinue
if ($existing) {
  Write-Output "backend already listening on 8001 (pid $($existing.OwningProcess -join ','))"
  exit 0
}

# 基础设施（幂等；失败不阻塞，后端日志会显示具体连接错误）
Push-Location $root
try { docker compose up -d postgres etcd milvus 2>&1 | Out-Null } catch { Write-Warning "docker compose failed: $($_.Exception.Message)" }
Pop-Location

# Ollama：未监听时自动拉起，等待就绪
$ollama = Get-NetTCPConnection -LocalPort 11434 -State Listen -ErrorAction SilentlyContinue
if (-not $ollama) {
  & (Join-Path $PSScriptRoot 'start-ollama.ps1')
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    if (Get-NetTCPConnection -LocalPort 11434 -State Listen -ErrorAction SilentlyContinue) { break }
  }
  $ollama = Get-NetTCPConnection -LocalPort 11434 -State Listen -ErrorAction SilentlyContinue
  if (-not $ollama) { throw 'Ollama failed to start on port 11434' }
  Write-Output "ollama ready on 11434"
}

$out = Join-Path $root '.data\backend.out.log'
$err = Join-Path $root '.data\backend.err.log'
Remove-Item $out, $err -ErrorAction SilentlyContinue
$python = Join-Path $root 'backend\.venv\Scripts\python.exe'
$p = Start-Process -FilePath $python `
  -ArgumentList '-m uvicorn app.main:app --host 0.0.0.0 --port 8001' `
  -WorkingDirectory (Join-Path $root 'backend') `
  -RedirectStandardOutput $out -RedirectStandardError $err `
  -WindowStyle Hidden -PassThru
Set-Content -Path (Join-Path $root '.data\backend.pid') -Value $p.Id
Write-Output "started backend pid=$($p.Id)"
