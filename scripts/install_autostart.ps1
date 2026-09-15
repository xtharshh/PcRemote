param([string]$Pin="1234", [int]$Port=5000)
# Always-on, NO terminal window. Works WITHOUT admin (logon task for current user).
# For run-before-logon as well, re-run this file as Administrator.
$pyw = (Get-Command pythonw).Source
$dir = Split-Path -Parent $PSScriptRoot
$action = New-ScheduledTaskAction -Execute $pyw `
  -Argument "src/pc_service/daemon.py $Pin $Port" -WorkingDirectory $dir
$trig = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -Hidden
try {
  Register-ScheduledTask -TaskName "PCRemote" -Action $action -Trigger $trig `
    -Settings $set -Force | Out-Null
  Start-ScheduledTask -TaskName "PCRemote" -ErrorAction SilentlyContinue
  Write-Output "PCRemote installed: no window, starts at your logon, PIN=$Pin PORT=$Port"
} catch {
  Write-Output "NEED ADMIN or failed: $($_.Exception.Message)"
  Write-Output "Right-click PowerShell -> Run as Administrator, then run this file again."
}
Write-Output "Check: scripts/status_daemon.ps1 | Remove: scripts/uninstall_autostart.ps1"
