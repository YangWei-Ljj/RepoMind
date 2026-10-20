# 切换 RepoMind 使用的 LLM 后端：DeepSeek（云端） 或 Ollama（本地）
# 用法：
#   .\switch-llm.ps1 deepseek
#   .\switch-llm.ps1 ollama
# 切换后需重启后端 uvicorn 才会生效。

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("deepseek","ollama")]
    [string]$Mode
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root ".env.$Mode"
$dst = Join-Path $root ".env"

if (-not (Test-Path $src)) {
    Write-Host "未找到 $src" -ForegroundColor Red
    exit 1
}

Copy-Item $src $dst -Force
Write-Host "已切换 LLM -> $Mode" -ForegroundColor Green

# 显示当前生效的 LLM 配置
Select-String -Path $dst -Pattern "^LLM_" | ForEach-Object { Write-Host "  $($_.Line)" }

Write-Host ""
Write-Host "请重启后端 uvicorn 使配置生效。" -ForegroundColor Yellow
