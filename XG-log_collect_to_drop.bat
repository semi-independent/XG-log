@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "TERM_ROOT=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"

REM Desktop “Results folder”
set "RESULTS=C:\Users\Administrator\Desktop\XG_Results_ToSend"

REM Collect time range (days) for LOGS only
set "DAYS=2"

REM Log
set "RUNID=%RANDOM%%RANDOM%"
set "LOG=%TEMP%\xg_collect_%RUNID%.log"
set "FINALLOG=%REPO%\_collect.log"
set "META=%TEMP%\xg_collect_meta_%RUNID%.txt"

echo ================================================== >> "%LOG%"
echo [COLLECT] [%date% %time%] START >> "%LOG%"
echo [COLLECT] TERM_ROOT=%TERM_ROOT% >> "%LOG%"
echo [COLLECT] DAYS=%DAYS% >> "%LOG%"

if not exist "%DROP%\" mkdir "%DROP%" >nul 2>nul

call :resolve_active_mt5
if errorlevel 1 (
  echo [COLLECT] NG: active MT5 terminal not found >> "%LOG%"
  goto :finalize
)

REM ----- 0) drop の古い結果を先に掃除（混在防止） -----
del /q "%DROP%\RSLT_*" >nul 2>nul

REM ----- 1) 操作ログ (MT5\logs) -----
call :collect_recent "%MT5%\logs" "*.log" "OPS_"

REM ----- 2) エキスパートログ (MT5\MQL5\Logs) -----
call :collect_recent "%MT5%\MQL5\Logs" "*.log" "EA_"

REM ----- 3) 口座履歴HTML・画像（RESULTSは“全部”集める：取りこぼし防止） -----
call :collect_all "%RESULTS%" "*.html" "RSLT_"
call :collect_all "%RESULTS%" "*.htm"  "RSLT_"
call :collect_all "%RESULTS%" "*.png"  "RSLT_"
call :collect_all "%RESULTS%" "*.jpg"  "RSLT_"
call :collect_all "%RESULTS%" "*.jpeg" "RSLT_"

:finalize
echo [COLLECT] [%date% %time%] END >> "%LOG%"
type "%LOG%" >> "%FINALLOG%" 2>nul
if errorlevel 1 (
  echo [COLLECT] WARN: final log is locked. temp log kept: %LOG%
) else (
  del /q "%LOG%" >nul 2>nul
)
del /q "%META%" >nul 2>nul
endlocal
exit /b 0

REM ====== SUB ======
:resolve_active_mt5
if not exist "%TERM_ROOT%\" (
  echo [COLLECT] missing TERM_ROOT: %TERM_ROOT% >> "%LOG%"
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root='%TERM_ROOT%';" ^
  "$cand=Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {" ^
  "  $opsDir=Join-Path $_.FullName 'logs';" ^
  "  $ops=Get-ChildItem -Path $opsDir -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "  if($ops){[PSCustomObject]@{Id=$_.Name;Path=$_.FullName;OpsName=$ops.Name;OpsTime=$ops.LastWriteTime;OpsSize=$ops.Length}}" ^
  "} | Sort-Object OpsTime -Descending;" ^
  "if(-not $cand){exit 3};" ^
  "$sel=$cand | Select-Object -First 1;" ^
  "$eaDir=Join-Path $sel.Path 'MQL5\Logs';" ^
  "$ea=Get-ChildItem -Path $eaDir -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "$eaName='';$eaTime='';$eaSize=0;" ^
  "if($ea){$eaName=$ea.Name;$eaTime=$ea.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss');$eaSize=$ea.Length};" ^
  "$opsTime=$sel.OpsTime.ToString('yyyy-MM-dd HH:mm:ss');" ^
  "'{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}' -f $sel.Id,$sel.Path,$sel.OpsName,$opsTime,$sel.OpsSize,$eaName,$eaTime,$eaSize" > "%META%" 2>nul

if errorlevel 1 (
  echo [COLLECT] powershell scan failed >> "%LOG%"
  exit /b 1
)

if not exist "%META%" (
  echo [COLLECT] meta missing after scan >> "%LOG%"
  exit /b 1
)

for /f "usebackq tokens=1-8 delims=|" %%A in ("%META%") do (
  set "TERM_ID=%%A"
  set "MT5=%%B"
  set "OPS_LATEST=%%C"
  set "OPS_TIME=%%D"
  set "OPS_SIZE=%%E"
  set "EA_LATEST=%%F"
  set "EA_TIME=%%G"
  set "EA_SIZE=%%H"
)

if not defined MT5 (
  echo [COLLECT] failed to parse active terminal metadata >> "%LOG%"
  exit /b 1
)

echo [COLLECT] ACTIVE_ID=!TERM_ID! >> "%LOG%"
echo [COLLECT] ACTIVE_MT5=!MT5! >> "%LOG%"
echo [COLLECT] OPS_LATEST=!OPS_LATEST! time=!OPS_TIME! size=!OPS_SIZE! >> "%LOG%"
echo [COLLECT] EA_LATEST=!EA_LATEST! time=!EA_TIME! size=!EA_SIZE! >> "%LOG%"
if "!OPS_SIZE!"=="0" echo [COLLECT] WARN: latest OPS log size is 0 >> "%LOG%"
if "!EA_SIZE!"=="0" echo [COLLECT] WARN: latest EA log size is 0 >> "%LOG%"
exit /b 0

:collect_recent
set "SRC=%~1"
set "MASK=%~2"
set "PFX=%~3"

if not exist "%SRC%\" (
  echo [COLLECT] missing: %SRC% >> "%LOG%"
  exit /b 0
)

forfiles /p "%SRC%" /m "%MASK%" /d -%DAYS% /c "cmd /c echo @path" 2>nul > "%TEMP%\_xg_collect_list.txt"

for /f "usebackq delims=" %%F in ("%TEMP%\_xg_collect_list.txt") do (
  set "FN=%%~nxF"
  copy /y "%%~fF" "%DROP%\%PFX%!FN!" >nul 2>nul
)

echo [COLLECT] ok(recent): %SRC%\%MASK% -> drop (%PFX%) >> "%LOG%"
del /q "%TEMP%\_xg_collect_list.txt" >nul 2>nul
exit /b 0


:collect_all
set "SRC=%~1"
set "MASK=%~2"
set "PFX=%~3"

if not exist "%SRC%\" (
  echo [COLLECT] missing: %SRC% >> "%LOG%"
  exit /b 0
)

for /f "delims=" %%F in ('dir /b /a:-d "%SRC%\%MASK%" 2^>nul') do (
  copy /y "%SRC%\%%F" "%DROP%\%PFX%%%F" >nul 2>nul
)

echo [COLLECT] ok(all): %SRC%\%MASK% -> drop (%PFX%) >> "%LOG%"
exit /b 0
