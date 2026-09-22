#!/usr/bin/env bash
# Roda os testes da API localmente: cria venv, instala deps de dev, roda pytest.
# Argumentos extras vão direto pro pytest (ex.: ./test.sh tests/contract -v).
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo "Criando venv..."
  python3 -m venv .venv
fi

source .venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements-dev.txt

exec pytest "$@"
