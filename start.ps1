param([switch]$NoBuild)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
Push-Location $projectRoot
try {
  if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.example' -Destination '.env'
    Write-Host '已生成 .env。填写 MODEL_BASE_URL、MODEL_API_KEY、MODEL_ID 后，再运行本脚本。'
    exit 0
  }
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw '请先安装并启动 Docker Desktop。' }
  $engineType = docker info --format '{{.OSType}}'
  if ($LASTEXITCODE -ne 0) { throw 'Docker 未启动，或 Linux 容器引擎不可用。' }
  if ($engineType.Trim() -ne 'linux') { throw '请将 Docker Desktop 切换为 Linux 容器模式。' }
  if ($NoBuild) { docker compose up -d --wait --wait-timeout 180 }
  else { docker compose up -d --build --wait --wait-timeout 180 }
  if ($LASTEXITCODE -ne 0) { throw '启动失败。请运行 docker compose logs app 查看原因。' }
  $port = '4096'
  $binding = '127.0.0.1'
  foreach ($line in Get-Content -LiteralPath '.env') {
    if ($line -match '^WEB_PORT=(.+)$') { $port = $Matches[1].Trim() }
    if ($line -match '^BIND_ADDRESS=(.+)$') { $binding = $Matches[1].Trim() }
  }
  $browserHost = if ($binding -eq '0.0.0.0') { 'localhost' } else { $binding }
  $webUrl = "http://${browserHost}:$port"
  Write-Host "Web 地址：$webUrl"
  Write-Host '无需登录。项目目录：/workspace'
  Start-Process $webUrl
} finally { Pop-Location }
