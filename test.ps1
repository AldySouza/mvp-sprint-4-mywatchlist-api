# Roda os testes da API localmente no Windows: garante o Python (instala se
# faltar), prepara a .venv (mesma logica do start.ps1), instala as deps de dev
# e roda o pytest. Argumentos extras vao direto pro pytest
# (ex.: .\test.ps1 tests\contract -v).
$pytestArgs = $args

. "$PSScriptRoot\start.ps1"
$python = Initialize-Python
Initialize-Venv $python

Write-Host "==> Instalando dependencias de teste..."
& $venvPython -m pip install --disable-pip-version-check -q -r requirements-dev.txt
if ($LASTEXITCODE -ne 0) { Fail "falha ao instalar as dependencias de teste (veja a mensagem acima)." }

Write-Host "==> Rodando os testes..."
& $venvPython -m pytest @pytestArgs
exit $LASTEXITCODE
