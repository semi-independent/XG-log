@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "ARCH=%REPO%\archive"
set "DROP=%REPO%\drop"
set "LOG=%REPO%\_diag_archive.log"

REM ====== START ======
echo ==================================================>>"%LOG%"
echo [DIAG_ARCH] [%date% %time%] START>>"%LOG%"
echo REPO=%REPO%>>"%LOG%"

pushd "%REPO%" 1>nul 2>nul
if errorlevel 1 (
  echo [NG] cannot cd to REPO>>"%LOG%"
  echo [DIAG_ARCH] END>>"%LOG%"
  exit /b 1
)

echo ---- where am i ---->>"%LOG%"
cd>>"%LOG%"

echo ---- drop list (top 30) ---->>"%LOG%"
if exist "%DROP%\" (
  dir /a:-d /o:-d "%DROP%" | findstr /v /c:"Directory of" /c:"<DIR>" | more +0 >>"%LOG%"
) else (
  echo [NG] drop folder missing: %DROP%>>"%LOG%"
)

echo ---- archive latest (top 10 folders) ---->>"%LOG%"
if exist "%ARCH%\" (
  dir /ad /o:-d "%ARCH%" | more +0 >>"%LOG%"
) else (
  echo [NG] archive folder missing: %ARCH%>>"%LOG%"
)

echo ---- git status ---->>"%LOG%"
git status>>"%LOG%" 2>&1

echo ---- git remote -v ---->>"%LOG%"
git remote -v>>"%LOG%" 2>&1

echo ---- git log (last 8) ---->>"%LOG%"
git --no-pager log -n 8 --oneline --decorate>>"%LOG%" 2>&1

echo ---- last commit touching archive ---->>"%LOG%"
git --no-pager log -n 5 --oneline -- archive>>"%LOG%" 2>&1

echo ---- origin/main vs local ---->>"%LOG%"
git fetch>>"%LOG%" 2>&1
git rev-parse HEAD>>"%LOG%" 2>&1
git rev-parse origin/main>>"%LOG%" 2>&1

echo [DIAG_ARCH] [%date% %time%] END>>"%LOG%"
popd 1>nul 2>nul

echo OK: _diag_archive.log を見て>>"%LOG%"
endlocal
exit /b 0