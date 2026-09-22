@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

where docker >nul 2>nul
if errorlevel 1 (
    echo Docker nao encontrado. Instale em https://docs.docker.com/get-docker/ e rode este script de novo.
    exit /b 1
)

docker info >nul 2>nul
if errorlevel 1 (
    echo Docker nao esta rodando. Tentando iniciar o Docker Desktop...
    if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
        start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
    )
    echo Aguardando o Docker iniciar ^(pode levar ate 1 minuto^)...
    set tries=0
    :waitloop
    timeout /t 2 >nul
    set /a tries+=1
    docker info >nul 2>nul
    if not errorlevel 1 goto ready
    if !tries! GEQ 30 (
        echo Docker nao respondeu a tempo. Abra o Docker Desktop manualmente e rode este script de novo.
        exit /b 1
    )
    goto waitloop
)

:ready
if "%PORT%"=="" set PORT=8000

echo Buildando imagem Docker...
docker build -t mywatchlist-api .

echo API disponivel em http://localhost:%PORT%/docs
docker run --rm -p %PORT%:8000 -v mywatchlist-data:/app/data mywatchlist-api
