@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO=C:\XG\repo\XG-log"
set "LOG=%REPO%\_trace_mt5_source_v3.log"
set "TERMROOT=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo ==================================================>>"%LOG%"
echo [TRACE_MT5_V3] [%date% %time%] START>>"%LOG%"
echo TERMROOT=%TERMROOT%>>"%LOG%"

if not exist "%PS%" (
  echo [NG] PowerShell not found: %PS%>>"%LOG%"
  type "%LOG%"
  pause
  exit /b 1
)

if not exist "%TERMROOT%\" (
  echo [NG] TERMROOT missing: %TERMROOT%>>"%LOG%"
  type "%LOG%"
  pause
  exit /b 1
)

echo.>>"%LOG%"
echo ---- Scan Terminal ID folders (no recurse) ---->>"%LOG%"

REM PowerShell script: list each ID folder and newest file in logs / MQL5\Logs
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root='%TERMROOT%';" ^
  "$ids=Get-ChildItem -Path $root -Directory -ErrorAction Stop;" ^
  "if(-not $ids){ 'NG: no id folders under TERMROOT'; exit }" ^
  "$rows=@();" ^
  "foreach($d in $ids){" ^
  "  $opsPath=Join-Path $d.FullName 'logs';" ^
  "  $eaPath=Join-Path $d.FullName 'MQL5\Logs';" ^
  "  $ops=$null; $ea=$null;" ^
  "  if(Test-Path $opsPath){" ^
  "    $ops=Get-ChildItem -Path $opsPath -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "  }" ^
  "  if(Test-Path $eaPath){" ^
  "    $ea=Get-ChildItem -Path $eaPath -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "  }" ^
  "  $rows += [pscustomobject]@{ID=$d.Name; OPS=if($ops){$ops.Name}else{'-'}; OPS_Time=if($ops){$ops.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}else{'-'}; EA=if($ea){$ea.Name}else{'-'}; EA_Time=if($ea){$ea.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}else{'-'} }" ^
  "}" ^
  "$rows | Sort-Object OPS_Time -Descending | Select-Object -First 20 | Format-Table -AutoSize" ^
  1>>"%LOG%" 2>>"%LOG%"

echo.>>"%LOG%"
echo ---- Candidate (best guess) ---->>"%LOG%"

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root='%TERMROOT%';" ^
  "$ids=Get-ChildItem -Path $root -Directory -ErrorAction Stop;" ^
  "$best=$null;" ^
  "foreach($d in $ids){" ^
  "  $opsPath=Join-Path $d.FullName 'logs';" ^
  "  $ops=$null;" ^
  "  if(Test-Path $opsPath){" ^
  "    $ops=Get-ChildItem -Path $opsPath -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;" ^
  "  }" ^
  "  if($ops -and (-not $best -or $ops.LastWriteTime -gt $best.Time)){" ^
  "    $best=[pscustomobject]@{ID=$d.Name; Time=$ops.LastWriteTime; Path=$d.FullName; File=$ops.FullName}" ^
  "  }" ^
  "}" ^
  "if($best){ 'BEST_ID='+$best.ID; 'BEST_PATH='+$best.Path; 'BEST_OPS='+$best.File; 'BEST_TIME='+$best.Time.ToString('yyyy-MM-dd HH:mm:ss') } else { 'NG: could not find any OPS log in any id folder' }" ^
  1>>"%LOG%" 2>>"%LOG%"

echo.>>"%LOG%"
echo [TRACE_MT5_V3] [%date% %time%] END>>"%LOG%"

type "%LOG%"
pause
endlocal
exit /b 0