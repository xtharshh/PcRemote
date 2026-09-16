param([string]$Pin="1234", [int]$Port=5000)
# Always-on, NO terminal window. Runs elevated so icacls/user-creation work.
# Must be run from an Administrator PowerShell once.
$pyw = (Get-Command pythonw).Source
$dir = Split-Path -Parent $PSScriptRoot
$action = New-ScheduledTaskAction -Execute $pyw `
  -Argument "src/pc_service/daemon.py $Pin $Port" -WorkingDirectory $dir
$trig = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -Hidden
try {
  # -RunLevel Highest on Register-ScheduledTask works on Win10/Server2016+
  Register-ScheduledTask -TaskName "LumenDesk" -Action $action -Trigger $trig `
    -Settings $set -RunLevel Highest -Force | Out-Null
  Start-ScheduledTask -TaskName "LumenDesk" -ErrorAction SilentlyContinue
  Write-Output "LumenDesk service installed (elevated): starts at logon, PIN=$Pin PORT=$Port"
} catch {
  Write-Output "FAILED (run this script from Administrator PowerShell): $($_.Exception.Message)"
}
Write-Output "Check: scripts/status_daemon.ps1 | Remove: scripts/uninstall_autostart.ps1"
