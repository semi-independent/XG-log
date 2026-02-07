@echo off
setlocal EnableExtensions EnableDelayedExpansion
title XG LOG SEND V2 DIAG (MOV)

set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "ARCH=%REPO%\archive"
set "LOG=%REPO%\_send.log"
set "LOCK=%REPO%\_send.lock"

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HHmmss'"`) do set "TS=%%T"
set "DEST=%ARCH%\%TS%"

echo ================================================== >> "%LOG%"
echo [V2_DIAG] [%date% %time%] START TS=%TS% >> "%LOG%"

echo === V2_DIAG RUNNING ===
echo Repo : %REPO%
echo Drop : %DROP%
echo Dest : %DEST%
echo Log  : %LOG%
echo.

REM --- hard unlock (safe) ---
if exist "%REPO%\_send_lock" rmdir /s /q "%REPO%\_send_lock" >nul 2>nul
if exist "%LOCK%" del /f /q "%LOCK%" >nul 2>nul

type nul > "%LOCK%"

if not exist "%DROP%\" mkdir "%DROP%" >nul 2>nul
if not exist "%ARCH%\" mkdir "%ARCH%" >nul 2>nul
mkdir "%DEST%" >nul 2>nul

echo [V2_DIAG] robocopy /MOV start >> "%LOG%"

REM --- MOVE (copy+delete) ---
robocopy "%DROP%" "%DEST%" *.log *.txt *.html *.png *.jpg *.jpeg /MOV /R:20 /W:2 /COPY:DAT /DCOPY:DAT /NFL /NDL /NP >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
echo [V2_DIAG] robocopy rc=%RC% >> "%LOG%"

if %RC% GEQ 8 (
  echo [V2_DIAG] ERROR robocopy failed rc=%RC% >> "%LOG%"
  echo エラー：robocopy が失敗（rc=%RC%）。_send.log を見て。
  goto :cleanup
)

echo [V2_DIAG] MOVE DONE >> "%LOG%"

pushd "%REPO%"
git add -A >> "%LOG%" 2>&1
for /f %%S in ('git status --porcelain ^| find /c /v ""') do set "CHG=%%S"
echo [V2_DIAG] git changes=%CHG% >> "%LOG%"

if "%CHG%"=="0" (
  echo [V2_DIAG] No changes >> "%LOG%"
  echo Git更新なし（MOVEだけ成功）。OK。
  popd
  goto :cleanup
)

git commit -m "log: %TS%" >> "%LOG%" 2>&1
set "GIT_TERMINAL_PROMPT=0"
for /f "delims=" %%B in ('git rev-parse --abbrev-ref HEAD') do set "BR=%%B"
git push -u origin "%BR%" >> "%LOG%" 2>&1
echo [V2_DIAG] PUSH DONE >> "%LOG%"
popd

echo [V2_DIAG] SUCCESS >> "%LOG%"
echo 完了（V2_DIAG）。

:cleanup
del /f /q "%LOCK%" >nul 2>nul
echo [V2_DIAG] END >> "%LOG%"
echo.
echo === V2_DIAG END ===
pause
endlocal
exit /b 0