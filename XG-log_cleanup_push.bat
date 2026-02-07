@echo off
setlocal
set "REPO=C:\XG\repo\XG-log"
pushd "%REPO%"

git add -A
for /f %%S in ('git status --porcelain ^| find /c /v ""') do set "CHG=%%S"
if "%CHG%"=="0" (
  echo No changes.
  popd
  exit /b 0
)

for /f "delims=" %%T in ('powershell -NoProfile -Command "Get-Date -Format ''yyyy-MM-dd_HHmmss''"') do set "TS=%%T"
git commit -m "cleanup: %TS%"
set "GIT_TERMINAL_PROMPT=0"
for /f "delims=" %%B in ('git rev-parse --abbrev-ref HEAD') do set "BR=%%B"
git push -u origin "%BR%"

popd
endlocal
exit /b 0