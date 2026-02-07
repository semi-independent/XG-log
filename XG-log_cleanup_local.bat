@echo off
setlocal
set "REPO=C:\XG\repo\XG-log"
set "ARCH=%REPO%\archive"
set "RESULTS=C:\Users\Administrator\Desktop\XG_Results_ToSend"

REM archive folder (date-stamped) remove older than 30 days
forfiles /p "%ARCH%" /d -30 /c "cmd /c if @isdir==TRUE rmdir /s /q @path" 2>nul

REM results folder files remove older than 7 days
forfiles /p "%RESULTS%" /s /d -7 /c "cmd /c del /f /q @path" 2>nul

endlocal
exit /b 0