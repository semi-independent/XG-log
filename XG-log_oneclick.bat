@echo off
setlocal
set "REPO=C:\XG\repo\XG-log"

call "%REPO%\XG-log_collect_to_drop.bat"
if errorlevel 1 exit /b 1

call "%REPO%\XG-log_cleanup_local.bat"
if errorlevel 1 exit /b 1

call "%REPO%\XG-log_send.bat"
exit /b %errorlevel%