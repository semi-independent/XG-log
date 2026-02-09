@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "LOG=%REPO%\_cleanup_temp.log"

REM ====== START ======
cd /d "%REPO%" || exit /b 1

echo ================================================== >> "%LOG%"
echo [CLEAN_TEMP] [%date% %time%] START >> "%LOG%"

REM 1) sync first (avoid push rejected)
git fetch >> "%LOG%" 2>&1
git pull --rebase --autostash >> "%LOG%" 2>&1

REM 2) remove temp/diag/force files from git + local
for %%F in (
  "_diag_send.bat"
  "_diag_send.log"
  "_force_send.bat"
  "_force_send.log"
) do (
  if exist "%%~F" (
    git rm -f "%%~F" >> "%LOG%" 2>&1
    echo [CLEAN_TEMP] removed: %%~F >> "%LOG%"
  ) else (
    echo [CLEAN_TEMP] skip (missing): %%~F >> "%LOG%"
  )
)

REM 3) commit & push only if something changed
git status --porcelain > "%TEMP%\_xg_stat.txt"
for /f %%A in ('type "%TEMP%\_xg_stat.txt" ^| find /c /v ""') do set "CHG=%%A"

if "%CHG%"=="0" (
  echo [CLEAN_TEMP] no changes. >> "%LOG%"
  echo [CLEAN_TEMP] END >> "%LOG%"
  endlocal
  exit /b 0
)

git commit -m "cleanup temp bat/log" >> "%LOG%" 2>&1
git push >> "%LOG%" 2>&1

echo [CLEAN_TEMP] DONE >> "%LOG%"
echo [CLEAN_TEMP] END >> "%LOG%"
endlocal
exit /b 0