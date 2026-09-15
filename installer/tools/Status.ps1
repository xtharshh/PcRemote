# Lumen Desk status: task state + API + recent log.
$ErrorActionPreference = "SilentlyContinue"
$app = Split-Path -Parent $PSScriptRoot
$port = 5000
$ini = Join-Path $app "config\install.ini"
if (Test-Path $ini) {
  $m = Select-String -Path $ini -Pattern "^\s*port\s*=\s*(\d+)"
  if ($m) { $port = [int]$m.Matches[0].Groups[1].Value }
}
Get-ScheduledTask -TaskName "LumenDesk" |
  Format-Table TaskName, State -AutoSize
try {
  $s = Invoke-RestMethod "http://localhost:${port}/status" -TimeoutSec 5
  "API OK — PC: $($s.pc), brightness: $($s.brightness), active profile: $($s.active)"
} catch { "API not responding (service starting? reinstall or check the log below)" }
Get-Content (Join-Path $app "profiles\daemon.log") -Tail 5
