@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ====== CONFIG ======
set "REPO=C:\XG\repo\XG-log"
set "LOG=%REPO%\_diag_send.log"

echo ==================================================>> "%LOG%"
echo [DIAG] [%date% %time%] START>> "%LOG%"

if not exist "%REPO%\.git\" (
  echo [NG] .git not found: %REPO%>> "%LOG%"
  echo [HINT] REPO path wrong or not a git repo>> "%LOG%"
  goto :END
)

pushd "%REPO%" >nul

echo ---- git remote -v ---->> "%LOG%"
git remote -v>> "%LOG%" 2>&1

echo ---- git branch ---->> "%LOG%"
git branch>> "%LOG%" 2>&1

echo ---- git status ---->> "%LOG%"
git status>> "%LOG%" 2>&1

echo ---- latest files in drop (top 30) ---->> "%LOG%"
dir "%REPO%\drop" /a:-d /o:-d>> "%LOG%" 2>&1

echo ---- git diff --stat ---->> "%LOG%"
git diff --stat>> "%LOG%" 2>&1

echo ---- git log (last 5) ---->> "%LOG%"
git log --oneline -n 5>> "%LOG%" 2>&1

popd >nul

:END
echo [DIAG] [%date% %time%] END>> "%LOG%"
echo OK: wrote "%LOG%"
endlocal
exit /b 0