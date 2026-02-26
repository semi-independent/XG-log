@echo off
REM XG-log_oneclick.bat
REM collect → send を1クリックで実行
REM ※ send後にdropへファイルが残る場合があります（仕様）
setlocal EnableExtensions EnableDelayedExpansion
set "REPO=C:\XG\repo\XG-log"

call "%REPO%\XG-log_collect_to_drop.bat"
if errorlevel 1 (
  echo [ONECLICK] collect failed.
  pause
  exit /b 1
)

call "%REPO%\XG-log_send.bat"
if errorlevel 1 (
  echo [ONECLICK] send failed.
  pause
  exit /b 1
)

echo [ONECLICK] done.
endlocal
exit /b 0