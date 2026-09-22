#!/usr/bin/env bash
# Builda e sobe a API via Docker (standalone). Se for rodar junto com o
# front-end, use mywatchlist-front/start.sh, que orquestra os dois via
# docker compose.
set -euo pipefail

cd "$(dirname "$0")"

wait_for_docker() {
  local tries=0
  until docker info >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -gt 30 ]; then
      echo "Docker não respondeu a tempo. Abra o Docker Desktop manualmente e rode este script de novo." >&2
      exit 1
    fi
    sleep 2
  done
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker não encontrado. Instale em https://docs.docker.com/get-docker/ e rode este script de novo." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker não está rodando. Tentando iniciar..."
  if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Docker.app" ]; then
    open -a Docker
  elif command -v systemctl >/dev/null 2>&1; then
    systemctl start docker 2>/dev/null || sudo systemctl start docker 2>/dev/null || true
  fi
  echo "Aguardando o Docker iniciar (pode levar até 1 minuto na primeira vez)..."
  wait_for_docker
fi

PORT="${PORT:-8000}"
IMAGE="mywatchlist-api"

echo "Buildando imagem Docker..."
docker build -t "$IMAGE" .

echo "API disponível em http://localhost:${PORT}/docs"
exec docker run --rm -p "${PORT}:8000" -v mywatchlist-data:/app/data "$IMAGE"
