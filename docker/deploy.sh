#!/usr/bin/env bash
# kkFileView 一键 Docker 部署
# 用法: ./docker/deploy.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Maven 打包..."
mvn -B package -Dmaven.test.skip=true -pl server -am

if ! ls server/target/kkFileView-*.tar.gz >/dev/null 2>&1; then
  echo "错误: 未找到 server/target/kkFileView-*.tar.gz" >&2
  exit 1
fi

echo "==> Docker 构建并启动..."
docker compose up -d --build

echo ""
echo "部署完成: http://localhost:8012/"
echo "查看日志: docker compose logs -f kkfileview"
