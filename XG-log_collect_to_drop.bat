@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "TERM_ROOT=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
set "RESULTS=C:\Users\Administrator\Desktop\XG_Results_ToSend"
set "TRIM_HOURS=12"

REM ====== LOG SETUP ======
set "RUNID=%RANDOM%%RANDOM%"
set "LOG=%TEMP%\xg_collect_%RUNID%.log"
set "FINALLOG=%REPO%\_collect.log"
set "META=%TEMP%\xg_collect_meta_%RUNID%.txt"

echo ================================================== >> "%LOG%"
echo [COLLECT] [%date% %time%] START >> "%LOG%"
echo [COLLECT] TRIM_HOURS=%TRIM_HOURS% >> "%LOG%"

if not exist "%DROP%\" mkdir "%DROP%" >nul 2>nul

call :resolve_active_mt5
if errorlevel 1 (
  echo [COLLECT] NG: active MT5 terminal not found >> "%LOG%"
  goto :finalize
)

REM ----- 0) clear drop -----
del /q "%DROP%\*" >nul 2>nul

REM ----- 1) OPS logs -----
call :collect_and_trim "%MT5%\logs" "*.log" "OPS_" "1"

REM ----- 2) EA logs -----
call :collect_and_trim "%MT5%\MQL5\Logs" "*.log" "EA_" "1"

REM ----- 3) Results (all) -----
call :collect_all "%RESULTS%" "*.html" "RSLT_"
call :collect_all "%RESULTS%" "*.htm"  "RSLT_"
call :collect_all "%RESULTS%" "*.png"  "RSLT_"
call :collect_all "%RESULTS%" "*.jpg"  "RSLT_"
call :collect_all "%RESULTS%" "*.jpeg" "RSLT_"

:finalize
echo [COLLECT] [%date% %time%] END >> "%LOG%"
type "%LOG%" >> "%FINALLOG%" 2>nul
if not errorlevel 1 del /q "%LOG%" >nul 2>nul
del /q "%META%" >nul 2>nul
endlocal
exit /b 0

REM ====== resolve_active_mt5 ======
:resolve_active_mt5
if not exist "%TERM_ROOT%\" (
  echo [COLLECT] missing TERM_ROOT >> "%LOG%"
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root='%TERM_ROOT%';" ^
  "$cand=Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {" ^
  "  $opsDir=Join-Path $_.FullName 'logs';" ^
  "  $opsAll=Get-ChildItem -Path $opsDir -File -Filter '*.log' -ErrorAction SilentlyContinue;" ^
  "  $opsDate=$opsAll | Where-Object { $_.Name -match '^\d{8}\.log$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "  $ops=if($opsDate){$opsDate}else{$opsAll | Sort-Object LastWriteTime -Descending | Select-Object -First 1};" ^
  "  if($ops){[PSCustomObject]@{Id=$_.Name;Path=$_.FullName;OpsTime=$ops.LastWriteTime;OpsSize=$ops.Length}}" ^
  "} | Sort-Object OpsTime -Descending;" ^
  "if(-not $cand){exit 3};" ^
  "$sel=$cand | Select-Object -First 1;" ^
  "$eaDir=Join-Path $sel.Path 'MQL5\Logs';" ^
  "$eaAll=Get-ChildItem -Path $eaDir -File -Filter '*.log' -ErrorAction SilentlyContinue;" ^
  "$eaDate=$eaAll | Where-Object { $_.Name -match '^\d{8}\.log$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "$ea=if($eaDate){$eaDate}else{$eaAll | Sort-Object LastWriteTime -Descending | Select-Object -First 1};" ^
  "$eaName='';$eaSize=0;" ^
  "if($ea){$eaName=$ea.Name;$eaSize=$ea.Length};" ^
  "'{0}|{1}|{2}|{3}' -f $sel.Id,$sel.Path,$eaName,$eaSize" > "%META%" 2>nul
