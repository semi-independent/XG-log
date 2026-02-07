@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"

REM MT5 Data Folder (fixed in your environment)
set "MT5=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\ED051E4A9BEE8A33BDDD0F947358B2B2"

REM Desktop “Results folder” (rename your folder to this)
set "RESULTS=C:\Users\Administrator\Desktop\XG_Results_ToSend"

REM Collect time range (days). Keep it small to reduce noise.
set "DAYS=2"

REM Log
set "LOG=%REPO%\_collect.log"

REM ====== START ======
echo ================================================== >> "%LOG%"
echo [COLLECT] [%date% %time%] START >> "%LOG%"

if not exist "%DROP%\" mkdir "%DROP%" >nul 2>nul

REM ----- 1) 操作ログ (MT5\logs) -----
call :collect_recent "%MT5%\logs" "*.log" "OPS_"

REM ----- 2) エキスパートログ (MT5\MQL5\Logs) -----
call :collect_recent "%MT5%\MQL5\Logs" "*.log" "EA_"

REM ----- 3) 口座履歴HTML・画像（デスクトップの結果フォルダ） -----
REM html / htm / png / jpg / jpeg
call :collect_recent "%RESULTS%" "*.html" "RSLT_"
call :collect_recent "%RESULTS%" "*.htm"  "RSLT_"
call :collect_recent "%RESULTS%" "*.png"  "RSLT_"
call :collect_recent "%RESULTS%" "*.jpg"  "RSLT_"
call :collect_recent "%RESULTS%" "*.jpeg" "RSLT_"

echo [COLLECT] [%date% %time%] END >> "%LOG%"
endlocal
exit /b 0

REM ====== SUB ======
:collect_recent
set "SRC=%~1"
set "MASK=%~2"
set "PFX=%~3"

if not exist "%SRC%\" (
  echo [COLLECT] missing: %SRC% >> "%LOG%"
  exit /b 0
)

REM pick files modified within DAYS
forfiles /p "%SRC%" /m "%MASK%" /d -%DAYS% /c "cmd /c echo @path" 2>nul > "%TEMP%\_xg_collect_list.txt"

for /f "usebackq delims=" %%F in ("%TEMP%\_xg_collect_list.txt") do (
  REM copy with collision-safe name: prefix + original name
  set "FN=%%~nxF"
  copy /y "%%~fF" "%DROP%\%PFX%!FN!" >nul 2>nul
)

echo [COLLECT] ok: %SRC%\%MASK% -> drop (%PFX%) >> "%LOG%"
exit /b 0