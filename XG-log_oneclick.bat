@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "REPO=C:\XG\repo\XG-log"

call "%REPO%\XG-log_collect_to_drop.bat"
if errorlevel 1 (
  echo [ONECLICK] collect failed. Check _collect.log
  pause
  exit /b 1
)

call "%REPO%\XG-log_send.bat"
if errorlevel 1 (
  echo [ONECLICK] send failed. Check _send.log
  pause
  exit /b 1
)

echo [ONECLICK] done.
endlocal
exit /b 0
