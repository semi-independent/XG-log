:: C:\XG\repo\XG-log\XG-log_send.bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "ARCH=%REPO%\archive"
set "LOG=%REPO%\_send.log"

REM archive folder name = ts (locale-independent)
for /f %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString(\"yyyy-MM-dd_HHmmss\")"') do set "TS=%%I"
set "DST=%ARCH%\%TS%"

REM ====== START ======
echo ==================================================>>"%LOG%"
echo [SEND] [%date% %time%] START ts=%TS%>>"%LOG%"

pushd "%REPO%" 1>nul 2>nul
if errorlevel 1 (
  echo [NG] cannot cd to REPO: %REPO%>>"%LOG%"
  echo [SEND] END>>"%LOG%"
  exit /b 1
)

REM ----- 0) preflight -----
if not exist "%DROP%\" (
  echo [NG] drop missing: %DROP%>>"%LOG%"
  echo [SEND] END>>"%LOG%"
  popd
  exit /b 1
)
if not exist "%ARCH%\" mkdir "%ARCH%" >nul 2>nul

REM drop empty check
set "DROP_COUNT=0"
for /f %%C in ('dir /b /a:-d "%DROP%" 2^>nul ^| find /c /v ""') do set "DROP_COUNT=%%C"
set "DROP_EMPTY=1"
if not "%DROP_COUNT%"=="0" set "DROP_EMPTY=0"
if "%DROP_EMPTY%"=="1" (
  echo [OK] drop is empty. nothing to send.>>"%LOG%"
  echo [SEND] END>>"%LOG%"
  popd
  exit /b 0
)

REM ----- 1) sync before making archive (avoid push reject) -----
echo ---- git fetch ---->>"%LOG%"
git fetch>>"%LOG%" 2>&1

echo ---- git pull --rebase --autostash ---->>"%LOG%"
git pull --rebase --autostash>>"%LOG%" 2>&1

REM ----- 2) create new archive folder and copy drop into it -----
mkdir "%DST%" >nul 2>nul
if not exist "%DST%\" (
  echo [NG] cannot create archive folder: %DST%>>"%LOG%"
  echo [SEND] END>>"%LOG%"
  popd
  exit /b 1
)

echo ---- copy drop -> archive\%TS% ---->>"%LOG%"
copy /y "%DROP%\*" "%DST%\" >nul 2>nul

REM verify copy
set "COPIED_OK=0"
dir /b "%DST%\" 1>nul 2>nul && set "COPIED_OK=1"
if "%COPIED_OK%"=="0" (
  echo [NG] archive folder empty after copy. abort.>>"%LOG%"
  echo [SEND] END>>"%LOG%"
  popd
  exit /b 1
)

REM ----- 3) stage files and commit -----
echo ---- git add ---->>"%LOG%"
git add -A>>"%LOG%" 2>&1

echo ---- git status (after add) ---->>"%LOG%"
git status>>"%LOG%" 2>&1

echo ---- git commit ---->>"%LOG%"
git commit -m "log: %TS%">>"%LOG%" 2>&1

REM ----- 4) push (with one auto-retry after sync) -----
echo ---- git push ---->>"%LOG%"
git push>>"%LOG%" 2>&1
set "PUSH_RC=%errorlevel%"

if not "%PUSH_RC%"=="0" (
  echo [WARN] push failed. retry once after sync.>>"%LOG%"
  echo ---- git fetch ---->>"%LOG%"
  git fetch>>"%LOG%" 2>&1
  echo ---- git pull --rebase --autostash ---->>"%LOG%"
  git pull --rebase --autostash>>"%LOG%" 2>&1
  echo ---- git push (retry) ---->>"%LOG%"
  git push>>"%LOG%" 2>&1
)

REM ----- 5) cleanup drop only after archive commit attempt -----
echo ---- cleanup drop ---->>"%LOG%"
del /q "%DROP%\*" >nul 2>nul

echo [OK] archive created: %TS%>>"%LOG%"
echo [SEND] [%date% %time%] END>>"%LOG%"
popd 1>nul 2>nul
endlocal
exit /b 0
