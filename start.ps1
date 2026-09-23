# Sobe a API MyWatchList num Windows sem nada pre-instalado.
#
# Verifica (e instala, se faltar) o Python na versao certa e o Docker.
# Com o Docker rodando, sobe a API num container; se o Docker nao ficar
# pronto (ex.: recem-instalado e pedindo reinicializacao), sobe com Python local.
#
#   .\start.ps1           Docker, ou Python local como alternativa
#   .\start.ps1 -Local    direto com Python local, sem Docker
#
# Para subir front + API juntos, use mywatchlist-front\start.ps1.
param([switch]$Local)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Set-Location -Path $PSScriptRoot

$port = if ($env:PORT) { [int]$env:PORT } else { 8000 }
$image = "mywatchlist-api"
$venvPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
# pydantic 2.9 / fastapi 0.115 tem wheels prontos do Python 3.10 ao 3.13.
$pyVersionCheck = "import sys; sys.exit(0 if (3, 10) <= sys.version_info[:2] <= (3, 13) else 1)"
$dockerDesktop = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
$dockerBin = "$env:ProgramFiles\Docker\Docker\resources\bin"

function Fail($message) {
    Write-Host "Erro: $message" -ForegroundColor Red
    exit 1
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    if (Test-Path $dockerBin) { $env:Path += ";$dockerBin" }
}

# ---------------------------------------------------------------- Python

# Retorna o caminho do python.exe se o comando existir e for compativel.
function Resolve-Python([string[]]$cmd) {
    if (-not (Get-Command $cmd[0] -ErrorAction SilentlyContinue)) { return $null }
    $cmdArgs = @($cmd | Select-Object -Skip 1)
    try {
        $exe = & $cmd[0] @cmdArgs -c "$pyVersionCheck; import venv, ensurepip; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $exe) { return "$exe".Trim() }
    } catch {}
    return $null
}

function Find-Python {
    $candidates = @(
        @("py", "-3.12"), @("py", "-3.13"), @("py", "-3.11"), @("py", "-3.10"),
        @("python"), @("python3"),
        @("$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"),
        @("$env:ProgramFiles\Python312\python.exe")
    )
    foreach ($c in $candidates) {
        $exe = Resolve-Python $c
        if ($exe) { return $exe }
    }
    return $null
}

function Install-Python {
    Write-Host "    Python 3.10-3.13 nao encontrado. Instalando Python 3.12 (so na primeira vez)..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements | Out-Host
    }
    if (-not (Find-Python)) {
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
        $installer = Join-Path $env:TEMP "python-3.12.10-$arch.exe"
        Write-Host "    Baixando instalador do Python..."
        Invoke-WebRequest "https://www.python.org/ftp/python/3.12.10/python-3.12.10-$arch.exe" -OutFile $installer
        Start-Process -Wait -FilePath $installer -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_launcher=1"
    }
    Update-SessionPath
    $exe = Find-Python
    if (-not $exe) { Fail "nao consegui instalar o Python. Instale o Python 3.12 em https://www.python.org/downloads/ e rode este script de novo." }
    return $exe
}

# Livre = ninguem escutando nela.
function Test-PortFree([int]$p) {
    $client = [Net.Sockets.TcpClient]::new()
    try { return -not $client.ConnectAsync("127.0.0.1", $p).Wait(1000) } catch { return $true } finally { $client.Dispose() }
}

# ---------------------------------------------------------------- Docker

function Test-DockerRunning {
    try { docker info *> $null; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

function Install-Docker {
    Write-Host "    Docker nao encontrado. Instalando o Docker Desktop (so na primeira vez; o Windows vai pedir permissao de administrador)..."
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install -e --id Docker.DockerDesktop --silent --accept-package-agreements --accept-source-agreements | Out-Host
        } else {
            $installer = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
            $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
            Write-Host "    Baixando instalador do Docker Desktop..."
            Invoke-WebRequest "https://desktop.docker.com/win/main/$arch/Docker%20Desktop%20Installer.exe" -OutFile $installer
            Start-Process -Wait -Verb RunAs -FilePath $installer -ArgumentList "install", "--quiet", "--accept-license"
        }
    } catch {
        return $false
    }
    Update-SessionPath
    return [bool](Get-Command docker -ErrorAction SilentlyContinue)
}

