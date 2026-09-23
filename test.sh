#!/usr/bin/env bash
# Roda os testes da API localmente: garante o Python (instala se faltar), prepara
# a .venv (mesma lógica do start.sh), instala as deps de dev e roda o pytest.
# Argumentos extras vão direto pro pytest (ex.: ./test.sh tests/contract -v).
set -euo pipefail
cd "$(dirname "$0")"

source ./start.sh
ensure_python
prepare_venv

echo "==> Instalando dependências de teste..."
.venv/bin/python -m pip install --disable-pip-version-check -q -r requirements-dev.txt

echo "==> Rodando os testes..."
exec .venv/bin/python -m pytest "$@"
