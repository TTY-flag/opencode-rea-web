#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  echo '已生成 .env。填写 MODEL_BASE_URL、MODEL_API_KEY、MODEL_ID 后，再运行本脚本。'
  exit 0
fi
[[ -f vendor/ghidra/ghidra_12.1.4_PUBLIC_20260921.zip ]] || {
  echo '请先从 https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip 下载 Ghidra ZIP，按原文件名放到 vendor/ghidra/；无需解压。' >&2
  exit 1
}
command -v docker >/dev/null || { echo '请先安装并启动 Docker。' >&2; exit 1; }
[[ "$(docker info --format '{{.OSType}}')" == linux ]] || { echo '请使用 Docker 的 Linux 容器引擎。' >&2; exit 1; }
docker compose up -d --build --wait --wait-timeout 180
port="$(sed -n 's/^WEB_PORT=//p' .env | tail -n1 | tr -d '\r')"
echo "Web 地址：http://localhost:${port:-4096}"
echo '无需登录。项目目录：/workspace'