# Retorna $true se, no fim, o Docker estiver instalado e rodando.
function Initialize-Docker {
    Update-SessionPath
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if (-not (Install-Docker)) { Write-Host "    Nao consegui instalar o Docker."; return $false }
    }
    if (Test-DockerRunning) { return $true }

    Write-Host "    Docker nao esta rodando. Tentando iniciar o Docker Desktop..."
    if (Test-Path $dockerDesktop) { Start-Process $dockerDesktop }
    Write-Host "    Aguardando o Docker iniciar (ate 2 min; na primeira vez, aceite os termos na janela do Docker Desktop)..."
    for ($i = 0; $i -lt 60; $i++) {
        if (Test-DockerRunning) { return $true }
        Start-Sleep -Seconds 2
    }
    Write-Host "    Se o Docker acabou de ser instalado, talvez seja preciso reiniciar o computador."
    return $false
}

# ---------------------------------------------------------------- Execucao

function Start-WithDocker {
    Write-Host "==> Buildando a imagem Docker..."
    docker build -t $image .
    if ($LASTEXITCODE -ne 0) { Fail "falha no build da imagem Docker (veja a mensagem acima)." }
    Write-Host ""
    Write-Host "API disponivel em http://localhost:$port/docs - Ctrl+C para parar."
    docker run --rm -p "${port}:8000" -v mywatchlist-data:/app/data $image
    exit $LASTEXITCODE
}

# Cria/valida a .venv e instala requirements.txt nela (usado tambem por test.ps1).
function Initialize-Venv($python) {
    Write-Host "==> Preparando ambiente virtual (.venv)..."
    if (Test-Path .venv) {
        $venvOk = $false
        if (Test-Path $venvPython) {
            try { & $venvPython -c $pyVersionCheck 2>$null; $venvOk = ($LASTEXITCODE -eq 0) } catch {}
        }
        if (-not $venvOk) {
            Write-Host "    .venv existente esta quebrado ou com Python incompativel; recriando."
            Remove-Item -Recurse -Force .venv
        }
    }
    if (-not (Test-Path .venv)) {
        & $python -m venv .venv
        if ($LASTEXITCODE -ne 0) { Fail "nao consegui criar o ambiente virtual." }
    }

    Write-Host "==> Instalando dependencias..."
    $stamp = ".venv\.installed-requirements.txt"
    if ((Test-Path $stamp) -and ((Get-FileHash requirements.txt).Hash -eq (Get-FileHash $stamp).Hash)) {
        Write-Host "    Dependencias ja instaladas."
    } else {
        & $venvPython -m pip install --disable-pip-version-check -q --upgrade pip
        & $venvPython -m pip install --disable-pip-version-check -q -r requirements.txt
        if ($LASTEXITCODE -ne 0) { Fail "falha ao instalar as dependencias (veja a mensagem acima)." }
        Copy-Item requirements.txt $stamp
    }
}

function Start-Local($python) {
    Initialize-Venv $python
    Write-Host ""
    Write-Host "API disponivel em http://localhost:$port/docs - Ctrl+C para parar."
    & $venvPython -m uvicorn app.main:app --host 127.0.0.1 --port $port
    exit $LASTEXITCODE
}

function Initialize-Python {
    Write-Host "==> Verificando Python..."
    $python = Find-Python
    if (-not $python) { $python = Install-Python }
    Write-Host "    OK: $python"
    return $python
}

# Carregado via dot-source (test.ps1): so define as funcoes.
if ($MyInvocation.InvocationName -eq ".") { return }

$python = Initialize-Python

if (-not (Test-PortFree $port)) {
    Fail "a porta $port ja esta em uso. Feche o programa que a usa (talvez a API ja esteja rodando) ou defina outra porta: `$env:PORT=9000; .\start.ps1"
}

if (-not $Local) {
    Write-Host "==> Verificando Docker..."
    if (Initialize-Docker) {
        Write-Host "    OK: Docker rodando."
        Start-WithDocker
    }
    Write-Host "    Docker indisponivel agora; seguindo com Python local."
}
Start-Local $python
