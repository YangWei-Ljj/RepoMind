$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root '.data\ollama.out.log'
$err = Join-Path $root '.data\ollama.err.log'
$exe = 'C:\Users\yangwei\AppData\Local\Programs\Ollama\ollama.exe'
$p = Start-Process -FilePath $exe -ArgumentList 'serve' -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden -PassThru
Set-Content -Path (Join-Path $root '.data\ollama.pid') -Value $p.Id
Write-Output "started ollama pid=$($p.Id)"
