# kkFileView 一键 Docker 部署（Windows PowerShell）
# 用法: .\docker\deploy.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "==> Maven 打包..." -ForegroundColor Cyan
mvn -B package "-Dmaven.test.skip=true" -pl server -am
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Tar = Get-ChildItem "server\target\kkFileView-*.tar.gz" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $Tar) {
    Write-Error "未找到 server\target\kkFileView-*.tar.gz，请先确认 mvn package 成功"
}

Write-Host "==> Docker 构建并启动..." -ForegroundColor Cyan
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "部署完成: http://localhost:8012/" -ForegroundColor Green
Write-Host "查看日志: docker compose logs -f kkfileview"
