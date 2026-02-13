param(
  [string]$TerminalId = "ED051E4A9BEE8A33BDDD0F947358B2B2",
  [string]$BuildId = "r20260213_fix1",
  [int]$LookbackMinutes = 30
)

$ErrorActionPreference = "Stop"

$base = Join-Path $env:APPDATA "MetaQuotes\Terminal\$TerminalId\MQL5\Experts"
$logFile = Join-Path $env:APPDATA "MetaQuotes\Terminal\$TerminalId\MQL5\Logs\$(Get-Date -Format yyyyMMdd).log"

if(-not (Test-Path $base)){
  Write-Host "[NG] Experts folder not found: $base"
  exit 2
}

$targets = @(
  @{ ex5="at_v0035_push.ex5"; key="[AT] READY_GATE=OK build=$BuildId"   },
  @{ ex5="at_v0036_pull.ex5"; key="[AT] READY_GATE=OK build=$BuildId"   },
  @{ ex5="main_v0009.ex5";    key="[MAIN] READY_GATE=OK build=$BuildId" },
  @{ ex5="sub_v0010.ex5";     key="[SUB] READY_GATE=OK build=$BuildId"  }
)

$ok = $true
Write-Host "=== EX5 freshness ==="
foreach($t in $targets){
  $p = Join-Path $base $t.ex5
  if(-not (Test-Path $p)){
    Write-Host "[NG] missing: $($t.ex5)"
    $ok = $false
    continue
  }
  $fi = Get-Item $p
  Write-Host ("[OK] {0}  {1:yyyy-MM-dd HH:mm:ss}  {2} bytes" -f $t.ex5, $fi.LastWriteTime, $fi.Length)
}

Write-Host ""
Write-Host "=== Runtime build markers ==="
if(-not (Test-Path $logFile)){
  Write-Host "[NG] log not found: $logFile"
  exit 2
}

$since = (Get-Date).AddMinutes(-1 * $LookbackMinutes)
$lines = Get-Content $logFile -Encoding UTF8 | Where-Object {
  if($_.Length -lt 19){ return $false }
  $tsStr = $_.Substring(0,19)
  try{
    $dt = [datetime]::ParseExact(
      $tsStr,
      "yyyy.MM.dd HH:mm:ss",
      [System.Globalization.CultureInfo]::InvariantCulture
    )
    return $dt -ge $since
  } catch {
    return $false
  }
}

foreach($t in $targets){
  if($lines | Select-String -SimpleMatch $t.key -Quiet){
    Write-Host "[OK] found marker: $($t.key)"
  } else {
    Write-Host "[NG] marker not found in last $LookbackMinutes min: $($t.key)"
    $ok = $false
  }
}

Write-Host ""
if($ok){
  Write-Host "[PASS] build reflection looks good."
  exit 0
}

Write-Host "[FAIL] build reflection mismatch exists."
exit 1
