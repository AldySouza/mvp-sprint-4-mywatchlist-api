#!/usr/bin/env bash
# Sobe a API MyWatchList num computador sem nada pré-instalado.
#
# Verifica (e instala, se faltar) o Python na versão certa e o Docker.
# Com o Docker rodando, sobe a API num container; se o Docker não ficar
# pronto (ex.: recém-instalado e pedindo logout/login), sobe com Python local.
#
#   ./start.sh           Docker, ou Python local como alternativa
#   ./start.sh --local   direto com Python local, sem Docker
#
# Para subir front + API juntos, use mvp-sprint-4-mywatchlist-front/start.sh.
set -euo pipefail

cd "$(dirname "$0")"

PORT="${PORT:-8000}"
IMAGE="mywatchlist-api"
# pydantic 2.9 / fastapi 0.115 têm wheels prontos do Python 3.10 ao 3.13.
PY_VERSION_CHECK='import sys; sys.exit(0 if (3, 10) <= sys.version_info[:2] <= (3, 13) else 1)'
PY_MAC_PKG="https://www.python.org/ftp/python/3.12.10/python-3.12.10-macos11.pkg"
DOCKER_APP_BIN="/Applications/Docker.app/Contents/Resources/bin"

fail() {
  echo "Erro: $*" >&2
  exit 1
}

sudo_cmd() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# ---------------------------------------------------------------- Python

python_ok() {
  "$1" -c "$PY_VERSION_CHECK; import venv, ensurepip" >/dev/null 2>&1
}

find_python() {
  local c p
  for c in python3.12 python3.13 python3.11 python3.10 python3 python \
    /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12 \
    /Library/Frameworks/Python.framework/Versions/3.12/bin/python3; do
    p="$(command -v "$c" 2>/dev/null)" || continue
    # No macOS sem Xcode CLT, /usr/bin/python3 é só um atalho que abre um instalador.
    if [ "$p" = "/usr/bin/python3" ] && [ "$(uname -s)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
      continue
    fi
    if python_ok "$p"; then
      PYTHON="$p"
      return 0
    fi
  done
  return 1
}

install_python() {
  echo "    Python 3.10–3.13 não encontrado. Instalando Python 3.12 (só na primeira vez)..."
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install python@3.12
      else
        local pkg
        pkg="$(mktemp -d)/python.pkg"
        curl -fL --progress-bar -o "$pkg" "$PY_MAC_PKG"
        echo "    O instalador do Python precisa da sua senha de administrador."
        sudo installer -pkg "$pkg" -target /
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo_cmd apt-get update
        sudo_cmd apt-get install -y python3.12 python3.12-venv \
          || sudo_cmd apt-get install -y python3 python3-venv
      elif command -v dnf >/dev/null 2>&1; then
        sudo_cmd dnf install -y python3.12 || sudo_cmd dnf install -y python3
      elif command -v yum >/dev/null 2>&1; then
        sudo_cmd yum install -y python3
      elif command -v pacman >/dev/null 2>&1; then
        sudo_cmd pacman -Sy --noconfirm python
      elif command -v zypper >/dev/null 2>&1; then
        sudo_cmd zypper install -y python312 || sudo_cmd zypper install -y python3
      elif command -v apk >/dev/null 2>&1; then
        sudo_cmd apk add python3
      else
        fail "não sei instalar Python nesta distribuição. Instale o Python 3.12 (https://www.python.org/downloads/) e rode este script de novo."
      fi
      ;;
    *)
      fail "sistema não suportado por este script. No Windows, use start.bat ou start.ps1."
      ;;
  esac
  hash -r
  find_python || fail "o Python instalado não é compatível (precisa ser 3.10 a 3.13). Instale o Python 3.12 em https://www.python.org/downloads/ e rode este script de novo."
}

