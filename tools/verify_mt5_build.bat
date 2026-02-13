@echo off
setlocal
set "TERM_ID=ED051E4A9BEE8A33BDDD0F947358B2B2"
set "BUILD_ID=r20260213_fix1"
set "LOOKBACK_MIN=720"

if not "%~1"=="" set "BUILD_ID=%~1"
if not "%~2"=="" set "LOOKBACK_MIN=%~2"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_mt5_build.ps1" -TerminalId "%TERM_ID%" -BuildId "%BUILD_ID%" -LookbackMinutes %LOOKBACK_MIN%
set RC=%ERRORLEVEL%
echo.
if %RC%==0 (
  echo [VERIFY] PASS
) else (
  echo [VERIFY] FAIL (code=%RC%)
)
exit /b %RC%
