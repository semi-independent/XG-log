@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "LOG=%REPO%\_force_send.log"

echo ==================================================>> "%LOG%"
echo [FORCE] [%date% %time%] START>> "%LOG%"

if not exist "%REPO%\.git\" (
  echo [NG] .git not found: %REPO%>> "%LOG%"
  goto :END
)

pushd "%REPO%" >nul

echo ---- git status (before) ---->> "%LOG%"
git status>> "%LOG%" 2>&1

echo ---- git add ---->> "%LOG%"
git add -A>> "%LOG%" 2>&1

echo ---- git status (after add) ---->> "%LOG%"
git status>> "%LOG%" 2>&1

REM commit only if there is something staged
git diff --cached --quiet
if %errorlevel%==0 (
  echo [INFO] nothing staged -> no commit>> "%LOG%"
  goto :PUSHONLY
)

for /f "tokens=1-3 delims=/: " %%a in ("%date%") do set "D=%%a-%%b-%%c"
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set "T=%%a%%b%%c"
set "MSG=auto send %D%_%T%"

echo ---- git commit ---->> "%LOG%"
git commit -m "%MSG%">> "%LOG%" 2>&1

:PUSHONLY
echo ---- git push ---->> "%LOG%"
git push>> "%LOG%" 2>&1

echo ---- git log (last 3) ---->> "%LOG%"
git log --oneline -n 3>> "%LOG%" 2>&1

popd >nul

:END
echo [FORCE] [%date% %time%] END>> "%LOG%"
echo OK: wrote "%LOG%"
endlocal
exit /b 0