if errorlevel 1 ( echo [COLLECT] powershell scan failed >> "%LOG%" & exit /b 1 )
if not exist "%META%" ( echo [COLLECT] meta missing >> "%LOG%" & exit /b 1 )
for /f "usebackq tokens=1-4 delims=|" %%A in ("%META%") do (
  set "TERM_ID=%%A"
  set "MT5=%%B"
  set "EA_LATEST=%%C"
  set "EA_SIZE=%%D"
)
if not defined MT5 ( echo [COLLECT] parse failed >> "%LOG%" & exit /b 1 )
echo [COLLECT] ACTIVE=%MT5% EA=%EA_LATEST%(size=%EA_SIZE%) >> "%LOG%"
exit /b 0

REM ====== collect_and_trim: copy recent file then trim to last N hours ======
:collect_and_trim
set "SRC=%~1"
set "MASK=%~2"
set "PFX=%~3"
set "DATED_ONLY=%~4"

if not exist "%SRC%\" ( echo [COLLECT] missing: %SRC% >> "%LOG%" & exit /b 0 )

set "LIST=%TEMP%\_xg_list_%RANDOM%%RANDOM%.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$src='%SRC%';$mask='%MASK%';$dated='%DATED_ONLY%';$hours=[int]%TRIM_HOURS%;" ^
  "$cut=(Get-Date).AddHours(-$hours).Date;" ^
  "Get-ChildItem -Path $src -File -Filter $mask -ErrorAction SilentlyContinue |" ^
  "  Where-Object { $_.LastWriteTime -ge $cut } |" ^
  "  ForEach-Object { if($dated -eq '1'){ if($_.BaseName -notmatch '^\d{8}$'){return} }; $_.FullName }" ^
  "  | Set-Content '%LIST%' -Encoding ascii" 1>nul 2>nul

for /f "usebackq delims=" %%F in ("%LIST%") do (
  set "FN=%%~nxF"
  copy /y "%%~fF" "%DROP%\%PFX%!FN!" >nul 2>nul
  echo [COLLECT] copied: %PFX%!FN! >> "%LOG%"
)
del /q "%LIST%" >nul 2>nul

REM trim drop logs to last TRIM_HOURS
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$drop='%DROP%';$pfx='%PFX%';$hours=[int]%TRIM_HOURS%;" ^
  "$cutoff=(Get-Date).AddHours(-$hours);" ^
  "Get-ChildItem -Path $drop -Filter ($pfx+'*.log') -ErrorAction SilentlyContinue | ForEach-Object {" ^
  "  $f=$_;" ^
  "  if($f.BaseName -notmatch '\d{8}$'){return};" ^
  "  $fd=$Matches[0];" ^
  "  $enc=[System.Text.Encoding]::Unicode;" ^
  "  try{$lines=[System.IO.File]::ReadAllLines($f.FullName,$enc)}catch{return};" ^
  "  if(-not $lines -or $lines.Count -eq 0){return};" ^
  "  $kept=$lines | Where-Object {" ^
  "    if($_ -match '\t(\d{2}:\d{2}:\d{2})[.\t]'){" ^
  "      try{" ^
  "        $dt=[DateTime]::ParseExact($fd+' '+$Matches[1],'yyyyMMdd HH:mm:ss',$null);" ^
  "        return($dt -ge $cutoff)" ^
  "      }catch{return $true}" ^
  "    }; return $true" ^
  "  };" ^
  "  [System.IO.File]::WriteAllLines($f.FullName,$kept,$enc);" ^
  "  Write-Host ('[TRIM] '+$f.Name+' '+$lines.Count+'->'+$kept.Count)" ^
  "}" >> "%LOG%" 2>&1

echo [COLLECT] ok: %SRC% -> drop (%PFX%) >> "%LOG%"
exit /b 0

REM ====== collect_all: copy all files (no trim) ======
:collect_all
set "SRC=%~1"
set "MASK=%~2"
set "PFX=%~3"
if not exist "%SRC%\" ( echo [COLLECT] missing: %SRC% >> "%LOG%" & exit /b 0 )
for /f "delims=" %%F in ('dir /b /a:-d "%SRC%\%MASK%" 2^>nul') do (
  copy /y "%SRC%\%%F" "%DROP%\%PFX%%%F" >nul 2>nul
)
echo [COLLECT] ok(all): %SRC% (%PFX%) >> "%LOG%"
exit /b 0
