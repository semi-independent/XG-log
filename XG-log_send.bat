@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "ARCH=%REPO%\archive"
set "LOG=%REPO%\_send.log"
set "LOCK=%REPO%\_send.lock"

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HHmmss'"`) do set "TS=%%T"
set "DEST=%ARCH%\%TS%"

REM ---- stale lock cleanup (30 minutes) ----
if exist "%LOCK%" (
  for /f %%A in ('powershell -NoProfile -Command "(Get-Date) - (Get-Item ''%LOCK%'').LastWriteTime | %%{ [int]$_.TotalMinutes }"') do set "AGE=%%A"
  if not "%AGE%"=="" if %AGE% GEQ 30 del /f /q "%LOCK%" >nul 2>nul
)

REM ---- lock ----
if exist "%LOCK%" (
  echo [%date% %time%] Another send is running (lock exists). >> "%LOG%"
  echo 既に送信処理が動いています（lock）。少し待つか、lock解除後に再実行。
  exit /b 2
)
type nul > "%LOCK%"

echo ================================================== >> "%LOG%"
echo [%date% %time%] START TS=%TS% >> "%LOG%"

if not exist "%REPO%\.git" (
  echo [%date% %time%] ERROR: .git not found at %REPO% >> "%LOG%"
  echo エラー：Gitリポジトリが見つかりません（%REPO%\.git）。
  goto :cleanup
)

if not exist "%DROP%\" mkdir "%DROP%" >nul 2>nul
if not exist "%ARCH%\" mkdir "%ARCH%" >nul 2>nul
mkdir "%DEST%" >nul 2>nul

REM ---- anything to send? ----
set "HASFILES="
for /f "delims=" %%F in ('dir /b /a:-d "%DROP%\*.log" "%DROP%\*.txt" "%DROP%\*.html" "%DROP%\*.png" "%DROP%\*.jpg" "%DROP%\*.jpeg" 2^>nul') do (
  set "HASFILES=1"
  goto :hasfiles_done
)
:hasfiles_done
if not defined HASFILES (
  echo [%date% %time%] No target files in drop. >> "%LOG%"
  echo drop に送信対象がありません。
  goto :cleanup
)

REM ---- Move by robocopy (/MOV) ----
set "RCFAIL="
call :robomove "*.log"
call :robomove "*.txt"
call :robomove "*.html"
call :robomove "*.png"
call :robomove "*.jpg"
call :robomove "*.jpeg"

if defined RCFAIL (
  echo [%date% %time%] ERROR: robocopy /MOV failed. >> "%LOG%"
  echo エラー：移動に失敗しました。_send.log を確認してください。
  goto :cleanup
)

echo [%date% %time%] MOVE DONE. >> "%LOG%"

REM ---- Git ----
pushd "%REPO%"

git add -A >> "%LOG%" 2>&1
for /f %%S in ('git status --porcelain ^| find /c /v ""') do set "CHG=%%S"
echo [%date% %time%] git changes=%CHG% >> "%LOG%"

if "%CHG%"=="0" (
  echo [%date% %time%] No git changes after add. >> "%LOG%"
  echo Git更新なし。
  popd
  goto :cleanup
)

git commit -m "log: %TS%" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [%date% %time%] ERROR: git commit failed. >> "%LOG%"
  echo エラー：commit に失敗しました。_send.log を確認してください。
  popd
  goto :cleanup
)

for /f "delims=" %%B in ('git rev-parse --abbrev-ref HEAD') do set "BR=%%B"
set "GIT_TERMINAL_PROMPT=0"
git push -u origin "%BR%" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [%date% %time%] ERROR: git push failed. >> "%LOG%"
  echo エラー：push に失敗しました。_send.log を確認してください。
  popd
  goto :cleanup
)

popd
echo [%date% %time%] SUCCESS. >> "%LOG%"
echo 完了：GitHubへpushしました。

:cleanup
echo [%date% %time%] END >> "%LOG%"
del /f /q "%LOCK%" >nul 2>nul
endlocal
exit /b 0

:robomove
set "MASK=%~1"
echo [%date% %time%] robocopy /MOV mask=%MASK% >> "%LOG%"
robocopy "%DROP%" "%DEST%" "%MASK%" /MOV /R:20 /W:2 /COPY:DAT /DCOPY:DAT /NFL /NDL /NP >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
  echo [%date% %time%] robocopy FAILED mask=%MASK% rc=%RC% >> "%LOG%"
  set "RCFAIL=1"
) else (
  echo [%date% %time%] robocopy OK mask=%MASK% rc=%RC% >> "%LOG%"
)
exit /b 0