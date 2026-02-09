@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "ARCH=%REPO%\archive"
set "LOG=%REPO%\_send.log"

REM archive folder name = ts
for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "D=%%a-%%b-%%c"
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set "T=%%a%%b%%c"
set "TS=%D%_%T%"
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
dir /a:-d "%DROP%" | findstr /r /c:"[0-9][0-9]* File" > "%TEMP%\_xg_drop_count.txt"
set "DROP_EMPTY=0"
findstr /c:" 0 File" "%TEMP%\_xg_drop_count.txt" >nul && set "DROP_EMPTY=1"
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