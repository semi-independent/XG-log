@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===== Settings =====
set "REPO=C:\XG\repo\XG-log"
set "DROP=%REPO%\drop"
set "ARCH=%REPO%\archive"
set "LOG=%REPO%\_send.log"

REM ===== Timestamp (YYYY-MM-DD_HHMMSS) =====
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd_HHmmss'"`) do set "TS=%%T"
set "DEST=%ARCH%\%TS%"

REM ===== Single instance lock =====
set "LOCKDIR=%REPO%\_send_lock"
mkdir "%LOCKDIR%" >nul 2>nul
if errorlevel 1 (
  echo [%date% %time%] Another send is running. >> "%LOG%"
  echo 既に送信処理が動いています。少し待ってからもう一度。
  exit /b 2
)

echo ================================================== >> "%LOG%"
echo [%date% %time%] START TS=%TS% >> "%LOG%"

REM ===== Preflight =====
if not exist "%REPO%\.git" (
  echo [%date% %time%] ERROR: .git not found at %REPO% >> "%LOG%"
  echo エラー：Gitリポジトリが見つかりません（%REPO%\.git）。
  goto :cleanup
)
if not exist "%DROP%\" mkdir "%DROP%" >nul 2>nul
if not exist "%ARCH%\" mkdir "%ARCH%" >nul 2>nul

REM ===== Check if there is anything to send (dir-based) =====
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

REM ===== Make destination folder =====
mkdir "%DEST%" >nul 2>nul
if errorlevel 1 (
  echo [%date% %time%] ERROR: cannot create DEST=%DEST% >> "%LOG%"
  echo エラー：archive フォルダ作成に失敗しました。
  goto :cleanup
)

REM ===== Move with robocopy (copy+delete) =====
REM robocopy return codes: 0-7 success, >=8 failure
set "RCFAIL="

call :robomove "*.log"
call :robomove "*.txt"
call :robomove "*.html"
call :robomove "*.png"
call :robomove "*.jpg"
call :robomove "*.jpeg"

if defined RCFAIL (
  echo [%date% %time%] ERROR: robocopy /MOV failed for some masks. >> "%LOG%"
  echo エラー：移動に失敗しました（ロック中の可能性）。_send.log を確認してください。
  goto :cleanup
)

echo [%date% %time%] MOVE DONE. >> "%LOG%"

REM ===== Git add / commit / push =====
pushd "%REPO%"

git status --porcelain >nul 2>nul
if errorlevel 1 (
  echo [%date% %time%] ERROR: git not available or repo broken. >> "%LOG%"
  echo エラー：git が使えない / リポジトリが壊れています。
  popd
  goto :cleanup
)

git add -A >> "%LOG%" 2>&1

REM Commit only if there are changes
for /f %%S in ('git status --porcelain ^| find /c /v ""') do set "CHG=%%S"
echo [%date% %time%] git changes=%CHG% >> "%LOG%"

if "%CHG%"=="0" (
  echo [%date% %time%] No git changes after add. >> "%LOG%"
  echo Git更新なし（同内容が既に反映済みの可能性）。
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

REM Push: disable interactive prompts (no freeze)
set "GIT_TERMINAL_PROMPT=0"
git push -u origin "%BR%" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [%date% %time%] ERROR: git push failed. >> "%LOG%"
  echo エラー：push に失敗しました（認証/回線/リモート設定）。_send.log を確認してください。
  popd
  goto :cleanup
)

popd

echo [%date% %time%] SUCCESS. >> "%LOG%"
echo 完了：archive に整理して GitHub へ push しました。
goto :cleanup

REM ===== Subroutine =====
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

:cleanup
rmdir "%LOCKDIR%" >nul 2>nul
echo [%date% %time%] END >> "%LOG%"
endlocal
exit /b 0