port_free() {
  # Livre = ninguém escutando nela (bind falharia com conexões antigas em TIME_WAIT).
  ! "$PYTHON" -c 'import socket, sys; socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=1)' "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------- Docker

add_docker_app_to_path() {
  # O Docker Desktop só cria o atalho em /usr/local/bin na primeira abertura.
  if [ -d "$DOCKER_APP_BIN" ]; then PATH="$PATH:$DOCKER_APP_BIN"; fi
}

docker_running() {
  docker info >/dev/null 2>&1
}

wait_for_docker() {
  local waited=0
  until docker_running; do
    [ "$waited" -ge "$1" ] && return 1
    sleep 2
    waited=$((waited + 2))
  done
}

install_docker() {
  echo "    Docker não encontrado. Instalando (só na primeira vez)..."
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install --cask docker || return 1
      else
        local arch dmg mnt rc=0
        arch="$([ "$(uname -m)" = "arm64" ] && echo arm64 || echo amd64)"
        dmg="$(mktemp -d)/Docker.dmg"
        curl -fL --progress-bar -o "$dmg" "https://desktop.docker.com/mac/main/$arch/Docker.dmg" || return 1
        mnt="$(mktemp -d)"
        hdiutil attach -nobrowse -quiet -mountpoint "$mnt" "$dmg" || return 1
        echo "    Copiar o Docker para /Applications precisa da sua senha de administrador."
        sudo cp -R "$mnt/Docker.app" /Applications/ || rc=1
        hdiutil detach -quiet "$mnt" || true
        return "$rc"
      fi
      ;;
    Linux)
      # Script oficial de instalação do Docker Engine + Compose.
      curl -fsSL https://get.docker.com | sudo_cmd sh || return 1
      sudo_cmd systemctl enable --now docker 2>/dev/null || true
      if [ "$(id -u)" -ne 0 ]; then
        sudo usermod -aG docker "$USER" || true
        echo "    Docker instalado. Para usá-lo sem sudo, faça logout/login (ou reinicie) e rode este script de novo."
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

# Retorna 0 se, no fim, o Docker estiver instalado e rodando.
ensure_docker() {
  add_docker_app_to_path
  if ! command -v docker >/dev/null 2>&1; then
    install_docker || { echo "    Não consegui instalar o Docker."; return 1; }
    add_docker_app_to_path
    hash -r
  fi
  docker_running && return 0

  echo "    Docker não está rodando. Tentando iniciar..."
  local timeout=30
  if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Docker.app" ]; then
    open -a Docker
    timeout=120
    echo "    Aguardando o Docker iniciar (até 2 min; na primeira vez, aceite os termos na janela do Docker Desktop)..."
  elif command -v systemctl >/dev/null 2>&1; then
    sudo_cmd systemctl start docker 2>/dev/null || true
  fi
  wait_for_docker "$timeout"
}

# ---------------------------------------------------------------- Execução

run_docker() {
  echo "==> Buildando a imagem Docker..."
  docker build -t "$IMAGE" .
  echo
  echo "API disponível em http://localhost:${PORT}/docs — Ctrl+C para parar."
  exec docker run --rm -p "${PORT}:8000" -v mywatchlist-data:/app/data "$IMAGE"
}

# Cria/valida a .venv e instala requirements.txt nela (usado também por test.sh).
prepare_venv() {
  echo "==> Preparando ambiente virtual (.venv)..."
  if [ -e .venv ] && ! .venv/bin/python -c "$PY_VERSION_CHECK" >/dev/null 2>&1; then
    echo "    .venv existente está quebrado ou com Python incompatível; recriando."
    rm -rf .venv
  fi
  [ -d .venv ] || "$PYTHON" -m venv .venv

  echo "==> Instalando dependências..."
  if cmp -s requirements.txt .venv/.installed-requirements.txt; then
    echo "    Dependências já instaladas."
  else
    .venv/bin/python -m pip install --disable-pip-version-check -q --upgrade pip
    .venv/bin/python -m pip install --disable-pip-version-check -q -r requirements.txt
    cp requirements.txt .venv/.installed-requirements.txt
  fi
}

run_local() {
  prepare_venv
  echo
  echo "API disponível em http://localhost:${PORT}/docs — Ctrl+C para parar."
  exec .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT"
}

ensure_python() {
  echo "==> Verificando Python..."
  find_python || install_python
  echo "    OK: $("$PYTHON" --version) em $PYTHON"
}

# Carregado via `source` (test.sh): só define as funções.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

ensure_python

port_free "$PORT" || fail "a porta $PORT já está em uso. Feche o programa que a usa (talvez a API já esteja rodando) ou use outra porta: PORT=9000 ./start.sh"

if [ "${1:-}" != "--local" ]; then
  echo "==> Verificando Docker..."
  if ensure_docker; then
    echo "    OK: Docker rodando."
    run_docker
  fi
  echo "    Docker indisponível agora; seguindo com Python local."
fi
run_local
