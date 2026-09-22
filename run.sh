#!/usr/bin/env bash
# Sobe a API MyWatchList localmente sem Docker: cria venv, instala deps, roda uvicorn.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo "Criando venv..."
  python3 -m venv .venv
fi

source .venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements-dev.txt

echo "API em http://localhost:8000 (Swagger UI em /docs). Ctrl+C para parar."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
