@echo off
rem Atalho para test.ps1 (que faz todo o trabalho): funciona com duplo clique
rem e sem precisar mudar a politica de execucao do PowerShell.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test.ps1" %*
if errorlevel 1 pause
