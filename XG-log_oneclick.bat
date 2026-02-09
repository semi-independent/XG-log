:: C:\XG\repo\XG-log\XG-log_oneclick.bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"

call "%REPO%\XG-log_collect_to_drop.bat"
if errorlevel 1 exit /b 1

set "EA_SIZE=0"
for /f %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$d='%DROP%'; if(!(Test-Path $d)){exit 2};" ^
  "$f=Get-ChildItem -Path $d -File -Filter 'EA_*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "if(-not $f){exit 3};" ^
  "Write-Output $f.Length"') do set "EA_SIZE=%%S"

if not defined EA_SIZE (
  echo [ONECLICK] NG: EA log not found in drop
  exit /b 2
)

if "%EA_SIZE%"=="0" (
  echo [ONECLICK] NG: EA log size is 0. send aborted.
  exit /b 3
)

call "%REPO%\XG-log_send.bat"
exit /b %errorlevel%
